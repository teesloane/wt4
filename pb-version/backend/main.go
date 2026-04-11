package main

import (
	"fmt"
	"log"
	"os"

	"weakty-pb/commands"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

func main() {
	app := pocketbase.New()

	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		if err := initCollections(app); err != nil {
			return fmt.Errorf("initCollections: %w", err)
		}

		registerMarkdownHooks(app)
		registerEntityHooks(app)
		registerRoutes(app, se)

		// Run migration if MIGRATE_DB env var points to an Ash SQLite database.
		if dbPath := os.Getenv("MIGRATE_DB"); dbPath != "" {
			if err := migrateFromExample(app, dbPath); err != nil {
				log.Printf("migration warning: %v", err)
			}
		}

		return se.Next()
	})

	app.RootCmd.AddCommand(commands.NewBackfillHTMLCmd(app))

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
