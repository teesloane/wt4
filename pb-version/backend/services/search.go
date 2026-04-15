package services

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"

	"github.com/pocketbase/pocketbase/core"
)

// SearchResult is the normalised shape returned to the frontend.
type SearchResult struct {
	ExternalID   string  `json:"external_id"`
	Type         string  `json:"type"`
	Title        string  `json:"title"`
	Creator      string  `json:"creator"`
	Year         string  `json:"year"`
	ThumbnailURL *string `json:"thumbnail_url"`
}

// HandleMediaSearch is the handler for GET /api/admin/search?q=...&type=...
func HandleMediaSearch(e *core.RequestEvent) error {
	q := strings.TrimSpace(e.Request.URL.Query().Get("q"))
	mediaType := strings.TrimSpace(e.Request.URL.Query().Get("type"))

	if q == "" {
		return e.JSON(http.StatusBadRequest, map[string]string{"error": "q parameter is required"})
	}

	var results []SearchResult
	var err error

	switch mediaType {
	case "book", "comic":
		results, err = searchOpenLibrary(q, mediaType)
	case "music":
		results, err = searchMusicBrainz(q)
	case "movie":
		results, err = searchTMDB(q, "movie")
	case "tv":
		results, err = searchTMDB(q, "tv")
	default:
		return e.JSON(http.StatusBadRequest, map[string]string{"error": "type must be one of: book, comic, music, movie, tv"})
	}

	if err != nil {
		fmt.Printf("media search error (type=%s q=%s): %v\n", mediaType, q, err)
		results = []SearchResult{}
	}
	if results == nil {
		results = []SearchResult{}
	}

	return e.JSON(http.StatusOK, results)
}

// ─── OpenLibrary ─────────────────────────────────────────────────────────────

func searchOpenLibrary(q, mediaType string) ([]SearchResult, error) {
	apiURL := fmt.Sprintf(
		"https://openlibrary.org/search.json?q=%s&fields=key,title,author_name,first_publish_year,cover_i&limit=15",
		url.QueryEscape(q),
	)

	resp, err := http.Get(apiURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var payload struct {
		Docs []struct {
			Key              string   `json:"key"`
			Title            string   `json:"title"`
			AuthorName       []string `json:"author_name"`
			FirstPublishYear int      `json:"first_publish_year"`
			CoverI           int      `json:"cover_i"`
		} `json:"docs"`
	}
	if err := json.Unmarshal(body, &payload); err != nil {
		return nil, err
	}

	results := make([]SearchResult, 0, len(payload.Docs))
	for _, doc := range payload.Docs {
		externalID := strings.TrimPrefix(doc.Key, "/works/")

		creator := ""
		if len(doc.AuthorName) > 0 {
			creator = doc.AuthorName[0]
		}

		year := ""
		if doc.FirstPublishYear != 0 {
			year = fmt.Sprintf("%d", doc.FirstPublishYear)
		}

		var thumbURL *string
		if doc.CoverI != 0 {
			s := fmt.Sprintf("https://covers.openlibrary.org/b/id/%d-M.jpg", doc.CoverI)
			thumbURL = &s
		}

		results = append(results, SearchResult{
			ExternalID:   externalID,
			Type:         mediaType,
			Title:        doc.Title,
			Creator:      creator,
			Year:         year,
			ThumbnailURL: thumbURL,
		})
	}
	return results, nil
}

// ─── MusicBrainz ─────────────────────────────────────────────────────────────

func searchMusicBrainz(q string) ([]SearchResult, error) {
	apiURL := fmt.Sprintf(
		"https://musicbrainz.org/ws/2/release-group?query=%s&fmt=json&limit=15",
		url.QueryEscape(q),
	)

	req, err := http.NewRequest("GET", apiURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "weakty-pb/1.0 (tylersloane@gmail.com)")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var payload struct {
		ReleaseGroups []struct {
			ID           string `json:"id"`
			Title        string `json:"title"`
			FirstRelease string `json:"first-release-date"`
			ArtistCredit []struct {
				Name   string `json:"name"`
				Artist struct {
					Name string `json:"name"`
				} `json:"artist"`
			} `json:"artist-credit"`
		} `json:"release-groups"`
	}
	if err := json.Unmarshal(body, &payload); err != nil {
		return nil, err
	}

	results := make([]SearchResult, 0, len(payload.ReleaseGroups))
	for _, rg := range payload.ReleaseGroups {
		creator := ""
		if len(rg.ArtistCredit) > 0 {
			if rg.ArtistCredit[0].Artist.Name != "" {
				creator = rg.ArtistCredit[0].Artist.Name
			} else {
				creator = rg.ArtistCredit[0].Name
			}
		}

		year := ""
		if len(rg.FirstRelease) >= 4 {
			year = rg.FirstRelease[:4]
		}

		results = append(results, SearchResult{
			ExternalID:   rg.ID,
			Type:         "music",
			Title:        rg.Title,
			Creator:      creator,
			Year:         year,
			ThumbnailURL: nil,
		})
	}
	return results, nil
}

// ─── TMDB ─────────────────────────────────────────────────────────────────────

func searchTMDB(q, tmdbType string) ([]SearchResult, error) {
	apiKey := os.Getenv("TMDB_API_KEY")
	if apiKey == "" {
		return []SearchResult{}, nil
	}

	apiURL := fmt.Sprintf(
		"https://api.themoviedb.org/3/search/%s?api_key=%s&query=%s&page=1",
		tmdbType, apiKey, url.QueryEscape(q),
	)

	resp, err := http.Get(apiURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var payload struct {
		Results []struct {
			ID           int    `json:"id"`
			Title        string `json:"title"`
			Name         string `json:"name"`
			ReleaseDate  string `json:"release_date"`
			FirstAirDate string `json:"first_air_date"`
			PosterPath   string `json:"poster_path"`
		} `json:"results"`
	}
	if err := json.Unmarshal(body, &payload); err != nil {
		return nil, err
	}

	results := make([]SearchResult, 0, len(payload.Results))
	for _, item := range payload.Results {
		title := item.Title
		if title == "" {
			title = item.Name
		}

		date := item.ReleaseDate
		if date == "" {
			date = item.FirstAirDate
		}
		year := ""
		if len(date) >= 4 {
			year = date[:4]
		}

		var thumbURL *string
		if item.PosterPath != "" {
			s := "https://image.tmdb.org/t/p/w500" + item.PosterPath
			thumbURL = &s
		}

		results = append(results, SearchResult{
			ExternalID:   fmt.Sprintf("%s:%d", tmdbType, item.ID),
			Type:         tmdbType,
			Title:        title,
			Creator:      "",
			Year:         year,
			ThumbnailURL: thumbURL,
		})
	}
	return results, nil
}
