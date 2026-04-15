## Why

The admin frontend currently only allows reading tags, media items, and projects — you can't create, update, or delete them. Adding full CRUD for these collections and a media quick-add flow (with external API search) removes the main reason to fall back to the raw PocketBase admin UI.

## What Changes

- **Tags**: Add create, edit, and delete to the tags list page (currently read-only)
- **Media logs**: Add create (with quick-add search), edit, and delete to the media page
- **Projects**: Add create, edit, and delete to a new projects list/edit page
- **Go backend**: New route `GET /api/admin/search?q=...&type=book|music|movie|comic|tv` that proxies OpenLibrary, MusicBrainz, and TMDB search APIs
- **Quick-add UI**: Search component (type selector + query input + cover-thumbnail results) that pre-fills a new media log form on result select

## Capabilities

### New Capabilities

- `tag-crud`: Create, edit (name, slug, public flag), and delete tags via the admin frontend
- `media-log-crud`: Create, edit, and delete media log records via the admin frontend
- `project-crud`: Create, edit, and delete projects via the admin frontend
- `media-search-api`: Go backend proxy route that fans out to OpenLibrary / MusicBrainz / TMDB and returns normalised search results
- `media-quick-add`: Frontend search UI that queries the backend proxy and pre-fills the new media log form

### Modified Capabilities

<!-- none -->

## Impact

- **Frontend**: `TagsPage`, `MediaPage` gain mutation buttons + dialogs; new `ProjectsPage`; new `MediaSearchDialog` component
- **Backend**: New `routes_admin.go` (or additions to `routes.go`) with `/api/admin/search`; needs `TMDB_API_KEY` env var
- **Dependencies**: No new npm packages expected; TMDB requires a free API key configured at deploy time
- **PocketBase collections touched**: `tags`, `media_logs`, `projects`
