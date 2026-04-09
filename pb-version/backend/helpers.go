package main

import (
	"html/template"
	"net/http"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

func float64Ptr(v float64) *float64 { return &v }

func renderPage(e *core.RequestEvent, name string, data any) error {
	e.Response.Header().Set("Content-Type", "text/html; charset=utf-8")
	e.Response.WriteHeader(http.StatusOK)
	return tmpl.ExecuteTemplate(e.Response, name, data)
}

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
			return ""
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
		EntityType:  "post",
		Subtype:     subtype,
		TypeLabel:   typeLabel("post", subtype),
		Title:       rec.GetString("title"),
		Slug:        slug,
		URL:         entityURL("post", subtype, slug),
		PublishedAt: formatDate(rec, "published_at"),
		Excerpt:     rec.GetString("excerpt"),
		Hero:        rec.GetString("featured_image"),
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
		Slug:        slug,
		URL:         entityURL("media_log", "", slug),
		PublishedAt: date,
		Excerpt:     rec.GetString("notes"),
		Thumbnail:   rec.GetString("thumbnail_url"),
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
		Hero:        rec.GetString("featured_image"),
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

// renderPostDetail is shared by /posts/:slug, /til/:slug, /now/:slug, etc.
func renderPostDetail(app *pocketbase.PocketBase, e *core.RequestEvent, slug string) error {
	rec, err := app.FindFirstRecordByData("posts", "slug", slug)
	if err != nil {
		return notFound("post not found")
	}
	app.ExpandRecord(rec, []string{"tags"}, nil)
	return renderPage(e, "post-detail", PostPage{
		Title:       rec.GetString("title"),
		PublishedAt: formatDate(rec, "published_at"),
		Excerpt:     rec.GetString("excerpt"),
		HTML:        template.HTML(rec.GetString("html")),
		Tags:        expandedTags(rec),
		Attribution: rec.GetString("attribution"),
		AttrURL:     rec.GetString("attribution_url"),
		PostType:    rec.GetString("post_type"),
	})
}
