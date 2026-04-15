## ADDED Requirements

### Requirement: Create media log
The admin SHALL be able to create a new media log via a dialog form with fields: title (required), creator, media_type (required; enum: book, music, film, tv, comic, game), status (required; enum: want_to_consume, consuming, consumed), rating (1–5, optional), date_consumed, date_finished, date_started, external_url, public (boolean), and thumbnail_url. On submit, the record is created via `pb.collection('media_logs').create(...)` and the list refreshes.

#### Scenario: Successful media log creation
- **WHEN** user fills in the required fields (title, media_type, status) and submits
- **THEN** a new media_log record is created and appears in the list

#### Scenario: Optional fields can be left blank
- **WHEN** user submits without filling optional fields
- **THEN** the record is created with null/empty values for those fields

### Requirement: Edit media log
The admin SHALL be able to edit an existing media log via an edit dialog opened from a row action. All fields from create are editable. On submit, the record is updated via `pb.collection('media_logs').update(id, ...)`.

#### Scenario: Edit opens pre-filled
- **WHEN** user clicks the edit action on a media log row
- **THEN** the dialog opens with all current field values pre-filled

#### Scenario: Successful update
- **WHEN** user modifies fields and submits
- **THEN** the record is updated and the list reflects the changes

### Requirement: Delete media log
The admin SHALL be able to delete a media log via a confirm dialog. On confirm, the record is deleted via `pb.collection('media_logs').delete(id)`.

#### Scenario: Delete requires confirmation
- **WHEN** user clicks delete on a media log row
- **THEN** a confirmation dialog appears naming the item being deleted

#### Scenario: Successful deletion
- **WHEN** user confirms deletion
- **THEN** the record is removed and disappears from the list
