package main

import (
	"mime"
	"os"
	"path/filepath"

	"github.com/pocketbase/pocketbase/core"
)

// registerAdminRoute serves the React admin SPA at /admin and /admin/{path...}.
//
// Static assets (JS, CSS bundles with hashed names) are served directly.
// All other paths fall back to index.html so React Router handles client-side
// navigation. Auth is enforced client-side by the React app; PocketBase rejects
// any API calls that lack a valid superuser token regardless.
//
// Build the app first: mise run admin:build
func registerAdminRoute(se *core.ServeEvent) {
	devMode := os.Getenv("TEMPLATE_DIR") != ""

	handler := func(e *core.RequestEvent) error {
		path := e.Request.PathValue("path")

		// Serve static assets (hashed filenames with known extensions) directly.
		if path != "" && filepath.Ext(path) != "" {
			var data []byte
			var err error
			if devMode {
				data, err = os.ReadFile("static/admin/" + path)
			} else {
				data, err = staticFS.ReadFile("static/admin/" + path)
			}
			if err == nil {
				ct := mime.TypeByExtension(filepath.Ext(path))
				if ct == "" {
					ct = "application/octet-stream"
				}
				e.Response.Header().Set("Content-Type", ct)
				if devMode {
					e.Response.Header().Set("Cache-Control", "no-store")
				} else {
					// Vite output filenames are content-hashed — safe to cache forever.
					e.Response.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
				}
				_, err = e.Response.Write(data)
				return err
			}
		}

		// SPA fallback: serve index.html for all unmatched routes.
		var indexHTML []byte
		var err error
		if devMode {
			indexHTML, err = os.ReadFile("static/admin/index.html")
		} else {
			indexHTML, err = staticFS.ReadFile("static/admin/index.html")
		}
		if err != nil {
			return e.NotFoundError("admin app not built — run: mise run admin:build", nil)
		}
		e.Response.Header().Set("Content-Type", "text/html; charset=utf-8")
		e.Response.Header().Set("Cache-Control", "no-store")
		_, err = e.Response.Write(indexHTML)
		return err
	}

	se.Router.GET("/admin", handler)
	se.Router.GET("/admin/{path...}", handler)
}
