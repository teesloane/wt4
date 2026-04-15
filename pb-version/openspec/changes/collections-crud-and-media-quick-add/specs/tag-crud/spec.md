## ADDED Requirements

### Requirement: Create tag
The admin SHALL be able to create a new tag via a dialog form with fields: name (required), slug (auto-generated from name if blank), and public (boolean toggle). On submit, the record is created via `pb.collection('tags').create(...)` and the list refreshes.

#### Scenario: Successful tag creation
- **WHEN** user opens the "New Tag" dialog, fills in a name, and submits
- **THEN** the tag is created in PocketBase and appears in the list

#### Scenario: Slug auto-generated
- **WHEN** user fills in a name but leaves slug blank
- **THEN** the frontend generates a slug (lowercase, hyphens for non-alphanumeric) before submitting

#### Scenario: Duplicate name rejected
- **WHEN** user tries to create a tag with a name that already exists
- **THEN** PocketBase returns an error and the dialog displays it without closing

### Requirement: Edit tag
The admin SHALL be able to edit an existing tag's name, slug, and public flag via an edit dialog opened from a row action. On submit, the record is updated via `pb.collection('tags').update(id, ...)` and the list refreshes.

#### Scenario: Edit opens pre-filled
- **WHEN** user clicks the edit action on a tag row
- **THEN** the dialog opens with the tag's current name, slug, and public value pre-filled

#### Scenario: Successful update
- **WHEN** user modifies fields and submits
- **THEN** the tag is updated and the list shows the new values

### Requirement: Delete tag
The admin SHALL be able to delete a tag via a confirm dialog. On confirm, the record is deleted via `pb.collection('tags').delete(id)` and removed from the list.

#### Scenario: Delete requires confirmation
- **WHEN** user clicks the delete action on a tag row
- **THEN** a confirmation dialog appears before the delete is executed

#### Scenario: Successful deletion
- **WHEN** user confirms deletion
- **THEN** the tag is removed from PocketBase and disappears from the list
