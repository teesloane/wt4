## Context

The pb-version admin frontend is a React SPA (Vite + shadcn/ui + TanStack Query) that talks directly to PocketBase via the JS SDK. The Go backend handles public-facing routes and RSS; admin mutations are done client-side via `pb.collection(...).create/update/delete()`. Three collection pages (Tags, Media, Projects) are currently read-only — they fetch data but have no create/edit/delete affordances. A fourth feature (media quick-add) requires a Go proxy route to avoid CORS and API-key exposure.

## Goals / Non-Goals

**Goals:**
- Full CRUD UI for `tags`, `media_logs`, and `projects` in the admin frontend
- Go backend route `/api/admin/search` that proxies OpenLibrary, MusicBrainz, and TMDB
- Frontend search dialog that queries the proxy and pre-fills a new media log form
- Parity with the key capabilities of the Elixir version for these collections

**Non-Goals:**
- Rich text / markdown editing for projects (plain textarea is fine for now)
- Image upload for tags, media logs, or projects (thumbnail URLs only)
- Public-facing project detail page changes
- Pagination in admin list views (existing 500-record limit is acceptable)
- Authentication on the `/api/admin/search` route (PocketBase admin auth protects the page)

## Decisions

### 1. CRUD pattern: modal dialogs, not separate pages

All three collections use inline dialogs (shadcn `<Dialog>`) for create and edit — same pattern used in PostsPage for delete confirmation. Avoids new routes and keeps the admin SPA simple. Projects are complex enough that a full-page editor _could_ be justified, but the PostEditorPage already exists for that level of complexity; projects don't need it at this stage.

**Alternative considered**: Separate `/admin/tags/new`, `/admin/tags/:id/edit` routes. Rejected — overkill for collections where the form is < 6 fields.

### 2. Media log form: combined quick-add + manual entry

The new media log dialog starts with an optional quick-add search step. User can skip it and fill the form manually, or search to pre-fill. This is a single Dialog with two "modes" controlled by local state.

**Alternative considered**: Separate "Quick Add" button and "New Media Log" button. Rejected — adds surface area; one entry point is cleaner.

### 3. Go proxy for external search APIs

External media APIs (especially TMDB) require an API key that must not be in the browser bundle. Go backend proxies the request, normalises the response shape across all three APIs, and returns a unified JSON array. The route is under `/api/admin/` to signal intent; no PocketBase auth middleware is added at this stage (the admin is behind PocketBase's own auth gate).

**Normalised response shape:**
```json
[
  {
    "external_id": "string",
    "type": "book|music|movie|tv|comic",
    "title": "string",
    "creator": "string",
    "year": "string",
    "thumbnail_url": "string|null"
  }
]
```

**Alternative considered**: Serverless function or client-side fetch with CORS proxy. Rejected — we already have a Go binary; adding a handler is trivial.

### 4. Slug auto-generation: frontend mirrors Elixir logic

When creating a tag or project without an explicit slug, the frontend generates one from the name/title using the same rule as the Elixir version: lowercase, replace non-alphanumeric runs with `-`, trim leading/trailing `-`. This avoids a round-trip and matches existing data.

### 5. TMDB API key configuration

`TMDB_API_KEY` is read from the environment at startup. The search handler returns an empty result set (not an error) if the key is absent, so the quick-add UI degrades gracefully (book and music still work).

## Risks / Trade-offs

- **No optimistic updates** → mutations trigger a query invalidation; list briefly shows stale data then re-fetches. Acceptable for an admin tool.
- **TMDB rate limits** → free tier is 40 requests/10s; unlikely to be hit in single-user admin use. No throttling implemented.
- **MusicBrainz strict rate limit (1 req/s)** → add `User-Agent` header as required by their ToS; single-user admin is fine.
- **PocketBase collection schema must match** → if the `media_logs` PocketBase collection is missing a field (e.g. `date_started`), the create will silently ignore it. No schema migration tooling exists on the PocketBase side (schema is managed in PocketBase admin).

## Migration Plan

1. Deploy Go binary with new `/api/admin/search` route (additive, no breaking changes)
2. Set `TMDB_API_KEY` env var in deploy config
3. Deploy frontend with new CRUD dialogs (purely additive UI)
4. No database migrations required — PocketBase schema already has these collections
