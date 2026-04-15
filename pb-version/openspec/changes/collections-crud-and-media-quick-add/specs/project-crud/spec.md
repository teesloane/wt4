## ADDED Requirements

### Requirement: Projects list page
The admin SHALL have a projects page that lists all projects with columns: title, status (draft/published), project_status (ongoing/hiatus/completed), and published_at date. The page SHALL include a "New Project" button.

#### Scenario: Projects page renders
- **WHEN** user navigates to the Projects section
- **THEN** a table of all projects is shown with title, status, project_status, and date columns

### Requirement: Create project
The admin SHALL be able to create a new project via a dialog form with fields: title (required), slug (auto-generated from title if blank), excerpt, markdown body (textarea), status (draft/published), project_status (ongoing/hiatus/completed), public (boolean), start_date, and end_date. On submit, the record is created via `pb.collection('projects').create(...)`.

#### Scenario: Successful project creation
- **WHEN** user fills in title and submits
- **THEN** a new project record is created and appears in the list

#### Scenario: Slug auto-generated
- **WHEN** user fills in a title but leaves slug blank
- **THEN** the frontend generates a slug before submitting

#### Scenario: Status defaults to draft
- **WHEN** user creates a project without selecting a status
- **THEN** status defaults to "draft"

### Requirement: Edit project
The admin SHALL be able to edit an existing project via an edit dialog with the same fields as create. On submit, the record is updated via `pb.collection('projects').update(id, ...)`.

#### Scenario: Edit opens pre-filled
- **WHEN** user clicks the edit action on a project row
- **THEN** the dialog opens with current field values pre-filled

#### Scenario: Successful update
- **WHEN** user modifies fields and submits
- **THEN** the record is updated and the list reflects changes

### Requirement: Delete project
The admin SHALL be able to delete a project via a confirm dialog.

#### Scenario: Delete requires confirmation
- **WHEN** user clicks delete on a project row
- **THEN** a confirmation dialog appears before deletion

#### Scenario: Successful deletion
- **WHEN** user confirms
- **THEN** the project record is removed from the list
