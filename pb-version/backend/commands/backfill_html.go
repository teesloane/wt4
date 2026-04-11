package commands

import (
	"fmt"
	"log"

	"weakty-pb/internal/markdown"

	"github.com/pocketbase/pocketbase"
	"github.com/spf13/cobra"
)

// NewBackfillHTMLCmd returns a cobra command that regenerates the html field
// from the markdown field for all posts, projects, and tags.
func NewBackfillHTMLCmd(app *pocketbase.PocketBase) *cobra.Command {
	return &cobra.Command{
		Use:   "backfill-html",
		Short: "Regenerate html fields from markdown for all posts, projects, and tags",
		RunE: func(cmd *cobra.Command, args []string) error {
			if err := app.Bootstrap(); err != nil {
				return fmt.Errorf("bootstrap: %w", err)
			}
			return backfillHTML(app)
		},
	}
}

func backfillHTML(app *pocketbase.PocketBase) error {
	type job struct {
		collection string
		srcField   string
		dstField   string
	}
	jobs := []job{
		{"posts", "markdown", "html"},
		{"projects", "markdown", "html"},
		{"tags", "description", "description_html"},
	}

	for _, j := range jobs {
		records, err := app.FindAllRecords(j.collection)
		if err != nil {
			return fmt.Errorf("fetch %s: %w", j.collection, err)
		}
		updated := 0
		for _, rec := range records {
			generated := markdown.Render(rec.GetString(j.srcField))
			if rec.GetString(j.dstField) == generated {
				continue
			}
			rec.Set(j.dstField, generated)
			if err := app.Save(rec); err != nil {
				log.Printf("backfill %s %s: %v", j.collection, rec.Id, err)
				continue
			}
			updated++
		}
		log.Printf("backfill %s: %d/%d records updated", j.collection, updated, len(records))
	}
	return nil
}
