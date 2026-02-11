defmodule Weakty.Repo.Migrations.AddContentImagesToPosts do
  @moduledoc """
  Adds content_images field to posts table for storing uploaded content images.
  """

  use Ecto.Migration

  def up do
    alter table(:posts) do
      add :content_images, :json, default: "[]"
    end
  end

  def down do
    alter table(:posts) do
      remove :content_images
    end
  end
end
