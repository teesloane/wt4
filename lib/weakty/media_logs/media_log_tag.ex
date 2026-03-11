defmodule Weakty.MediaLogs.MediaLogTag do
  use Ash.Resource,
    domain: Weakty.MediaLogs,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "media_log_tags"
    repo Weakty.Repo
  end

  code_interface do
    define :create_media_log_tag, action: :create
    define :delete_media_log_tag, action: :destroy
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:media_log_id, :tag_id]
    end
  end

  attributes do
    uuid_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :media_log, Weakty.MediaLogs.MediaLog do
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
    identity :unique_media_log_tag, [:media_log_id, :tag_id]
  end
end
