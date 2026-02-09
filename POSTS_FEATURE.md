# Posts Feature

This document describes the Posts feature implementation for Weakty, inspired by Ghost blog software.

## Overview

Posts are used for writing fiction, non-fiction, essays, and other long-form content. They support markdown rendering, featured images, draft/published status, and integration with the entity system.

## Features

### Core Attributes

- **title** (string, required): The post title
- **slug** (string, required): URL-friendly slug, auto-generated from title
- **markdown** (text, required): Raw markdown content
- **html** (text, optional): Rendered HTML (can be generated from markdown)
- **featured_image** (string, optional): URL or path to featured image
- **excerpt** (string, optional): Short summary/description of the post

### Publishing

- **status** (enum, required): Either `:draft` or `:published`
- **published_at** (datetime, optional): Automatically set when post is published
- **public** (boolean, default: false): Whether the post is publicly visible
- **featured** (boolean, default: false): Whether this is a featured post

### Relationships

- **user_id** (belongs_to User, required): The author of the post

## Actions

### Create Actions

- `create_post/1` - Create a new post (defaults to draft status)
  - Auto-generates slug from title if not provided
  - Auto-sets published_at when status is :published

### Read Actions

- `list_posts/0` - List all posts
- `list_published_posts/0` - List only published posts (sorted by published_at desc)
- `list_drafts/0` - List only draft posts (sorted by updated_at desc)
- `get_post/1` - Get a specific post by ID

### Update Actions

- `update_post/2` - Update post attributes
  - Auto-sets published_at when status changes to :published
- `publish_post/1` - Publish a draft post (sets status to :published and published_at to now)
- `unpublish_post/1` - Unpublish a post (sets status back to :draft)

### Delete Actions

- `delete_post/1` - Delete a post

## Entity Integration

Posts automatically sync with the Entity system through the `SyncEntity` change:

- Entity type: `:post`
- Mapped fields:
  - title → entity.title
  - markdown → entity.content
  - slug → entity.slug
  - featured_image → entity.hero_url
  - public → entity.public
  - published_at → entity.published_at
  - status → entity.status
- Source path: `/posts`

When a post is deleted, the corresponding entity is automatically removed via the `DestroyEntity` change.

## Usage Examples

### Creating a Draft Post

```elixir
alias Weakty.Posts.Post

{:ok, post} = Post.create_post(%{
  title: "My First Post",
  markdown: "# Hello World\n\nThis is my first post!",
  excerpt: "An introduction to my blog",
  featured_image: "/images/hello-world.jpg",
  status: :draft,
  user_id: user_id
})
```

### Publishing a Post

```elixir
# Method 1: Update status directly
{:ok, post} = Post.update_post(post, %{status: :published})

# Method 2: Use the publish action
{:ok, post} = Post.publish_post(post)
```

### Listing Posts

```elixir
# All posts
{:ok, all_posts} = Post.list_posts()

# Only published posts
{:ok, published} = Post.list_published_posts()

# Only drafts
{:ok, drafts} = Post.list_drafts()
```

## Admin Interface

Posts are automatically available in the Ash Admin interface at `/admin`. You can:

- Create, read, update, and delete posts
- Filter by status, featured, public
- Search by title, slug, or content
- View associated user

## GraphQL API

If GraphQL is configured for the Posts domain, the following queries and mutations will be available:

- Queries: `listPosts`, `getPost`, `listPublishedPosts`, `listDrafts`
- Mutations: `createPost`, `updatePost`, `publishPost`, `unpublishPost`, `deletePost`

## Future Enhancements

The following features are planned but not yet implemented:

- **Tags**: Posts will support tagging (being implemented in a separate worktree)
- **Categories**: Hierarchical organization of posts
- **SEO fields**: meta_title, meta_description
- **Social sharing**: og_image, og_title, og_description
- **Custom templates**: Support for custom post layouts
- **Scheduled publishing**: Schedule posts to be published at a future date
- **Revisions**: Keep history of post changes

## Database Schema

The posts table includes:

```sql
CREATE TABLE posts (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  title TEXT NOT NULL,
  slug TEXT NOT NULL,
  markdown TEXT NOT NULL,
  html TEXT,
  featured_image TEXT,
  excerpt TEXT,
  status TEXT NOT NULL,  -- 'draft' or 'published'
  featured BOOLEAN NOT NULL,
  public BOOLEAN NOT NULL,
  published_at TIMESTAMP,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

## Testing

Run the test script to verify the Posts feature:

```bash
mix run test_posts.exs
```

This will:
1. Create a test draft post
2. Publish the post
3. List posts by status
4. Verify all actions work correctly
