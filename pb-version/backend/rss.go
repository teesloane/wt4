package main

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

func registerRSSRoute(app *pocketbase.PocketBase, se *core.ServeEvent) {
	se.Router.GET("/rss.xml", func(e *core.RequestEvent) error {
		return handleRSS(app, e)
	})
	se.Router.GET("/rss/", func(e *core.RequestEvent) error {
		return handleRSS(app, e)
	})
}

func handleRSS(app *pocketbase.PocketBase, e *core.RequestEvent) error {
	records, err := app.FindRecordsByFilter(
		"posts",
		"public=true && status='published'",
		"-published_at",
		100, 0,
	)
	if err != nil {
		records = []*core.Record{}
	}
	for _, r := range records {
		app.ExpandRecord(r, []string{"tags"}, nil)
	}

	xml := buildRSSFeed(records)
	e.Response.Header().Set("Content-Type", "application/rss+xml; charset=utf-8")
	e.Response.WriteHeader(http.StatusOK)
	_, err = e.Response.Write([]byte(xml))
	return err
}

func buildRSSFeed(posts []*core.Record) string {
	lastBuildDate := time.Now().UTC()
	if len(posts) > 0 {
		dt := posts[0].GetDateTime("published_at")
		if !dt.IsZero() {
			lastBuildDate = dt.Time()
		}
	}

	var items strings.Builder
	for _, p := range posts {
		items.WriteString(buildRSSItem(p))
	}

	return fmt.Sprintf(`<?xml version="1.0" encoding="UTF-8" ?>
<rss
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:content="http://purl.org/rss/1.0/modules/content/"
    xmlns:atom="http://www.w3.org/2005/Atom"
    version="2.0"
    xmlns:media="http://search.yahoo.com/mrss/"
>
  <channel>
    <title><![CDATA[Weakty]]></title>
    <description><![CDATA[Hello, I'm Ty.]]></description>
    <link>https://weakty.com/</link>
    <image>
      <url>https://weakty.com/favicon.png</url>
      <title>Weakty</title>
      <link>https://weakty.com/</link>
    </image>
    <generator>Weakty PocketBase</generator>
    <lastBuildDate>%s</lastBuildDate>
    <atom:link href="https://weakty.com/rss.xml" rel="self" type="application/rss+xml" />
    <ttl>60</ttl>
    %s
  </channel>
</rss>`, formatRFC822(lastBuildDate), items.String())
}

func buildRSSItem(rec *core.Record) string {
	slug := rec.GetString("slug")
	postType := rec.GetString("post_type")
	title := rec.GetString("title")
	if title == "" {
		title = "Untitled"
	}
	excerpt := rec.GetString("excerpt")
	html := rec.GetString("html")
	featuredImage := rec.GetString("featured_image")

	// Build URL
	url := "https://weakty.com/posts/" + slug
	if postType == "til" {
		url = "https://weakty.com/til/" + slug
	} else if postType == "update" {
		url = "https://weakty.com/now/" + slug
	} else if postType == "quote" {
		url = "https://weakty.com/quotes/" + slug
	}

	pubDate := formatRFC822(time.Now().UTC())
	dt := rec.GetDateTime("published_at")
	if !dt.IsZero() {
		pubDate = formatRFC822(dt.Time())
	}

	categories := buildRSSCategories(rec)

	mediaTag := ""
	if featuredImage != "" {
		imgURL := "https://weakty.com" + fileURL("posts", rec.Id, featuredImage, "")
		mediaTag = fmt.Sprintf(`<media:content url="%s" medium="image" />`, escapeXMLAttr(imgURL))
	}

	return fmt.Sprintf(`    <item>
      <title><![CDATA[%s]]></title>
      <description><![CDATA[%s]]></description>
      <link>%s</link>
      <guid isPermaLink="false">%s</guid>
      %s
      <dc:creator><![CDATA[Ty]]></dc:creator>
      <pubDate>%s</pubDate>
      <content:encoded><![CDATA[%s]]></content:encoded>
      %s
    </item>
`, escapeCDATA(title), escapeCDATA(excerpt), url, rec.Id, categories, pubDate, escapeCDATA(html), mediaTag)
}

func buildRSSCategories(rec *core.Record) string {
	var sb strings.Builder
	for _, t := range rec.ExpandedAll("tags") {
		fmt.Fprintf(&sb, `<category><![CDATA[%s]]></category>`, escapeCDATA(t.GetString("name")))
		sb.WriteString("\n      ")
	}
	return sb.String()
}

func formatRFC822(t time.Time) string {
	return t.UTC().Format("Mon, 02 Jan 2006 15:04:05 GMT")
}

func escapeCDATA(s string) string {
	return strings.ReplaceAll(s, "]]>", "]]]]><![CDATA[>")
}

func escapeXMLAttr(s string) string {
	s = strings.ReplaceAll(s, "&", "&amp;")
	s = strings.ReplaceAll(s, "<", "&lt;")
	s = strings.ReplaceAll(s, ">", "&gt;")
	s = strings.ReplaceAll(s, `"`, "&quot;")
	return s
}
