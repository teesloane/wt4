## 1. Go Backend — Media Search Proxy

- [x] 1.1 Add `TMDB_API_KEY` to the Go app's env var reading (e.g. in `main.go` or a config struct)
- [x] 1.2 Create `search.go` (or add to `routes.go`) with a handler for `GET /api/admin/search?q=...&type=...`
- [x] 1.3 Implement OpenLibrary search sub-function (book/comic types) returning normalised results
- [x] 1.4 Implement MusicBrainz search sub-function (music type) with required `User-Agent` header
- [x] 1.5 Implement TMDB search sub-function (movie/tv types); return empty array if key is missing
- [x] 1.6 Register the `/api/admin/search` route in `registerRoutes` (or equivalent)
- [ ] 1.7 Test the route manually: `curl "localhost:8090/api/admin/search?q=dune&type=book"`

## 2. Tag CRUD — Frontend

- [ ] 2.1 Add "New Tag" button to `TagsPage.tsx` header
- [ ] 2.2 Build `TagFormDialog` component (fields: name, slug, public toggle) with create mode
- [ ] 2.3 Wire create submit to `pb.collection('tags').create(...)` with slug auto-generation
- [ ] 2.4 Add row actions (edit, delete) to each tag row in the table
- [ ] 2.5 Wire edit action to open `TagFormDialog` in edit mode pre-filled with current values
- [ ] 2.6 Wire edit submit to `pb.collection('tags').update(id, ...)`
- [ ] 2.7 Add delete confirm dialog; wire confirm to `pb.collection('tags').delete(id)`
- [ ] 2.8 Invalidate the `["tags"]` query on any successful mutation so the list refreshes

## 3. Media Log CRUD — Frontend

- [ ] 3.1 Add "New" button to `MediaPage.tsx` header
- [ ] 3.2 Build `MediaLogFormDialog` component with all fields (title, creator, media_type, status, rating, dates, external_url, thumbnail_url, public)
- [ ] 3.3 Wire create submit to `pb.collection('media_logs').create(...)`
- [ ] 3.4 Add row actions (edit, delete) to each media log row
- [ ] 3.5 Wire edit action to open `MediaLogFormDialog` pre-filled
- [ ] 3.6 Wire edit submit to `pb.collection('media_logs').update(id, ...)`
- [ ] 3.7 Add delete confirm dialog; wire to `pb.collection('media_logs').delete(id)`
- [ ] 3.8 Invalidate the `["media", type]` query on any successful mutation

## 4. Media Quick Add — Frontend

- [ ] 4.1 Add "Quick Add" button to `MediaPage.tsx` header (alongside "New")
- [ ] 4.2 Build `MediaSearchDialog` component with type selector, query input, and results list (cover thumbnail, title, creator, year)
- [ ] 4.3 Wire search to `GET /api/admin/search?q=...&type=...` on form submit
- [ ] 4.4 On result click: close search dialog, open `MediaLogFormDialog` with pre-filled values (title, creator, thumbnail_url, date_published from year)
- [ ] 4.5 Verify quick-add → create flow end-to-end

## 5. Project CRUD — Frontend

- [ ] 5.1 Create `ProjectsPage.tsx` with a table listing all projects (title, status, project_status, published_at)
- [ ] 5.2 Register the page in the admin router and sidebar nav
- [ ] 5.3 Build `ProjectFormDialog` component (fields: title, slug, excerpt, markdown body, status, project_status, public, start_date, end_date)
- [ ] 5.4 Add "New Project" button; wire to `pb.collection('projects').create(...)` with slug auto-generation
- [ ] 5.5 Add row actions (edit, delete)
- [ ] 5.6 Wire edit to `pb.collection('projects').update(id, ...)` pre-filled
- [ ] 5.7 Add delete confirm dialog; wire to `pb.collection('projects').delete(id)`
- [ ] 5.8 Invalidate `["projects"]` query on any successful mutation
