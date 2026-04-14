package main

import (
	"log"

	"github.com/pocketbase/pocketbase/core"
)

// applyMigrations runs idempotent schema patches on every boot.
// Once a migration has been applied to all environments, remove its block here.
func applyMigrations(app core.App) {
	// Drop the public field from posts and expand status values to include
	// private and archived. public is replaced entirely by status='published'.
	if col, err := app.FindCollectionByNameOrId("posts"); err == nil {
		changed := false

		if f := col.Fields.GetByName("public"); f != nil {
			col.Fields.RemoveById(f.GetId())
			changed = true
			log.Println("schema_migrations: removed public field from posts")
		}

		if f := col.Fields.GetByName("status"); f != nil {
			sf := f.(*core.SelectField)
			want := []string{"draft", "published", "private", "archived"}
			if !stringSliceEqual(sf.Values, want) {
				sf.Values = want
				changed = true
				log.Println("schema_migrations: updated posts status values")
			}
		}

		if changed {
			if err := app.Save(col); err != nil {
				log.Printf("schema_migrations: save posts collection: %v", err)
			}
		}
	}
}

func stringSliceEqual(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
