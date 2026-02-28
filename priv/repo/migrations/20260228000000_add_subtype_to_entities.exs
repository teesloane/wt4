defmodule Weakty.Repo.Migrations.AddSubtypeToEntities do
  use Ecto.Migration

  def up do
    alter table(:entities) do
      add :subtype, :text
    end

    # Backfill subtype for existing post entities from the posts table
    execute """
    UPDATE entities
    SET subtype = (SELECT post_type FROM posts WHERE posts.id = entities.source_id)
    WHERE entity_type = 'post'
    """
  end

  def down do
    alter table(:entities) do
      remove :subtype
    end
  end
end
