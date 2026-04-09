package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/types"

	_ "modernc.org/sqlite"
)

// migrateFromExample imports data from an Ash SQLite database into PocketBase.
// Set the MIGRATE_DB environment variable to the path of the source database.
func migrateFromExample(app *pocketbase.PocketBase, dbPath string) error {
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		return fmt.Errorf("source db not found at %s", dbPath)
	}

	src, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return fmt.Errorf("open source db: %w", err)
	}
	defer src.Close()

	// tagIDMap maps source tag ID → PocketBase record ID.
	tagIDMap, err := migrateTags(app, src)
	if err != nil {
		return fmt.Errorf("migrate tags: %w", err)
	}

	if err := migratePosts(app, src, tagIDMap); err != nil {
		return fmt.Errorf("migrate posts: %w", err)
	}

	if err := migrateLinks(app, src, tagIDMap); err != nil {
		return fmt.Errorf("migrate links: %w", err)
	}

	if err := migrateMediaLogs(app, src, tagIDMap); err != nil {
		return fmt.Errorf("migrate media_logs: %w", err)
	}

	if err := migrateProjects(app, src, tagIDMap); err != nil {
		return fmt.Errorf("migrate projects: %w", err)
	}

	return nil
}

// scanDate parses an Ash timestamp string into a types.DateTime.
func scanDate(s string) (types.DateTime, bool) {
	if s == "" {
		return types.DateTime{}, false
	}
	s = strings.Replace(s, " ", "T", 1)
	var dt types.DateTime
	if err := dt.Scan(s); err != nil {
		return types.DateTime{}, false
	}
	return dt, true
}

// tagIDsForSource returns PocketBase record IDs for the tags associated with a
// source record via the given join table.
func tagIDsForSource(src *sql.DB, joinTable, fkCol, sourceID string, tagIDMap map[string]string) []string {
	rows, err := src.Query(
		fmt.Sprintf(`SELECT tag_id FROM %s WHERE %s = ?`, joinTable, fkCol),
		sourceID,
	)
	if err != nil {
		return nil
	}
	defer rows.Close()

	var ids []string
	for rows.Next() {
		var srcTagID string
		if err := rows.Scan(&srcTagID); err != nil {
			continue
		}
		if pbID, ok := tagIDMap[srcTagID]; ok {
			ids = append(ids, pbID)
		}
	}
	return ids
}

// --- tags ---

func migrateTags(app *pocketbase.PocketBase, src *sql.DB) (map[string]string, error) {
	col, err := app.FindCollectionByNameOrId("tags")
	if err != nil {
		return nil, fmt.Errorf("find tags collection: %w", err)
	}

	rows, err := src.Query(`
		SELECT id, name, slug,
		       COALESCE(public, 0),
		       COALESCE(featured_image,''), COALESCE(description,''), COALESCE(description_html,'')
		FROM tags
		ORDER BY inserted_at ASC
	`)
	if err != nil {
		return nil, fmt.Errorf("query tags: %w", err)
	}
	defer rows.Close()

	tagIDMap := make(map[string]string)
	imported, skipped := 0, 0

	for rows.Next() {
		var (
			srcID, name, slug                               string
			public                                          int
			featuredImage, description, descriptionHTML string
		)
		if err := rows.Scan(&srcID, &name, &slug, &public, &featuredImage, &description, &descriptionHTML); err != nil {
			return nil, fmt.Errorf("scan tag: %w", err)
		}

		if ex, _ := app.FindFirstRecordByData("tags", "slug", slug); ex != nil {
			tagIDMap[srcID] = ex.Id
			skipped++
			continue
		}

		rec := core.NewRecord(col)
		rec.Set("name", name)
		rec.Set("slug", slug)
		rec.Set("public", public == 1)
		rec.Set("featured_image", featuredImage)
		rec.Set("description", description)
		rec.Set("description_html", descriptionHTML)

		if err := app.Save(rec); err != nil {
			log.Printf("migrate tag %q: %v", slug, err)
			continue
		}
		tagIDMap[srcID] = rec.Id
		imported++
	}

	log.Printf("tags migration: %d imported, %d skipped", imported, skipped)
	return tagIDMap, nil
}

// --- posts ---

func migratePosts(app *pocketbase.PocketBase, src *sql.DB, tagIDMap map[string]string) error {
	col, err := app.FindCollectionByNameOrId("posts")
	if err != nil {
		return fmt.Errorf("find posts collection: %w", err)
	}

	rows, err := src.Query(`
		SELECT id, title, slug,
		       COALESCE(excerpt,''), COALESCE(html,''), COALESCE(markdown,''),
		       post_type, status,
		       CASE WHEN public = 1 THEN 1 ELSE 0 END,
		       CASE WHEN featured = 1 THEN 1 ELSE 0 END,
		       COALESCE(featured_image,''), COALESCE(attribution,''), COALESCE(attribution_url,''),
		       COALESCE(published_at,''), COALESCE(content_images,'[]')
		FROM posts
		WHERE status = 'published'
		ORDER BY published_at DESC
	`)
	if err != nil {
		return fmt.Errorf("query posts: %w", err)
	}
	defer rows.Close()

	imported, skipped := 0, 0
	for rows.Next() {
		var (
			srcID, title, slug, excerpt, html, markdown string
			postType, status                             string
			public, featured                             int
			featuredImage, attribution, attrURL          string
			publishedAt, contentImages                   string
		)
		if err := rows.Scan(
			&srcID, &title, &slug, &excerpt, &html, &markdown,
			&postType, &status, &public, &featured,
			&featuredImage, &attribution, &attrURL,
			&publishedAt, &contentImages,
		); err != nil {
			return fmt.Errorf("scan post: %w", err)
		}

		if ex, _ := app.FindFirstRecordByData("posts", "slug", slug); ex != nil {
			skipped++
			continue
		}

		rec := core.NewRecord(col)
		rec.Set("title", title)
		rec.Set("slug", slug)
		rec.Set("excerpt", excerpt)
		rec.Set("html", html)
		rec.Set("markdown", markdown)
		rec.Set("post_type", postType)
		rec.Set("status", status)
		rec.Set("public", public == 1)
		rec.Set("featured", featured == 1)
		rec.Set("featured_image", featuredImage)
		rec.Set("attribution", attribution)
		rec.Set("attribution_url", attrURL)
		rec.Set("content_images", contentImages)

		if dt, ok := scanDate(publishedAt); ok {
			rec.Set("published_at", dt)
		}

		tagIDs := tagIDsForSource(src, "post_tags", "post_id", srcID, tagIDMap)
		if len(tagIDs) > 0 {
			rec.Set("tags", tagIDs)
		}

		if err := app.Save(rec); err != nil {
			log.Printf("migrate post %q: %v", slug, err)
			continue
		}
		imported++
	}

	log.Printf("posts migration: %d imported, %d skipped", imported, skipped)
	return nil
}

// --- links ---

func migrateLinks(app *pocketbase.PocketBase, src *sql.DB, tagIDMap map[string]string) error {
	col, err := app.FindCollectionByNameOrId("links")
	if err != nil {
		return fmt.Errorf("find links collection: %w", err)
	}

	rows, err := src.Query(`
		SELECT id, url, COALESCE(title,''), slug,
		       COALESCE(commentary,''),
		       CASE WHEN public = 1 THEN 1 ELSE 0 END,
		       COALESCE(og_title,''), COALESCE(og_description,''), COALESCE(og_image,''),
		       CASE WHEN og_image_pinned = 1 THEN 1 ELSE 0 END,
		       inserted_at
		FROM links
		ORDER BY inserted_at DESC
	`)
	if err != nil {
		return fmt.Errorf("query links: %w", err)
	}
	defer rows.Close()

	imported, skipped := 0, 0
	for rows.Next() {
		var (
			srcID, url, title, slug, commentary string
			public                              int
			ogTitle, ogDesc, ogImage            string
			ogImagePinned                       int
			insertedAt                          string
		)
		if err := rows.Scan(
			&srcID, &url, &title, &slug, &commentary, &public,
			&ogTitle, &ogDesc, &ogImage, &ogImagePinned,
			&insertedAt,
		); err != nil {
			return fmt.Errorf("scan link: %w", err)
		}

		if ex, _ := app.FindFirstRecordByData("links", "slug", slug); ex != nil {
			skipped++
			continue
		}

		rec := core.NewRecord(col)
		rec.Set("url", url)
		rec.Set("title", title)
		rec.Set("slug", slug)
		rec.Set("commentary", commentary)
		rec.Set("public", public == 1)
		rec.Set("og_title", ogTitle)
		rec.Set("og_description", ogDesc)
		rec.Set("og_image", ogImage)
		rec.Set("og_image_pinned", ogImagePinned == 1)

		if dt, ok := scanDate(insertedAt); ok {
			rec.Set("published_at", dt)
		}

		tagIDs := tagIDsForSource(src, "link_tags", "link_id", srcID, tagIDMap)
		if len(tagIDs) > 0 {
			rec.Set("tags", tagIDs)
		}

		if err := app.Save(rec); err != nil {
			log.Printf("migrate link %q: %v", slug, err)
			continue
		}
		imported++
	}

	log.Printf("links migration: %d imported, %d skipped", imported, skipped)
	return nil
}

// --- media_logs ---

func migrateMediaLogs(app *pocketbase.PocketBase, src *sql.DB, tagIDMap map[string]string) error {
	col, err := app.FindCollectionByNameOrId("media_logs")
	if err != nil {
		return fmt.Errorf("find media_logs collection: %w", err)
	}

	rows, err := src.Query(`
		SELECT id, title, slug, media_type, COALESCE(creator,''),
		       COALESCE(date_published,''), COALESCE(thumbnail_url,''),
		       status,
		       COALESCE(date_consumed,''), COALESCE(date_started,''), COALESCE(date_finished,''),
		       COALESCE(rating, 0),
		       COALESCE(notes,''), COALESCE(external_url,''),
		       CASE WHEN public = 1 THEN 1 ELSE 0 END,
		       CASE WHEN favourite = 1 THEN 1 ELSE 0 END,
		       COALESCE(published_at,'')
		FROM media_logs
		ORDER BY inserted_at DESC
	`)
	if err != nil {
		return fmt.Errorf("query media_logs: %w", err)
	}
	defer rows.Close()

	imported, skipped := 0, 0
	for rows.Next() {
		var (
			srcID, title, slug, mediaType, creator  string
			datePublished, thumbnailURL             string
			status                                  string
			dateConsumed, dateStarted, dateFinished string
			rating                                  int
			notes, externalURL                      string
			public, favourite                       int
			publishedAt                             string
		)
		if err := rows.Scan(
			&srcID, &title, &slug, &mediaType, &creator,
			&datePublished, &thumbnailURL,
			&status,
			&dateConsumed, &dateStarted, &dateFinished,
			&rating,
			&notes, &externalURL,
			&public, &favourite,
			&publishedAt,
		); err != nil {
			return fmt.Errorf("scan media_log: %w", err)
		}

		if ex, _ := app.FindFirstRecordByData("media_logs", "slug", slug); ex != nil {
			skipped++
			continue
		}

		rec := core.NewRecord(col)
		rec.Set("title", title)
		rec.Set("slug", slug)
		rec.Set("media_type", mediaType)
		rec.Set("creator", creator)
		rec.Set("thumbnail_url", thumbnailURL)
		rec.Set("status", status)
		rec.Set("notes", notes)
		rec.Set("external_url", externalURL)
		rec.Set("public", public == 1)
		rec.Set("favourite", favourite == 1)

		if rating > 0 {
			rec.Set("rating", rating)
		}

		for field, val := range map[string]string{
			"date_published": datePublished,
			"date_consumed":  dateConsumed,
			"date_started":   dateStarted,
			"date_finished":  dateFinished,
			"published_at":   publishedAt,
		} {
			if dt, ok := scanDate(val); ok {
				rec.Set(field, dt)
			}
		}

		tagIDs := tagIDsForSource(src, "media_log_tags", "media_log_id", srcID, tagIDMap)
		if len(tagIDs) > 0 {
			rec.Set("tags", tagIDs)
		}

		if err := app.Save(rec); err != nil {
			log.Printf("migrate media_log %q: %v", slug, err)
			continue
		}
		imported++
	}

	log.Printf("media_logs migration: %d imported, %d skipped", imported, skipped)
	return nil
}

// --- projects ---

func migrateProjects(app *pocketbase.PocketBase, src *sql.DB, tagIDMap map[string]string) error {
	col, err := app.FindCollectionByNameOrId("projects")
	if err != nil {
		return fmt.Errorf("find projects collection: %w", err)
	}

	rows, err := src.Query(`
		SELECT id, title, slug,
		       COALESCE(excerpt,''), COALESCE(html,''), COALESCE(markdown,''),
		       COALESCE(featured_image,''), status, project_status,
		       CASE WHEN featured = 1 THEN 1 ELSE 0 END,
		       CASE WHEN public = 1 THEN 1 ELSE 0 END,
		       COALESCE(published_at,''), COALESCE(start_date,''), COALESCE(end_date,''),
		       COALESCE(links,'[]'), COALESCE(images,'[]')
		FROM projects
		WHERE status = 'published'
		ORDER BY published_at DESC
	`)
	if err != nil {
		return fmt.Errorf("query projects: %w", err)
	}
	defer rows.Close()

	imported, skipped := 0, 0
	for rows.Next() {
		var (
			srcID, title, slug, excerpt, html, markdown string
			featuredImage, status, projectStatus        string
			featured, public                            int
			publishedAt, startDate, endDate             string
			links, images                               string
		)
		if err := rows.Scan(
			&srcID, &title, &slug, &excerpt, &html, &markdown,
			&featuredImage, &status, &projectStatus,
			&featured, &public,
			&publishedAt, &startDate, &endDate,
			&links, &images,
		); err != nil {
			return fmt.Errorf("scan project: %w", err)
		}

		if ex, _ := app.FindFirstRecordByData("projects", "slug", slug); ex != nil {
			skipped++
			continue
		}

		rec := core.NewRecord(col)
		rec.Set("title", title)
		rec.Set("slug", slug)
		rec.Set("excerpt", excerpt)
		rec.Set("html", html)
		rec.Set("markdown", markdown)
		rec.Set("featured_image", featuredImage)
		rec.Set("status", status)
		rec.Set("project_status", projectStatus)
		rec.Set("featured", featured == 1)
		rec.Set("public", public == 1)
		rec.Set("links", links)
		rec.Set("images", images)

		for field, val := range map[string]string{
			"published_at": publishedAt,
			"start_date":   startDate,
			"end_date":     endDate,
		} {
			if dt, ok := scanDate(val); ok {
				rec.Set(field, dt)
			}
		}

		tagIDs := tagIDsForSource(src, "project_tags", "project_id", srcID, tagIDMap)
		if len(tagIDs) > 0 {
			rec.Set("tags", tagIDs)
		}

		if err := app.Save(rec); err != nil {
			log.Printf("migrate project %q: %v", slug, err)
			continue
		}
		imported++
	}

	log.Printf("projects migration: %d imported, %d skipped", imported, skipped)
	return nil
}
