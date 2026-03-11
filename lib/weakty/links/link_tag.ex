defmodule Weakty.Links.LinkTag do
  use Ash.Resource,
    domain: Weakty.Links,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "link_tags"
    repo Weakty.Repo
  end

  code_interface do
    define :create_link_tag, action: :create
    define :delete_link_tag, action: :destroy
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:link_id, :tag_id]
    end
  end

  attributes do
    uuid_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :link, Weakty.Links.Link do
      allow_nil? false
      attribute_writable? true
      attribute_public? true
    end

    belongs_to :tag, Weakty.Tags.Tag do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_link_tag, [:link_id, :tag_id]
  end
end
