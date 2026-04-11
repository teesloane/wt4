package main

import "html/template"

type TagItem struct {
	Name string
	Slug string
}

type EntityItem struct {
	ID          string
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
	Creator     string
	Tags        []TagItem
	Favourite   bool
	Current     bool
}

type ListPage struct {
	PageTitle string
	Items     []EntityItem
}

type PostPage struct {
	Title         string
	PublishedAt   string
	Excerpt       string
	HTML          template.HTML
	Tags          []TagItem
	Attribution   string
	AttrURL       string
	PostType      string
	FeaturedImage string
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
	FeaturedImage string
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

type BookItem struct {
	Title   string
	Creator string
}

type NowPreview struct {
	Title string
	URL   string
	HTML  template.HTML
}

type AreaItem struct {
	Name  string `db:"name"`
	Slug  string `db:"slug"`
	Count int    `db:"cnt"`
}

type HomePage struct {
	Posts            []EntityItem
	RecentFiction    []EntityItem
	LatestStory      *EntityItem
	Projects         []EntityItem
	CurrentlyReading []BookItem
	Update           *NowPreview
	TopAreas         []AreaItem
}

type MediaLogItem struct {
	Title     string
	Creator   string
	MediaType string
	Thumbnail string
}

type NowDetailPage struct {
	Title         string
	PublishedAt   string
	FeaturedImage string
	HTML          template.HTML
	WeekEntities  []EntityItem
	WeekMediaLogs []MediaLogItem
	Updates       []EntityItem
	CurrentID     string
}
