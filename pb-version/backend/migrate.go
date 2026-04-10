package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/filesystem"
	"github.com/pocketbase/pocketbase/tools/types"

	_ "modernc.org/sqlite"
)

// uploadsPathRe matches /uploads/... image paths in markdown and HTML.
var uploadsPathRe = regexp.MustCompile(`/uploads/[^\s"')\]>]+`)

// migrateFromExample imports data from an Ash SQLite database into PocketBase.
// Set MIGRATE_DB to the source database path.
// Set UPLOADS_DIR to override the uploads directory (default: ../../priv/static/uploads
// relative to the source DB).
func migrateFromExample(app *pocketbase.PocketBase, dbPath string) error {
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		return fmt.Errorf("source db not found at %s", dbPath)
	}

	// Resolve uploads directory.
	uploadsDir := os.Getenv("UPLOADS_DIR")
	if uploadsDir == "" {
		absDBPath, err := filepath.Abs(dbPath)
		if err != nil {
			absDBPath = dbPath
		}
		uploadsDir = filepath.Join(filepath.Dir(absDBPath), "priv/static/uploads")
	}
	if abs, err := filepath.Abs(uploadsDir); err == nil {
		uploadsDir = abs
	}
	if _, err := os.Stat(uploadsDir); os.IsNotExist(err) {
		log.Printf("uploads dir not found at %s — images will be skipped", uploadsDir)
		uploadsDir = ""
	} else {
		log.Printf("using uploads dir: %s", uploadsDir)
	}

	src, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return fmt.Errorf("open source db: %w", err)
	}
	defer src.Close()

	// tagIDMap maps source tag ID → PocketBase record ID.
	tagIDMap, err := migrateTags(app, src, uploadsDir)
	if err != nil {
		return fmt.Errorf("migrate tags: %w", err)
	}

	if err := migratePosts(app, src, tagIDMap, uploadsDir); err != nil {
		return fmt.Errorf("migrate posts: %w", err)
	}

	if err := migrateLinks(app, src, tagIDMap); err != nil {
		return fmt.Errorf("migrate links: %w", err)
	}

	if err := migrateMediaLogs(app, src, tagIDMap, uploadsDir); err != nil {
		return fmt.Errorf("migrate media_logs: %w", err)
	}

	if err := migrateProjects(app, src, tagIDMap, uploadsDir); err != nil {
		return fmt.Errorf("migrate projects: %w", err)
	}

	if err := migrateContentImages(app, uploadsDir); err != nil {
		return fmt.Errorf("migrate content images: %w", err)
	}

	return nil
}

// uploadsFile resolves a source image path (e.g. "/uploads/foo.jpg") to a
// *filesystem.File ready to attach to a PocketBase record. Returns nil if the
// path is empty, the uploads directory is unknown, or the file is not found.
func uploadsFile(uploadsDir, srcPath string) *filesystem.File {
	if uploadsDir == "" || srcPath == "" {
		return nil
	}
	rel := strings.TrimPrefix(srcPath, "/uploads/")
	localPath := filepath.Join(uploadsDir, rel)
	if _, err := os.Stat(localPath); os.IsNotExist(err) {
		log.Printf("image not found: %s", localPath)
		return nil
	}
	f, err := filesystem.NewFileFromPath(localPath)
	if err != nil {
		log.Printf("open image %s: %v", localPath, err)
		return nil
	}
	return f
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

func migrateTags(app *pocketbase.PocketBase, src *sql.DB, uploadsDir string) (map[string]string, error) {
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
		if f := uploadsFile(uploadsDir, featuredImage); f != nil {
			rec.Set("featured_image", f)
		}
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

func migratePosts(app *pocketbase.PocketBase, src *sql.DB, tagIDMap map[string]string, uploadsDir string) error {
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
		       COALESCE(published_at,'')
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
			publishedAt                                  string
		)
		if err := rows.Scan(
			&srcID, &title, &slug, &excerpt, &html, &markdown,
			&postType, &status, &public, &featured,
			&featuredImage, &attribution, &attrURL,
			&publishedAt,
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
		if f := uploadsFile(uploadsDir, featuredImage); f != nil {
			rec.Set("featured_image", f)
		}
		rec.Set("attribution", attribution)
		rec.Set("attribution_url", attrURL)

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

func migrateMediaLogs(app *pocketbase.PocketBase, src *sql.DB, tagIDMap map[string]string, uploadsDir string) error {
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
		if f := uploadsFile(uploadsDir, thumbnailURL); f != nil {
			rec.Set("thumbnail_url", f)
		}
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

func migrateProjects(app *pocketbase.PocketBase, src *sql.DB, tagIDMap map[string]string, uploadsDir string) error {
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
		if f := uploadsFile(uploadsDir, featuredImage); f != nil {
			rec.Set("featured_image", f)
		}
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

// --- content images ---

// migrateContentImages scans markdown and html in posts and projects for
// /uploads/... image paths, attaches each unique image directly to the record's
// content_images field, then rewrites the paths in both columns so they point
// to the record's own PocketBase file URLs.
func migrateContentImages(app *pocketbase.PocketBase, uploadsDir string) error {
	if uploadsDir == "" {
		log.Println("content images: no uploads dir, skipping")
		return nil
	}

	totalUploaded, totalUpdated := 0, 0

	for _, collName := range []string{"posts", "projects"} {
		records, err := app.FindRecordsByFilter(collName, "1=1", "", 2000, 0)
		if err != nil {
			return fmt.Errorf("query %s: %w", collName, err)
		}

		for _, rec := range records {
			// Skip if already migrated in a previous run.
			if existing := rec.GetStringSlice("content_images"); len(existing) > 0 {
				continue
			}

			markdown := rec.GetString("markdown")
			html := rec.GetString("html")
			combined := markdown + "\n" + html

			paths := uploadsPathRe.FindAllString(combined, -1)
			if len(paths) == 0 {
				continue
			}

			// Deduplicate paths, preserving first-seen order.
			seen := make(map[string]struct{})
			var uniquePaths []string
			for _, p := range paths {
				if _, done := seen[p]; done {
					continue
				}
				seen[p] = struct{}{}
				uniquePaths = append(uniquePaths, p)
			}

			// Attach files one at a time so we can reliably map each source
			// path to the filename PocketBase assigns after save.
			replacements := make(map[string]string)
			for _, srcPath := range uniquePaths {
				f := uploadsFile(uploadsDir, srcPath)
				if f == nil {
					log.Printf("content image not found: %s — skipping", srcPath)
					continue
				}
				before := rec.GetStringSlice("content_images")
				mixed := make([]any, 0, len(before)+1)
				for _, s := range before {
					mixed = append(mixed, s)
				}
				mixed = append(mixed, f)
				rec.Set("content_images", mixed)
				if err := app.Save(rec); err != nil {
					log.Printf("attach image %s to %s %s: %v", srcPath, collName, rec.Id, err)
					continue
				}
				after := rec.GetStringSlice("content_images")
				if len(after) > len(before) {
					stored := after[len(after)-1]
					replacements[srcPath] = fileURL(collName, rec.Id, stored, "")
					totalUploaded++
				}
			}

			if len(replacements) == 0 {
				continue
			}

			for old, new := range replacements {
				markdown = strings.ReplaceAll(markdown, old, new)
				html = strings.ReplaceAll(html, old, new)
			}
			rec.Set("markdown", markdown)
			rec.Set("html", html)
			if err := app.Save(rec); err != nil {
				log.Printf("rewrite %s %s: %v", collName, rec.Id, err)
				continue
			}
			totalUpdated++
		}
	}

	log.Printf("content images: %d uploaded, %d records updated", totalUploaded, totalUpdated)
	return nil
}
