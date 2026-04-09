package main

import "html/template"

type TagItem struct {
	Name string
	Slug string
}

type EntityItem struct {
	EntityType  string
	Subtype     string
	TypeLabel   string
	Title       string
	Slug        string
	URL         string
	PublishedAt string
	Excerpt     string
	Hero        string
	Thumbnail   string
	Tags        []TagItem
	Favourite   bool
}

type ListPage struct {
	PageTitle string
	Items     []EntityItem
}

type PostPage struct {
	Title       string
	PublishedAt string
	Excerpt     string
	HTML        template.HTML
	Tags        []TagItem
	Attribution string
	AttrURL     string
	PostType    string
}

type LinkPage struct {
	Title       string
	SiteURL     string
	Commentary  template.HTML
	OGImage     string
	PublishedAt string
	Tags        []TagItem
}

type MediaLogPage struct {
	Title       string
	Creator     string
	MediaType   string
	Status      string
	Rating      string
	PublishedAt string
	Notes       template.HTML
	ExternalURL string
	Thumbnail   string
	Tags        []TagItem
}

type ProjectPage struct {
	Title         string
	PublishedAt   string
	Excerpt       string
	HTML          template.HTML
	Tags          []TagItem
	ProjectStatus string
}

type AreaTagView struct {
	TagItem
	DescriptionHTML template.HTML
}

type AreasPage struct {
	Tags []AreaTagView
}

type AreaDetailPage struct {
	Tag   AreaTagView
	Items []EntityItem
}
