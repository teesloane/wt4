defmodule Weakty.Tils.TilTag do
  use Ash.Resource,
    domain: Weakty.Tils,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "til_tags"
    repo Weakty.Repo
  end

  attributes do
    uuid_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :til, Weakty.Tils.Til do
      allow_nil? false
      attribute_writable? true
      attribute_public? true
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
      accept [:til_id, :tag_id]
    end
  end

  identities do
    identity :unique_til_tag, [:til_id, :tag_id]
  end

  code_interface do
    define :create_til_tag, action: :create
    define :delete_til_tag, action: :destroy
  end
end
