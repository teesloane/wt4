defmodule Weakty.Content.Entity do
  use Ash.Resource,
    domain: Weakty.Content,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshAdmin.Resource],
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "entities"
    repo Weakty.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :entity_type, Weakty.Content.EntityType do
      allow_nil? false
      public? true
    end

    attribute :source_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :title, :string do
      public? true
    end

    attribute :content, :string do
      public? true
    end

    attribute :url, :string do
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :source_path, :string do
      allow_nil? false
      public? true
    end

    attribute :hero_url, :string do
      public? true
    end

    attribute :thumbnail_url, :string do
      public? true
    end

    attribute :rating, :integer do
      public? true
    end

    attribute :status, :string do
      public? true
    end

    attribute :favourite, :boolean do
      default false
      public? true
    end

    attribute :tags, {:array, :string} do
      public? true
      default []
    end

    attribute :published_at, :utc_datetime_usec do
      allow_nil? true
      public? true
    end

    attribute :public, :boolean do
      allow_nil? false
      default false
      public? true
    end

    timestamps()
  end

  identities do
    identity :unique_source, [:entity_type, :source_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:entity_type, :source_id, :title, :content, :url, :slug, :source_path,
              :hero_url, :thumbnail_url, :rating, :status, :favourite, :tags,
              :published_at, :public]
      upsert? true
      upsert_identity :unique_source
      upsert_fields [:title, :content, :url, :slug, :source_path,
                      :hero_url, :thumbnail_url, :rating, :status, :favourite, :tags,
                      :published_at, :public, :updated_at]
    end

    update :update_tags do
      accept [:tags]
    end

    read :timeline do
      prepare build(sort: [published_at: :desc])
    end

    read :by_source do
      argument :entity_type, Weakty.Content.EntityType, allow_nil?: false
      argument :source_id, :uuid, allow_nil?: false
      get? true
      filter expr(entity_type == ^arg(:entity_type) and source_id == ^arg(:source_id))
    end
  end

  code_interface do
    define :list_entities, action: :timeline
    define :get_entity_by_source, action: :by_source, args: [:entity_type, :source_id]
    define :upsert_entity, action: :create
    define :update_entity_tags, action: :update_tags
    define :delete_entity, action: :destroy
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end
end
