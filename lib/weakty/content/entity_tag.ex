defmodule Weakty.Content.EntityTag do
  use Ash.Resource,
    domain: Weakty.Content,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "entity_tags"
    repo Weakty.Repo
  end

  code_interface do
    define :create_entity_tag, action: :create
    define :delete_entity_tag, action: :destroy
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:entity_id, :tag_id]
    end
  end

  attributes do
    uuid_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :entity, Weakty.Content.Entity do
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
    identity :unique_entity_tag, [:entity_id, :tag_id]
  end
end
