package main

import (
	"fmt"
	"log"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

func initCollections(app *pocketbase.PocketBase) error {
	if err := initTagsCollection(app); err != nil {
		return err
	}
	tagsCol, err := app.FindCollectionByNameOrId("tags")
	if err != nil {
		return fmt.Errorf("find tags collection: %w", err)
	}
	tagsColID := tagsCol.Id

	for _, fn := range []func(*pocketbase.PocketBase, string) error{
		initPostsCollection,
		initLinksCollection,
		initMediaLogsCollection,
		initProjectsCollection,
		initEntitiesCollection,
	} {
		if err := fn(app, tagsColID); err != nil {
			return err
		}
	}
	return nil
}

func initTagsCollection(app *pocketbase.PocketBase) error {
	if col, _ := app.FindCollectionByNameOrId("tags"); col != nil {
		return nil
	}
	log.Println("creating tags collection...")
	col := core.NewBaseCollection("tags")
	col.Fields.Add(&core.TextField{Name: "name", Required: true})
	col.Fields.Add(&core.TextField{Name: "slug", Required: true})
	col.Fields.Add(&core.BoolField{Name: "public"})
	col.Fields.Add(&core.TextField{Name: "featured_image"})
	col.Fields.Add(&core.TextField{Name: "description", Max: 1 << 20})
	col.Fields.Add(&core.TextField{Name: "description_html", Max: 1 << 20})
	col.Indexes = []string{
		"CREATE UNIQUE INDEX idx_tags_slug ON tags (slug)",
		"CREATE UNIQUE INDEX idx_tags_name ON tags (name)",
	}
	if err := app.Save(col); err != nil {
		return fmt.Errorf("save tags: %w", err)
	}
	log.Println("tags collection created")
	return nil
}

func initPostsCollection(app *pocketbase.PocketBase, tagsColID string) error {
	if col, _ := app.FindCollectionByNameOrId("posts"); col != nil {
		return nil
	}
	log.Println("creating posts collection...")
	col := core.NewBaseCollection("posts")
	col.Fields.Add(&core.TextField{Name: "title", Required: true})
	col.Fields.Add(&core.TextField{Name: "slug", Required: true})
	col.Fields.Add(&core.TextField{Name: "excerpt"})
	col.Fields.Add(&core.TextField{Name: "html", Max: 1 << 21})
	col.Fields.Add(&core.TextField{Name: "markdown", Max: 1 << 21})
	col.Fields.Add(&core.SelectField{
		Name:      "post_type",
		Values:    []string{"update", "post", "page", "til", "quote", "fiction", "process"},
		MaxSelect: 1,
	})
	col.Fields.Add(&core.SelectField{Name: "status", Values: []string{"draft", "published"}, MaxSelect: 1})
	col.Fields.Add(&core.BoolField{Name: "public"})
	col.Fields.Add(&core.BoolField{Name: "featured"})
	col.Fields.Add(&core.TextField{Name: "featured_image"})
	col.Fields.Add(&core.TextField{Name: "attribution"})
	col.Fields.Add(&core.TextField{Name: "attribution_url"})
	col.Fields.Add(&core.DateField{Name: "published_at"})
	col.Fields.Add(&core.JSONField{Name: "content_images"})
	col.Fields.Add(&core.RelationField{Name: "tags", CollectionId: tagsColID, MaxSelect: 0})
	col.Indexes = []string{
		"CREATE UNIQUE INDEX idx_posts_slug ON posts (slug)",
	}
	if err := app.Save(col); err != nil {
		return fmt.Errorf("save posts: %w", err)
	}
	log.Println("posts collection created")
	return nil
}

func initLinksCollection(app *pocketbase.PocketBase, tagsColID string) error {
	if col, _ := app.FindCollectionByNameOrId("links"); col != nil {
		return nil
	}
	log.Println("creating links collection...")
	col := core.NewBaseCollection("links")
	col.Fields.Add(&core.TextField{Name: "url", Required: true})
	col.Fields.Add(&core.TextField{Name: "title"})
	col.Fields.Add(&core.TextField{Name: "slug", Required: true})
	col.Fields.Add(&core.TextField{Name: "commentary", Max: 1 << 20})
	col.Fields.Add(&core.BoolField{Name: "public"})
	col.Fields.Add(&core.TextField{Name: "og_title"})
	col.Fields.Add(&core.TextField{Name: "og_description"})
	col.Fields.Add(&core.TextField{Name: "og_image"})
	col.Fields.Add(&core.BoolField{Name: "og_image_pinned"})
	col.Fields.Add(&core.DateField{Name: "published_at"})
	col.Fields.Add(&core.RelationField{Name: "tags", CollectionId: tagsColID, MaxSelect: 0})
	col.Indexes = []string{
		"CREATE UNIQUE INDEX idx_links_slug ON links (slug)",
	}
	if err := app.Save(col); err != nil {
		return fmt.Errorf("save links: %w", err)
	}
	log.Println("links collection created")
	return nil
}

func initMediaLogsCollection(app *pocketbase.PocketBase, tagsColID string) error {
	if col, _ := app.FindCollectionByNameOrId("media_logs"); col != nil {
		return nil
	}
	log.Println("creating media_logs collection...")
	col := core.NewBaseCollection("media_logs")
	col.Fields.Add(&core.TextField{Name: "title", Required: true})
	col.Fields.Add(&core.TextField{Name: "slug", Required: true})
	col.Fields.Add(&core.SelectField{
		Name:      "media_type",
		Values:    []string{"book", "comic", "movie", "music", "video_game"},
		MaxSelect: 1,
	})
	col.Fields.Add(&core.TextField{Name: "creator"})
	col.Fields.Add(&core.DateField{Name: "date_published"})
	col.Fields.Add(&core.TextField{Name: "thumbnail_url"})
	col.Fields.Add(&core.SelectField{
		Name:      "status",
		Values:    []string{"want_to_consume", "consuming", "consumed", "on_hold", "abandoned"},
		MaxSelect: 1,
	})
	col.Fields.Add(&core.DateField{Name: "date_consumed"})
	col.Fields.Add(&core.DateField{Name: "date_started"})
	col.Fields.Add(&core.DateField{Name: "date_finished"})
	col.Fields.Add(&core.NumberField{Name: "rating", Min: float64Ptr(1), Max: float64Ptr(5)})
	col.Fields.Add(&core.TextField{Name: "notes", Max: 1 << 20})
	col.Fields.Add(&core.TextField{Name: "external_url"})
	col.Fields.Add(&core.BoolField{Name: "public"})
	col.Fields.Add(&core.BoolField{Name: "favourite"})
	col.Fields.Add(&core.DateField{Name: "published_at"})
	col.Fields.Add(&core.RelationField{Name: "tags", CollectionId: tagsColID, MaxSelect: 0})
	col.Indexes = []string{
		"CREATE UNIQUE INDEX idx_media_logs_slug ON media_logs (slug)",
	}
	if err := app.Save(col); err != nil {
		return fmt.Errorf("save media_logs: %w", err)
	}
	log.Println("media_logs collection created")
	return nil
}

func initProjectsCollection(app *pocketbase.PocketBase, tagsColID string) error {
	if col, _ := app.FindCollectionByNameOrId("projects"); col != nil {
		return nil
	}
	log.Println("creating projects collection...")
	col := core.NewBaseCollection("projects")
	col.Fields.Add(&core.TextField{Name: "title", Required: true})
	col.Fields.Add(&core.TextField{Name: "slug", Required: true})
	col.Fields.Add(&core.TextField{Name: "excerpt"})
	col.Fields.Add(&core.TextField{Name: "html", Max: 1 << 21})
	col.Fields.Add(&core.TextField{Name: "markdown", Max: 1 << 21})
	col.Fields.Add(&core.TextField{Name: "featured_image"})
	col.Fields.Add(&core.SelectField{Name: "status", Values: []string{"draft", "published"}, MaxSelect: 1})
	col.Fields.Add(&core.SelectField{
		Name:      "project_status",
		Values:    []string{"ongoing", "hiatus", "completed"},
		MaxSelect: 1,
	})
	col.Fields.Add(&core.BoolField{Name: "featured"})
	col.Fields.Add(&core.BoolField{Name: "public"})
	col.Fields.Add(&core.DateField{Name: "published_at"})
	col.Fields.Add(&core.DateField{Name: "start_date"})
	col.Fields.Add(&core.DateField{Name: "end_date"})
	col.Fields.Add(&core.JSONField{Name: "links"})
	col.Fields.Add(&core.JSONField{Name: "images"})
	col.Fields.Add(&core.RelationField{Name: "tags", CollectionId: tagsColID, MaxSelect: 0})
	col.Indexes = []string{
		"CREATE UNIQUE INDEX idx_projects_slug ON projects (slug)",
	}
	if err := app.Save(col); err != nil {
		return fmt.Errorf("save projects: %w", err)
	}
	log.Println("projects collection created")
	return nil
}

func initEntitiesCollection(app *pocketbase.PocketBase, tagsColID string) error {
	if col, _ := app.FindCollectionByNameOrId("entities"); col != nil {
		return nil
	}
	log.Println("creating entities collection...")
	col := core.NewBaseCollection("entities")
	col.Fields.Add(&core.SelectField{
		Name:      "entity_type",
		Values:    []string{"post", "link", "media_log", "project"},
		MaxSelect: 1,
	})
	col.Fields.Add(&core.TextField{Name: "source_id", Required: true})
	col.Fields.Add(&core.TextField{Name: "title"})
	col.Fields.Add(&core.TextField{Name: "content", Max: 1 << 20})
	col.Fields.Add(&core.TextField{Name: "url"})
	col.Fields.Add(&core.TextField{Name: "slug"})
	col.Fields.Add(&core.TextField{Name: "hero_url"})
	col.Fields.Add(&core.TextField{Name: "thumbnail_url"})
	col.Fields.Add(&core.NumberField{Name: "rating"})
	col.Fields.Add(&core.TextField{Name: "subtype"})
	col.Fields.Add(&core.TextField{Name: "status"})
	col.Fields.Add(&core.BoolField{Name: "favourite"})
	col.Fields.Add(&core.DateField{Name: "published_at"})
	col.Fields.Add(&core.BoolField{Name: "public"})
	col.Fields.Add(&core.RelationField{Name: "tags", CollectionId: tagsColID, MaxSelect: 0})
	col.Indexes = []string{
		"CREATE UNIQUE INDEX idx_entities_source_id ON entities (source_id)",
	}
	if err := app.Save(col); err != nil {
		return fmt.Errorf("save entities: %w", err)
	}
	log.Println("entities collection created")
	return nil
}
