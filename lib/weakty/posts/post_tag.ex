defmodule Weakty.Posts.PostTag do
  use Ash.Resource,
    domain: Weakty.Posts,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "post_tags"
    repo Weakty.Repo
  end

  attributes do
    uuid_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :post, Weakty.Posts.Post do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :tag, Weakty.Tags.Tag do
      allow_nil? false
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:post_id, :tag_id]
    end
  end

  identities do
    identity :unique_post_tag, [:post_id, :tag_id]
  end

  code_interface do
    define :create_post_tag, action: :create
    define :delete_post_tag, action: :destroy
  end
end
