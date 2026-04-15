## ADDED Requirements

### Requirement: Media search proxy route
The Go backend SHALL expose `GET /api/admin/search?q=<query>&type=<type>` that fans out to the appropriate external API based on `type` and returns a normalised JSON array.

Supported types:
- `book` → OpenLibrary search API (`https://openlibrary.org/search.json`)
- `music` → MusicBrainz search API (`https://musicbrainz.org/ws/2/release-group`)
- `movie` → TMDB movie search (`https://api.themoviedb.org/3/search/movie`)
- `tv` → TMDB TV search (`https://api.themoviedb.org/3/search/tv`)
- `comic` → OpenLibrary (comics are books)

Normalised response item shape:
```json
{
  "external_id": "string",
  "type": "book|music|movie|tv|comic",
  "title": "string",
  "creator": "string",
  "year": "string",
  "thumbnail_url": "string|null"
}
```

#### Scenario: Book search returns results
- **WHEN** `GET /api/admin/search?q=dune&type=book` is requested
- **THEN** the route queries OpenLibrary, normalises the results, and returns a JSON array

#### Scenario: Movie search returns results
- **WHEN** `GET /api/admin/search?q=blade+runner&type=movie` is requested
- **THEN** the route queries TMDB and returns normalised results

#### Scenario: Music search returns results
- **WHEN** `GET /api/admin/search?q=radiohead&type=music` is requested
- **THEN** the route queries MusicBrainz and returns normalised results

#### Scenario: TMDB key missing degrades gracefully
- **WHEN** `TMDB_API_KEY` is not set and a movie/tv search is requested
- **THEN** the route returns an empty array (not an error status)

#### Scenario: Missing query parameter
- **WHEN** `q` is empty or missing
- **THEN** the route returns HTTP 400 with a JSON error

### Requirement: MusicBrainz User-Agent header
The Go backend SHALL send a `User-Agent` header on all MusicBrainz requests per their API ToS (format: `weakty-pb/<version> (contact@email)`).

#### Scenario: MusicBrainz request includes User-Agent
- **WHEN** a music search is performed
- **THEN** the HTTP request to MusicBrainz includes an identifying User-Agent header
