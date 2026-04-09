package main

import (
	"html/template"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

func registerRoutes(app *pocketbase.PocketBase, se *core.ServeEvent) {
	r := se.Router

	// Home — most recent public entities
	r.GET("/", func(e *core.RequestEvent) error {
		records, err := fetchAndExpand(app, "entities",
			"public=true && published_at!=''", "-published_at", 15)
		if err != nil {
			records = []*core.Record{}
		}
		items := make([]EntityItem, 0, len(records))
		for _, rec := range records {
			items = append(items, entityRecordToItem(rec))
		}
		return renderPage(e, "home", ListPage{Items: items})
	})

	// Archive — all public entities sorted by date
	r.GET("/archive", func(e *core.RequestEvent) error {
		records, err := fetchAndExpand(app, "entities",
			"public=true && published_at!=''", "-published_at", 500)
		if err != nil {
			records = []*core.Record{}
		}
		items := make([]EntityItem, 0, len(records))
		for _, rec := range records {
			items = append(items, entityRecordToItem(rec))
		}
		return renderPage(e, "archive", ListPage{Items: items})
	})

	// Posts
	r.GET("/posts", func(e *core.RequestEvent) error {
		return renderPostList(app, e, "post_type='post'", "posts")
	})
	r.GET("/posts/{slug}", func(e *core.RequestEvent) error {
		return renderPostDetail(app, e, e.Request.PathValue("slug"))
	})

	// Now (updates)
	r.GET("/now", func(e *core.RequestEvent) error {
		return renderPostList(app, e, "post_type='update'", "now")
	})
	r.GET("/now/{slug}", func(e *core.RequestEvent) error {
		return renderPostDetail(app, e, e.Request.PathValue("slug"))
	})

	// TIL
	r.GET("/til", func(e *core.RequestEvent) error {
		return renderPostList(app, e, "post_type='til'", "TIL")
	})
	r.GET("/til/{slug}", func(e *core.RequestEvent) error {
		return renderPostDetail(app, e, e.Request.PathValue("slug"))
	})

	// Quotes
	r.GET("/quotes", func(e *core.RequestEvent) error {
		return renderPostList(app, e, "post_type='quote'", "quotes")
	})
	r.GET("/quotes/{slug}", func(e *core.RequestEvent) error {
		return renderPostDetail(app, e, e.Request.PathValue("slug"))
	})

	// Fiction
	r.GET("/fiction", func(e *core.RequestEvent) error {
		return renderPostList(app, e, "post_type='fiction'", "fiction")
	})
	r.GET("/fiction/{slug}", func(e *core.RequestEvent) error {
		return renderPostDetail(app, e, e.Request.PathValue("slug"))
	})

	// Links
	r.GET("/links", func(e *core.RequestEvent) error {
		records, err := fetchAndExpand(app, "links", "public=true", "-created", 200)
		if err != nil {
			records = []*core.Record{}
		}
		items := make([]EntityItem, 0, len(records))
		for _, rec := range records {
			items = append(items, linkToEntityItem(rec))
		}
		return renderPage(e, "link-list", ListPage{Items: items})
	})
	r.GET("/links/{slug}", func(e *core.RequestEvent) error {
		slug := e.Request.PathValue("slug")
		rec, err := app.FindFirstRecordByData("links", "slug", slug)
		if err != nil {
			return notFound("link not found")
		}
		app.ExpandRecord(rec, []string{"tags"}, nil)
		return renderPage(e, "link-detail", LinkPage{
			Title:       rec.GetString("title"),
			SiteURL:     rec.GetString("url"),
			Commentary:  template.HTML(rec.GetString("commentary")),
			OGImage:     rec.GetString("og_image"),
			PublishedAt: formatDate(rec, "published_at"),
			Tags:        expandedTags(rec),
		})
	})

	// Media logs
	r.GET("/media-logs", func(e *core.RequestEvent) error {
		records, err := fetchAndExpand(app, "media_logs", "public=true", "-created", 200)
		if err != nil {
			records = []*core.Record{}
		}
		items := make([]EntityItem, 0, len(records))
		for _, rec := range records {
			items = append(items, mediaLogToEntityItem(rec))
		}
		return renderPage(e, "media-list", ListPage{Items: items})
	})
	r.GET("/media-logs/{slug}", func(e *core.RequestEvent) error {
		slug := e.Request.PathValue("slug")
		rec, err := app.FindFirstRecordByData("media_logs", "slug", slug)
		if err != nil {
			return notFound("media log not found")
		}
		app.ExpandRecord(rec, []string{"tags"}, nil)
		date := formatDate(rec, "date_consumed")
		if date == "" {
			date = formatDate(rec, "date_finished")
		}
		return renderPage(e, "media-detail", MediaLogPage{
			Title:       rec.GetString("title"),
			Creator:     rec.GetString("creator"),
			MediaType:   rec.GetString("media_type"),
			Status:      rec.GetString("status"),
			Rating:      starsFromRating(rec.GetFloat("rating")),
			PublishedAt: date,
			Notes:       template.HTML(rec.GetString("notes")),
			ExternalURL: rec.GetString("external_url"),
			Thumbnail:   rec.GetString("thumbnail_url"),
			Tags:        expandedTags(rec),
		})
	})

	// Projects
	r.GET("/projects", func(e *core.RequestEvent) error {
		records, err := fetchAndExpand(app, "projects",
			"public=true && status='published'", "-published_at", 200)
		if err != nil {
			records = []*core.Record{}
		}
		items := make([]EntityItem, 0, len(records))
		for _, rec := range records {
			items = append(items, projectToEntityItem(rec))
		}
		return renderPage(e, "project-list", ListPage{Items: items})
	})
	r.GET("/projects/{slug}", func(e *core.RequestEvent) error {
		slug := e.Request.PathValue("slug")
		rec, err := app.FindFirstRecordByData("projects", "slug", slug)
		if err != nil {
			return notFound("project not found")
		}
		app.ExpandRecord(rec, []string{"tags"}, nil)
		return renderPage(e, "project-detail", ProjectPage{
			Title:         rec.GetString("title"),
			PublishedAt:   formatDate(rec, "published_at"),
			Excerpt:       rec.GetString("excerpt"),
			HTML:          template.HTML(rec.GetString("html")),
			Tags:          expandedTags(rec),
			ProjectStatus: rec.GetString("project_status"),
		})
	})

	// Areas (public tags)
	r.GET("/areas", func(e *core.RequestEvent) error {
		records, err := app.FindRecordsByFilter("tags", "public=true", "name", 500, 0)
		if err != nil {
			records = []*core.Record{}
		}
		tags := make([]AreaTagView, 0, len(records))
		for _, r := range records {
			tags = append(tags, AreaTagView{
				TagItem:         TagItem{Name: r.GetString("name"), Slug: r.GetString("slug")},
				DescriptionHTML: template.HTML(r.GetString("description_html")),
			})
		}
		return renderPage(e, "areas-list", AreasPage{Tags: tags})
	})
	r.GET("/areas/{slug}", func(e *core.RequestEvent) error {
		slug := e.Request.PathValue("slug")
		tagRec, err := app.FindFirstRecordByData("tags", "slug", slug)
		if err != nil {
			return notFound("area not found")
		}
		records, err := fetchAndExpand(app, "entities",
			"public=true && tags?~'"+tagRec.Id+"' && published_at!=''", "-published_at", 500)
		if err != nil {
			records = []*core.Record{}
		}
		items := make([]EntityItem, 0, len(records))
		for _, rec := range records {
			items = append(items, entityRecordToItem(rec))
		}
		return renderPage(e, "area-detail", AreaDetailPage{
			Tag: AreaTagView{
				TagItem:         TagItem{Name: tagRec.GetString("name"), Slug: tagRec.GetString("slug")},
				DescriptionHTML: template.HTML(tagRec.GetString("description_html")),
			},
			Items: items,
		})
	})
}

// renderPostList is shared by /posts, /til, /now, /quotes, /fiction.
func renderPostList(app *pocketbase.PocketBase, e *core.RequestEvent, typeFilter, pageTitle string) error {
	filter := "public=true && status='published' && " + typeFilter
	records, err := fetchAndExpand(app, "posts", filter, "-published_at", 200)
	if err != nil {
		records = []*core.Record{}
	}
	items := make([]EntityItem, 0, len(records))
	for _, rec := range records {
		items = append(items, postToEntityItem(rec))
	}
	return renderPage(e, "post-list", ListPage{PageTitle: pageTitle, Items: items})
}

// notFound returns a 404 API error.
func notFound(msg string) error {
	return apis.NewNotFoundError(msg, nil)
}
