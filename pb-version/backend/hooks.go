package main

import (
	"log"

	"weakty-pb/internal/markdown"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

// registerMarkdownHooks wires up pre-save hooks that auto-generate the html
// field from the markdown field for posts, projects, and tags.
func registerMarkdownHooks(app *pocketbase.PocketBase) {
	// posts and projects: markdown → html
	for _, col := range []string{"posts", "projects"} {
		col := col
		app.OnRecordCreate(col).BindFunc(func(e *core.RecordEvent) error {
			e.Record.Set("html", markdown.Render(e.Record.GetString("markdown")))
			return e.Next()
		})
		app.OnRecordUpdate(col).BindFunc(func(e *core.RecordEvent) error {
			e.Record.Set("html", markdown.Render(e.Record.GetString("markdown")))
			return e.Next()
		})
	}

	// tags: description → description_html
	app.OnRecordCreate("tags").BindFunc(func(e *core.RecordEvent) error {
		e.Record.Set("description_html", markdown.Render(e.Record.GetString("description")))
		return e.Next()
	})
	app.OnRecordUpdate("tags").BindFunc(func(e *core.RecordEvent) error {
		e.Record.Set("description_html", markdown.Render(e.Record.GetString("description")))
		return e.Next()
	})
}

// registerEntityHooks wires up create/update/delete hooks on all content
// collections so the entities collection stays in sync automatically.
func registerEntityHooks(app *pocketbase.PocketBase) {
	type hookDef struct {
		collection string
		entityType string
		subtypeKey string // record field to read subtype from; empty if static
		subtype    string // static subtype value when subtypeKey is empty
	}

	defs := []hookDef{
		{"posts", "post", "post_type", ""},
		{"links", "link", "", "link"},
		{"media_logs", "media_log", "media_type", ""},
		{"projects", "project", "", "project"},
	}

	for _, d := range defs {
		d := d // capture loop variable
		app.OnRecordAfterCreateSuccess(d.collection).BindFunc(func(e *core.RecordEvent) error {
			sub := d.subtype
			if d.subtypeKey != "" {
				sub = e.Record.GetString(d.subtypeKey)
			}
			syncEntity(app, e.Record, d.entityType, sub)
			return e.Next()
		})
		app.OnRecordAfterUpdateSuccess(d.collection).BindFunc(func(e *core.RecordEvent) error {
			sub := d.subtype
			if d.subtypeKey != "" {
				sub = e.Record.GetString(d.subtypeKey)
			}
			syncEntity(app, e.Record, d.entityType, sub)
			return e.Next()
		})
		app.OnRecordAfterDeleteSuccess(d.collection).BindFunc(func(e *core.RecordEvent) error {
			deleteEntity(app, e.Record.Id)
			return e.Next()
		})
	}
}

// syncEntity creates or updates the entity record that mirrors a source record.
func syncEntity(app *pocketbase.PocketBase, rec *core.Record, entityType, subtype string) {
	entitiesCol, err := app.FindCollectionByNameOrId("entities")
	if err != nil {
		log.Printf("syncEntity: find entities collection: %v", err)
		return
	}

	existing, _ := app.FindRecordsByFilter("entities", "source_id='"+rec.Id+"'", "", 1, 0)

	var entity *core.Record
	if len(existing) > 0 {
		entity = existing[0]
	} else {
		entity = core.NewRecord(entitiesCol)
	}

	slug := rec.GetString("slug")

	entity.Set("entity_type", entityType)
	entity.Set("source_id", rec.Id)
	entity.Set("title", rec.GetString("title"))
	entity.Set("slug", slug)
	entity.Set("url", entityURL(entityType, subtype, slug))
	// Posts no longer have a public field — derive visibility from status.
	if entityType == "post" {
		entity.Set("public", rec.GetString("status") == "published")
	} else {
		entity.Set("public", rec.GetBool("public"))
	}
	entity.Set("subtype", subtype)
	entity.Set("favourite", rec.GetBool("favourite"))
	entity.Set("tags", rec.GetStringSlice("tags"))

	switch entityType {
	case "post":
		entity.Set("content", rec.GetString("excerpt"))
		entity.Set("hero_url", rec.GetString("featured_image"))
		entity.Set("status", rec.GetString("status"))
		if dt := rec.GetDateTime("published_at"); !dt.IsZero() {
			entity.Set("published_at", dt)
		}
	case "link":
		entity.Set("content", rec.GetString("commentary"))
		entity.Set("hero_url", rec.GetString("og_image"))
		entity.Set("thumbnail_url", rec.GetString("og_image"))
		if dt := rec.GetDateTime("published_at"); !dt.IsZero() {
			entity.Set("published_at", dt)
		}
	case "media_log":
		entity.Set("content", rec.GetString("notes"))
		entity.Set("thumbnail_url", rec.GetString("thumbnail_url"))
		entity.Set("rating", rec.GetFloat("rating"))
		entity.Set("status", rec.GetString("status"))
		dt := rec.GetDateTime("date_consumed")
		if dt.IsZero() {
			dt = rec.GetDateTime("date_finished")
		}
		if !dt.IsZero() {
			entity.Set("published_at", dt)
		}
	case "project":
		entity.Set("content", rec.GetString("excerpt"))
		entity.Set("hero_url", rec.GetString("featured_image"))
		entity.Set("status", rec.GetString("status"))
		if dt := rec.GetDateTime("published_at"); !dt.IsZero() {
			entity.Set("published_at", dt)
		}
	}

	if err := app.Save(entity); err != nil {
		log.Printf("syncEntity(%s %s): %v", entityType, rec.Id, err)
	}
}

// deleteEntity removes the entity record that mirrors the given source record ID.
func deleteEntity(app *pocketbase.PocketBase, sourceID string) {
	existing, err := app.FindRecordsByFilter("entities", "source_id='"+sourceID+"'", "", 1, 0)
	if err != nil || len(existing) == 0 {
		return
	}
	if err := app.Delete(existing[0]); err != nil {
		log.Printf("deleteEntity(%s): %v", sourceID, err)
	}
}
