# Posts LiveView Implementation

This document describes the LiveView implementation for the Posts feature, building on the Posts domain added in commit d162abe.

## Overview

Three LiveView pages were created to provide a complete UI for managing posts:

1. **Index Page** (`/posts`) - List all posts with filtering
2. **Form Page** (`/posts/new`, `/posts/:id/edit`) - Create and edit posts
3. **Show Page** (`/posts/:id`) - View individual posts

## Features

### Index Page (`WeaktyWeb.PostLive.Index`)

**Route:** `/posts` (with optional `?tab=` query parameter)

**Features:**
- Lists all posts for the current user
- Three tabs for filtering:
  - **All** - Shows all posts sorted by update date
  - **Published** - Shows only published posts sorted by publish date
  - **Drafts** - Shows only draft posts sorted by update date
- Quick actions for each post:
  - **Publish/Unpublish** - Toggle post status
  - **Edit** - Navigate to edit form
  - **Delete** - Remove post (with confirmation)
- Visual badges showing post status, featured, and public flags
- Shows excerpt and publication/update dates

**Authentication:** Requires logged-in user

### Form Page (`WeaktyWeb.PostLive.Form`)

**Routes:**
- `/posts/new` - Create new post
- `/posts/:id/edit` - Edit existing post

**Features:**
- Markdown editor with large textarea
- Preview toggle to see rendered markdown
- Fields:
  - **Title** (required) - Post title
  - **Slug** (optional) - Auto-generated from title if empty
  - **Featured Image URL** - URL to hero image
  - **Excerpt** - Short summary
  - **Markdown Content** (required) - Main post content
  - **Featured** - Checkbox to mark as featured
  - **Public** - Checkbox to make publicly visible
  - **Status** - Dropdown to select draft or published
- Real-time validation as you type
- Cancel button returns to index

**Authentication:** Requires logged-in user

### Show Page (`WeaktyWeb.PostLive.Show`)

**Route:** `/posts/:id`

**Features:**
- Displays full post with rendered markdown
- Shows featured image if present
- Shows excerpt in larger italic text
- Displays status badges (published/draft, featured, public)
- Shows publication or update date
- For post owners, provides action buttons:
  - **Edit Post** - Navigate to edit form
  - **Publish/Unpublish** - Toggle status
  - **Delete** - Remove post with confirmation
- Back button to return to index

**Authentication:** Optional (public posts visible to all, private posts only to owner)

**Privacy:** Only shows posts that are either:
- Public (visible to everyone)
- Owned by the current user (visible only to author)

## Routes Added to Router

```elixir
ash_authentication_live_session :authenticated_routes do
  # ... existing routes ...

  live "/posts", PostLive.Index, :index
  live "/posts/new", PostLive.Form, :new
  live "/posts/:id", PostLive.Show, :show
  live "/posts/:id/edit", PostLive.Form, :edit
end
```

## Dependencies Added

- **earmark** (~> 1.4) - Markdown rendering library

## Styling

All pages use DaisyUI classes for consistent styling with the rest of the app:
- Cards with shadow effects
- Badges for status indicators
- Buttons with appropriate colors (primary, success, warning, error, ghost)
- Form controls with proper spacing and labels
- Responsive layout with max-width containers

## Markdown Rendering

The `render_markdown/1` helper function converts markdown to HTML using Earmark:
- Returns empty string for nil or empty input
- Handles rendering errors gracefully
- Used in both Form (preview mode) and Show pages

## Usage Examples

### Creating a New Post

1. Navigate to `/posts`
2. Click "New Post" button
3. Fill in title and markdown content (minimum required fields)
4. Optionally add slug, featured image, excerpt
5. Choose status (draft or published)
6. Check "Featured" or "Public" as needed
7. Click "Create Post"

### Publishing a Draft

**Method 1 - From Index:**
1. Navigate to `/posts?tab=drafts`
2. Find the draft post
3. Click "Publish" button

**Method 2 - From Show:**
1. Navigate to `/posts/:id`
2. Click "Publish" button

**Method 3 - From Edit:**
1. Navigate to `/posts/:id/edit`
2. Change status dropdown to "Published"
3. Click "Update Post"

### Previewing Markdown

1. Navigate to post form (new or edit)
2. Click "Preview" button in top right
3. See rendered markdown
4. Click "Edit" to return to form

## Integration with Posts Domain

The LiveViews integrate seamlessly with the Posts domain:
- Use `Weakty.Posts.Post` module for all database operations
- Call action functions:
  - `list_posts!/0`, `list_published_posts!/0`, `list_drafts!/0`
  - `create_post/1`, `update_post/2`
  - `publish_post/1`, `unpublish_post/1`
  - `delete_post/1`
- Entity system automatically syncs via SyncEntity/DestroyEntity changes

## Future Enhancements

Potential improvements:
- Tag management in the form (similar to links)
- Rich markdown editor with toolbar
- Image upload for featured images
- Auto-save drafts
- Markdown cheatsheet/help
- Character/word count
- Reading time estimate
- SEO preview
- Schedule publishing
- Version history
