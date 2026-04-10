package main

import (
	"embed"
	"html/template"
	"mime"
	"os"
	"path/filepath"

	"github.com/pocketbase/pocketbase/core"
)

//go:embed templates/*.html
var templateFS embed.FS

//go:embed static
var staticFS embed.FS

var tmpl *template.Template

func init() {
	tmpl = template.Must(template.New("").ParseFS(templateFS, "templates/*.html"))
}

// activeTemplates returns disk-loaded templates when TEMPLATE_DIR is set
// (hot reload in dev), otherwise returns the embedded templates.
func activeTemplates() *template.Template {
	if dir := os.Getenv("TEMPLATE_DIR"); dir != "" {
		return template.Must(template.New("").ParseGlob(dir + "/*.html"))
	}
	return tmpl
}

func registerStaticHandler(se *core.ServeEvent) {
	se.Router.GET("/static/{path...}", func(e *core.RequestEvent) error {
		path := e.Request.PathValue("path")
		data, err := staticFS.ReadFile("static/" + path)
		if err != nil {
			return e.NotFoundError("", nil)
		}
		ct := mime.TypeByExtension(filepath.Ext(path))
		if ct == "" {
			ct = "application/octet-stream"
		}
		e.Response.Header().Set("Content-Type", ct)
		e.Response.Header().Set("Cache-Control", "public, max-age=3600")
		_, err = e.Response.Write(data)
		return err
	})
}
