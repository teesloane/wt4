package main

import (
	"fmt"
	"html/template"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

// fileURL returns a PocketBase file URL for a record's file field.
// thumb is optional (e.g. "400x0", "100x100") — pass "" for the original.
func fileURL(collection, recordID, filename, thumb string) string {
	if filename == "" {
		return ""
	}
	u := fmt.Sprintf("/api/files/%s/%s/%s", collection, recordID, filename)
	if thumb != "" {
		u += "?thumb=" + thumb
	}
	return u
}

func float64Ptr(v float64) *float64 { return &v }

// entityURL returns the public URL path for a given entity type + subtype + slug.
func entityURL(entityType, subtype, slug string) string {
	switch entityType {
	case "post":
		switch subtype {
		case "til":
			return "/til/" + slug
		case "update":
			return "/now/" + slug
		case "quote":
			return "/quotes/" + slug
		case "fiction":
			return "/fiction/" + slug
		default:
			return "/posts/" + slug
		}
	case "link":
		return "/links/" + slug
	case "media_log":
		return "/media-logs/" + slug
	case "project":
		return "/projects/" + slug
	default:
		return "/"
	}
}

// typeLabel returns the human-readable badge label for list views.
func typeLabel(entityType, subtype string) string {
	switch entityType {
	case "post":
		switch subtype {
		case "til":
			return "TIL"
		case "quote":
			return "quote"
		case "update":
			return "update"
		case "fiction":
			return "fiction"
		default:
			return "post"
		}
	case "link":
		return "link"
	case "media_log":
		switch subtype {
		case "book":
			return "book"
		case "comic":
			return "comic"
		case "movie":
			return "film"
		case "music":
			return "music"
		case "video_game":
			return "game"
		default:
			return "media"
		}
	case "project":
		return "project"
	default:
		return entityType
	}
}

// expandedTags returns TagItems from a record's expanded tags relation.
func expandedTags(rec *core.Record) []TagItem {
	items := []TagItem{}
	for _, t := range rec.ExpandedAll("tags") {
		items = append(items, TagItem{
			Name: t.GetString("name"),
			Slug: t.GetString("slug"),
		})
	}
	return items
}

// formatDate formats a DateTime field as "January 2, 2006", or "" if zero.
func formatDate(rec *core.Record, field string) string {
	dt := rec.GetDateTime(field)
	if dt.IsZero() {
		return ""
	}
	return dt.Time().Format("January 2, 2006")
}

// fetchAndExpand queries a collection and expands tags on every record.
func fetchAndExpand(app *pocketbase.PocketBase, collection, filter, sort string, limit int) ([]*core.Record, error) {
	records, err := app.FindRecordsByFilter(collection, filter, sort, limit, 0)
	if err != nil {
		return nil, err
	}
	for _, r := range records {
		app.ExpandRecord(r, []string{"tags"}, nil)
	}
	return records, nil
}

// starsFromRating converts a numeric rating (1–5) to a unicode star string.
func starsFromRating(r float64) string {
	if r <= 0 {
		return ""
	}
	n := int(r + 0.5)
	stars := ""
	for i := 0; i < n; i++ {
		stars += "★"
	}
	for i := n; i < 5; i++ {
		stars += "☆"
	}
	return stars
}

// --- Record → EntityItem converters ---

func postToEntityItem(rec *core.Record) EntityItem {
	subtype := rec.GetString("post_type")
	slug := rec.GetString("slug")
	return EntityItem{
		ID:          rec.Id,
		EntityType:  "post",
		Subtype:     subtype,
		TypeLabel:   typeLabel("post", subtype),
		Title:       rec.GetString("title"),
		Slug:        slug,
		URL:         entityURL("post", subtype, slug),
		PublishedAt: formatDate(rec, "published_at"),
		Excerpt:     rec.GetString("excerpt"),
		Hero:        fileURL("posts", rec.Id, rec.GetString("featured_image"), "400x0"),
		Tags:        expandedTags(rec),
	}
}

func linkToEntityItem(rec *core.Record) EntityItem {
	slug := rec.GetString("slug")
	return EntityItem{
		EntityType:  "link",
		TypeLabel:   "link",
		Title:       rec.GetString("title"),
		Slug:        slug,
		URL:         entityURL("link", "", slug),
		PublishedAt: formatDate(rec, "published_at"),
		Excerpt:     rec.GetString("commentary"),
		Hero:        rec.GetString("og_image"),
		Tags:        expandedTags(rec),
	}
}

func mediaLogToEntityItem(rec *core.Record) EntityItem {
	slug := rec.GetString("slug")
	mediaType := rec.GetString("media_type")
	date := formatDate(rec, "date_consumed")
	if date == "" {
		date = formatDate(rec, "date_finished")
	}
	return EntityItem{
		EntityType:  "media_log",
		Subtype:     mediaType,
		TypeLabel:   typeLabel("media_log", mediaType),
		Title:       rec.GetString("title"),
		Creator:     rec.GetString("creator"),
		Slug:        slug,
		URL:         entityURL("media_log", "", slug),
		PublishedAt: date,
		Excerpt:     rec.GetString("notes"),
		Thumbnail:   fileURL("media_logs", rec.Id, rec.GetString("thumbnail_url"), "100x100"),
		Tags:        expandedTags(rec),
		Favourite:   rec.GetBool("favourite"),
	}
}

func projectToEntityItem(rec *core.Record) EntityItem {
	slug := rec.GetString("slug")
	ps := rec.GetString("project_status")
	return EntityItem{
		EntityType:  "project",
		Subtype:     ps,
		TypeLabel:   typeLabel("project", ""),
		Title:       rec.GetString("title"),
		Slug:        slug,
		URL:         entityURL("project", "", slug),
		PublishedAt: formatDate(rec, "published_at"),
		Excerpt:     rec.GetString("excerpt"),
		Hero:        fileURL("projects", rec.Id, rec.GetString("featured_image"), "400x0"),
		Tags:        expandedTags(rec),
	}
}

func entityRecordToItem(rec *core.Record) EntityItem {
	et := rec.GetString("entity_type")
	sub := rec.GetString("subtype")
	return EntityItem{
		EntityType:  et,
		Subtype:     sub,
		TypeLabel:   typeLabel(et, sub),
		Title:       rec.GetString("title"),
		Slug:        rec.GetString("slug"),
		URL:         rec.GetString("url"),
		PublishedAt: formatDate(rec, "published_at"),
		Excerpt:     rec.GetString("content"),
		Hero:        rec.GetString("hero_url"),
		Thumbnail:   rec.GetString("thumbnail_url"),
		Tags:        expandedTags(rec),
		Favourite:   rec.GetBool("favourite"),
	}
}

func mediaLogToWeekItem(rec *core.Record) MediaLogItem {
	mediaType := rec.GetString("media_type")
	return MediaLogItem{
		Title:     rec.GetString("title"),
		Creator:   rec.GetString("creator"),
		MediaType: strings.ReplaceAll(mediaType, "_", " "),
		Thumbnail: fileURL("media_logs", rec.Id, rec.GetString("thumbnail_url"), "100x100"),
	}
}

func buildNowPage(app *pocketbase.PocketBase, rec *core.Record) NowDetailPage {
	publishedAt := rec.GetDateTime("published_at")

	var weekEntities []EntityItem
	var weekMediaLogs []MediaLogItem

	if !publishedAt.IsZero() {
		fromDt := publishedAt.Time().Add(-6 * 24 * time.Hour)
		fromStr := fromDt.UTC().Format("2006-01-02 15:04:05")
		toStr := publishedAt.Time().UTC().Format("2006-01-02 15:04:05")
		fromDate := fromDt.UTC().Format("2006-01-02")
		toDate := publishedAt.Time().UTC().Format("2006-01-02")

		// Entities active this week, excluding media_logs and update posts
		entityFilter := fmt.Sprintf(
			"public=true && entity_type!='media_log' && (entity_type!='post' || subtype!='update') && published_at>='%s' && published_at<='%s'",
			fromStr, toStr,
		)
		entityRecs, err := app.FindRecordsByFilter("entities", entityFilter, "-published_at", 50, 0)
		if err == nil {
			for _, r := range entityRecs {
				weekEntities = append(weekEntities, entityRecordToItem(r))
			}
		}

		// Music consumed this week
		musicFilter := fmt.Sprintf(
			"public=true && media_type='music' && date_consumed>='%s' && date_consumed<='%s'",
			fromDate, toDate,
		)
		musicRecs, _ := app.FindRecordsByFilter("media_logs", musicFilter, "-date_consumed", 50, 0)
		for _, r := range musicRecs {
			weekMediaLogs = append(weekMediaLogs, mediaLogToWeekItem(r))
		}

		// Books / comics in progress or finished this week.
		// Fetch all started on/before to_date, then filter in Go because PocketBase
		// null-date comparisons are unreliable in filter expressions.
		bookFilter := fmt.Sprintf(
			"public=true && (media_type='book' || media_type='comic') && date_started!='' && date_started<='%s'",
			toDate,
		)
		bookRecs, _ := app.FindRecordsByFilter("media_logs", bookFilter, "-date_started", 200, 0)
		for _, r := range bookRecs {
			dateFinished := r.GetDateTime("date_finished")
			// Include if: not finished yet, OR finished within the week window
			if dateFinished.IsZero() || !dateFinished.Time().Before(fromDt) {
				weekMediaLogs = append(weekMediaLogs, mediaLogToWeekItem(r))
			}
		}
	}

	// All update posts for the sidebar list
	updateRecs, _ := fetchAndExpand(app, "posts",
		"public=true && status='published' && post_type='update'", "-published_at", 200)
	updates := make([]EntityItem, 0, len(updateRecs))
	for _, r := range updateRecs {
		item := postToEntityItem(r)
		item.TypeLabel = ""
		item.Current = r.Id == rec.Id
		updates = append(updates, item)
	}

	return NowDetailPage{
		Title:         rec.GetString("title"),
		PublishedAt:   formatDate(rec, "published_at"),
		FeaturedImage: fileURL("posts", rec.Id, rec.GetString("featured_image"), "800x0"),
		HTML:          template.HTML(rec.GetString("html")),
		WeekEntities:  weekEntities,
		WeekMediaLogs: weekMediaLogs,
		Updates:       updates,
		CurrentID:     rec.Id,
	}
}

func renderNowDetail(app *pocketbase.PocketBase, e *core.RequestEvent, slug string) error {
	rec, err := app.FindFirstRecordByData("posts", "slug", slug)
	if err != nil {
		return notFound("post not found")
	}
	return renderPage(e, "now-detail", buildNowPage(app, rec))
}

func renderNowLatest(app *pocketbase.PocketBase, e *core.RequestEvent) error {
	records, err := app.FindRecordsByFilter("posts",
		"public=true && status='published' && post_type='update'", "-published_at", 1, 0)
	if err != nil || len(records) == 0 {
		return notFound("no updates found")
	}
	return renderPage(e, "now-list", buildNowPage(app, records[0]))
}

func renderHome(app *pocketbase.PocketBase, e *core.RequestEvent) error {
	// Recent non-fiction posts
	postRecs, _ := fetchAndExpand(app, "posts",
		"public=true && status='published' && post_type='post'", "-published_at", 5)
	posts := make([]EntityItem, 0, len(postRecs))
	for _, r := range postRecs {
		posts = append(posts, postToEntityItem(r))
	}

	// Recent fiction
	fictionRecs, _ := fetchAndExpand(app, "posts",
		"public=true && status='published' && post_type='fiction'", "-published_at", 3)
	recentFiction := make([]EntityItem, 0, len(fictionRecs))
	for _, r := range fictionRecs {
		recentFiction = append(recentFiction, postToEntityItem(r))
	}
	var latestStory *EntityItem
	if len(recentFiction) > 0 {
		item := recentFiction[0]
		latestStory = &item
	}

	// Projects
	projectRecs, _ := fetchAndExpand(app, "projects",
		"status='published'", "-published_at", 5)
	projects := make([]EntityItem, 0, len(projectRecs))
	for _, r := range projectRecs {
		projects = append(projects, projectToEntityItem(r))
	}

	// Currently reading — books/comics started but not finished
	bookRecs, _ := app.FindRecordsByFilter("media_logs",
		"public=true && (media_type='book' || media_type='comic') && date_started!=''",
		"-date_started", 50, 0)
	var currentlyReading []BookItem
	for _, r := range bookRecs {
		if r.GetDateTime("date_finished").IsZero() {
			currentlyReading = append(currentlyReading, BookItem{
				Title:   r.GetString("title"),
				Creator: r.GetString("creator"),
			})
		}
	}

	// Latest update post preview
	var update *NowPreview
	updateRecs, _ := app.FindRecordsByFilter("posts",
		"public=true && status='published' && post_type='update'", "-published_at", 1, 0)
	if len(updateRecs) > 0 {
		u := updateRecs[0]
		slug := u.GetString("slug")
		html := u.GetString("html")
		if len(html) > 600 {
			html = html[:600]
		}
		update = &NowPreview{
			Title: u.GetString("title"),
			URL:   "/now/" + slug,
			HTML:  template.HTML(html),
		}
	}

	// Top areas by entity tag count
	var topAreas []AreaItem
	app.DB().NewQuery(`
		SELECT t.name, t.slug, COUNT(et.id) as cnt
		FROM entity_tags et
		JOIN tags t ON t.id = et.tag_id
		WHERE t.public = 1
		GROUP BY t.id, t.name, t.slug
		ORDER BY cnt DESC
		LIMIT 5
	`).All(&topAreas)

	return renderPage(e, "home", HomePage{
		Posts:            posts,
		RecentFiction:    recentFiction,
		LatestStory:      latestStory,
		Projects:         projects,
		CurrentlyReading: currentlyReading,
		Update:           update,
		TopAreas:         topAreas,
	})
}

// renderPostDetail is shared by /posts/:slug, /til/:slug, /now/:slug, etc.
func renderPostDetail(app *pocketbase.PocketBase, e *core.RequestEvent, slug string) error {
	rec, err := app.FindFirstRecordByData("posts", "slug", slug)
	if err != nil {
		return notFound("post not found")
	}
	app.ExpandRecord(rec, []string{"tags"}, nil)
	return renderPage(e, "post-detail", PostPage{
		Title:         rec.GetString("title"),
		PublishedAt:   formatDate(rec, "published_at"),
		Excerpt:       rec.GetString("excerpt"),
		HTML:          template.HTML(rec.GetString("html")),
		Tags:          expandedTags(rec),
		Attribution:   rec.GetString("attribution"),
		AttrURL:       rec.GetString("attribution_url"),
		PostType:      rec.GetString("post_type"),
		FeaturedImage: fileURL("posts", rec.Id, rec.GetString("featured_image"), "800x0"),
	})
}
