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

  code_interface do
    define :list_entities, action: :timeline
    define :get_entity_by_source, action: :by_source, args: [:entity_type, :source_id]
    define :related_entities, action: :related, args: [:tag_ids, :exclude_id]
    define :upsert_entity, action: :create
    define :delete_entity, action: :destroy
    define :search_entities, action: :search, args: [:query]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :entity_type,
        :source_id,
        :title,
        :content,
        :url,
        :slug,
        :source_path,
        :hero_url,
        :thumbnail_url,
        :rating,
        :subtype,
        :status,
        :favourite,
        :published_at,
        :public
      ]

      upsert? true
      upsert_identity :unique_source

      upsert_fields [
        :title,
        :content,
        :url,
        :slug,
        :source_path,
        :hero_url,
        :thumbnail_url,
        :rating,
        :subtype,
        :status,
        :favourite,
        :published_at,
        :public,
        :updated_at
      ]
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

    read :search do
      argument :query, :string, allow_nil?: false

      prepare fn query, _context ->
        require Ash.Query
        term = Ash.Query.get_argument(query, :query)
        pattern = "%#{String.downcase(String.trim(term))}%"

        Ash.Query.filter(
          query,
          entity_type != :media_log and
            public == true and
            (fragment("lower(coalesce(title, '')) LIKE ?", ^pattern) or
               fragment("lower(coalesce(content, '')) LIKE ?", ^pattern) or
               exists(tags, fragment("lower(coalesce(name, '')) LIKE ?", ^pattern)))
        )
      end

      prepare build(sort: [published_at: :desc], limit: 15, load: [:tags])
    end

    read :related do
      argument :tag_ids, {:array, :uuid}, allow_nil?: false
      argument :exclude_id, :uuid, allow_nil?: false

      filter expr(
               public == true and
                 source_id != ^arg(:exclude_id) and
                 exists(tags, id in ^arg(:tag_ids))
             )
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
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

    attribute :subtype, :string do
      public? true
    end

    attribute :status, :string do
      public? true
    end

    attribute :favourite, :boolean do
      default false
      public? true
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

  relationships do
    many_to_many :tags, Weakty.Tags.Tag do
      through Weakty.Content.EntityTag
      source_attribute_on_join_resource :entity_id
      destination_attribute_on_join_resource :tag_id
      public? true
    end
  end

  identities do
    identity :unique_source, [:entity_type, :source_id]
  end
end
