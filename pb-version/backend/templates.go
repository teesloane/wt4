package main

import (
	"embed"
	"mime"
	"net/http"
	"os"
	"path/filepath"

	"github.com/CloudyKit/jet/v6"
	"github.com/CloudyKit/jet/v6/loaders/embedfs"
	"github.com/pocketbase/pocketbase/core"
)

//go:embed templates/*.html
var templateFS embed.FS

//go:embed static
var staticFS embed.FS

var jetSet *jet.Set

func init() {
	loader := embedfs.NewLoader("templates", templateFS)
	jetSet = jet.NewSet(loader)
}

// activeSet returns a live-reloading set when TEMPLATE_DIR is set (dev),
// otherwise returns the embedded production set.
func activeSet() *jet.Set {
	if dir := os.Getenv("TEMPLATE_DIR"); dir != "" {
		s := jet.NewSet(jet.NewOSFileSystemLoader(dir), jet.InDevelopmentMode())
		return s
	}
	return jetSet
}

// renderPage executes a Jet template by file name with the given data.
func renderPage(e *core.RequestEvent, name string, data any) error {
	e.Response.Header().Set("Content-Type", "text/html; charset=utf-8")
	e.Response.WriteHeader(http.StatusOK)
	tmpl, err := activeSet().GetTemplate(name + ".html")
	if err != nil {
		return err
	}
	return tmpl.Execute(e.Response, make(jet.VarMap), data)
}

// render404 renders the 404 template with a Not Found status.
func render404(e *core.RequestEvent) error {
	e.Response.Header().Set("Content-Type", "text/html; charset=utf-8")
	e.Response.WriteHeader(http.StatusNotFound)
	tmpl, err := activeSet().GetTemplate("404.html")
	if err != nil {
		_, werr := e.Response.Write([]byte("<h1>404 Not Found</h1><a href='/'>Home</a>"))
		if werr != nil {
			return werr
		}
		return nil
	}
	return tmpl.Execute(e.Response, make(jet.VarMap), nil)
}

func registerStaticHandler(se *core.ServeEvent) {
	devMode := os.Getenv("TEMPLATE_DIR") != ""

	se.Router.GET("/static/{path...}", func(e *core.RequestEvent) error {
		path := e.Request.PathValue("path")

		var data []byte
		var err error
		if devMode {
			// In dev mode serve from disk so css:watch changes are visible immediately.
			data, err = os.ReadFile("static/" + path)
		} else {
			data, err = staticFS.ReadFile("static/" + path)
		}
		if err != nil {
			return e.NotFoundError("", nil)
		}

		ct := mime.TypeByExtension(filepath.Ext(path))
		if ct == "" {
			ct = "application/octet-stream"
		}
		e.Response.Header().Set("Content-Type", ct)
		if devMode {
			e.Response.Header().Set("Cache-Control", "no-store")
		} else {
			e.Response.Header().Set("Cache-Control", "public, max-age=3600")
		}
		_, err = e.Response.Write(data)
		return err
	})
}
