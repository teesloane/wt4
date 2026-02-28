defmodule Weakty.Repo.Migrations.ConsolidateTilsAndQuotesIntoPosts do
  use Ecto.Migration

  def up do
    # Add quote attribution columns to posts
    alter table(:posts) do
      add :attribution, :text
      add :attribution_url, :text
    end

    # Migrate TILs into posts (reuse same UUIDs, body -> markdown)
    execute """
    INSERT INTO posts (id, user_id, title, slug, markdown, html, public, published_at,
                       status, post_type, featured, content_images, inserted_at, updated_at)
    SELECT id, user_id, title, slug, body, html, public, published_at,
           CASE WHEN public = 1 THEN 'published' ELSE 'draft' END,
           'til', 0, '[]', inserted_at, updated_at
    FROM tils
    """

    # Migrate Quotes into posts (auto-generate title from first 60 chars of body)
    execute """
    INSERT INTO posts (id, user_id, title, slug, markdown, public, published_at,
                       status, post_type, featured, attribution, attribution_url,
                       content_images, inserted_at, updated_at)
    SELECT id, user_id, substr(body, 1, 60), slug, body, public,
           inserted_at,
           CASE WHEN public = 1 THEN 'published' ELSE 'draft' END,
           'quote', 0, attribution, attribution_url, '[]', inserted_at, updated_at
    FROM quotes
    """

    # Migrate til_tags -> post_tags (reuse same join row UUIDs)
    execute """
    INSERT INTO post_tags (id, post_id, tag_id, inserted_at, updated_at)
    SELECT id, til_id, tag_id, inserted_at, updated_at FROM til_tags
    """

    # Migrate quote_tags -> post_tags
    execute """
    INSERT INTO post_tags (id, post_id, tag_id, inserted_at, updated_at)
    SELECT id, quote_id, tag_id, inserted_at, updated_at FROM quote_tags
    """

    # Drop join tables first (they reference tils/quotes)
    execute "DROP TABLE IF EXISTS til_tags"
    execute "DROP TABLE IF EXISTS quote_tags"

    # Drop source tables
    execute "DROP TABLE IF EXISTS tils"
    execute "DROP TABLE IF EXISTS quotes"
  end

  def down do
    raise "This migration cannot be safely reversed - data has been consolidated"
  end
end
