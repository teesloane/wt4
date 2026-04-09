package main

import (
	"embed"
	"html/template"
)

//go:embed templates/*.html
var templateFS embed.FS

var tmpl *template.Template

func init() {
	tmpl = template.Must(template.New("").ParseFS(templateFS, "templates/*.html"))
}
