## ADDED Requirements

### Requirement: Media search dialog
The admin media page SHALL include a "Quick Add" button that opens a search dialog. The dialog SHALL contain: a media type selector (book, music, movie, tv, comic), a search text input, and a results list. Each result SHALL show the cover thumbnail (if available), title, creator, and year.

#### Scenario: Quick Add button is visible
- **WHEN** user is on the media logs page
- **THEN** a "Quick Add" button is visible alongside any existing "New" button

#### Scenario: Search returns results
- **WHEN** user selects a type, enters a query, and submits the search
- **THEN** the dialog fetches `GET /api/admin/search?q=...&type=...` and displays the results

#### Scenario: No results shows empty state
- **WHEN** the search returns zero results
- **THEN** the dialog shows a friendly empty state message

#### Scenario: Cover thumbnail shown when available
- **WHEN** a result has a `thumbnail_url`
- **THEN** a small cover image is rendered next to the title in the results list

### Requirement: Pre-fill media log form from search result
When a user selects a result from the quick-add search, the system SHALL open the "New Media Log" dialog with title, creator, thumbnail_url, and date_published pre-filled from the search result. The user can review/edit before submitting.

#### Scenario: Selecting a result pre-fills the form
- **WHEN** user clicks a search result
- **THEN** the search dialog closes and the new media log form opens with title, creator, thumbnail_url, and year pre-filled

#### Scenario: Pre-filled form is editable
- **WHEN** the new media log form opens with pre-filled values
- **THEN** user can modify any field before submitting

#### Scenario: Form submitted creates the record
- **WHEN** user submits the pre-filled (or modified) new media log form
- **THEN** `pb.collection('media_logs').create(...)` is called and the record appears in the list
