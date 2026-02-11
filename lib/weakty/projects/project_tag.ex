defmodule Weakty.Projects.ProjectTag do
  use Ash.Resource,
    domain: Weakty.Projects,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "project_tags"
    repo Weakty.Repo
  end

  attributes do
    uuid_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :project, Weakty.Projects.Project do
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
      accept [:project_id, :tag_id]
    end
  end

  identities do
    identity :unique_project_tag, [:project_id, :tag_id]
  end

  code_interface do
    define :create_project_tag, action: :create
    define :delete_project_tag, action: :destroy
  end
end
