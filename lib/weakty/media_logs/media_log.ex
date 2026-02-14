defmodule Weakty.MediaLogs.MediaLog do
  use Ash.Resource,
    domain: Weakty.MediaLogs,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshAdmin.Resource],
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "media_logs"
    repo Weakty.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :media_type, Weakty.MediaLogs.MediaType do
      allow_nil? false
      public? true
    end

    attribute :creator, :string do
      public? true
    end

    attribute :date_published, :date do
      public? true
    end

    attribute :thumbnail_url, :string do
      public? true
    end

    attribute :status, Weakty.MediaLogs.Status do
      allow_nil? false
      default :want_to_consume
      public? true
    end

    attribute :date_consumed, :date do
      public? true
    end

    attribute :date_started, :date do
      public? true
    end

    attribute :date_finished, :date do
      public? true
    end

    attribute :rating, :integer do
      public? true
      constraints min: 1, max: 5
    end

    attribute :notes, :string do
      public? true
    end

    attribute :external_url, :string do
      public? true
    end

    attribute :public, :boolean do
      allow_nil? false
      default false
      public? true
    end

    attribute :favourite, :boolean do
      allow_nil? false
      default false
      public? true
    end

    attribute :published_at, :utc_datetime_usec do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Weakty.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    many_to_many :tags, Weakty.Tags.Tag do
      through Weakty.MediaLogs.MediaLogTag
      source_attribute_on_join_resource :media_log_id
      destination_attribute_on_join_resource :tag_id
    end
  end

  identities do
    identity :unique_slug, [:slug]
  end

  actions do
    defaults [:read]

    read :get_by_slug do
      get_by :slug
    end

    read :published do
      prepare build(sort: [published_at: :desc])
      filter expr(public == true)
    end

    read :by_media_type do
      argument :media_type, Weakty.MediaLogs.MediaType do
        allow_nil? false
      end

      prepare build(sort: [updated_at: :desc])
      filter expr(media_type == ^arg(:media_type))
    end

    read :by_status do
      argument :status, Weakty.MediaLogs.Status do
        allow_nil? false
      end

      prepare build(sort: [updated_at: :desc])
      filter expr(status == ^arg(:status))
    end

    read :consuming do
      prepare build(sort: [updated_at: :desc])
      filter expr(status == :consuming)
    end

    destroy :destroy do
      require_atomic? false
    end

    create :create do
      accept [:title, :slug, :media_type, :creator, :date_published, :thumbnail_url,
              :status, :date_consumed, :date_started, :date_finished, :rating, :notes,
              :external_url, :public, :favourite, :published_at, :user_id]

      argument :tags, {:array, :map} do
        allow_nil? true
      end

      change manage_relationship(:tags, :tags,
        type: :append_and_remove,
        value_is_key: :name,
        on_lookup: :relate,
        on_no_match: :create,
        use_identities: [:unique_name]
      )

      change fn changeset, _context ->
        # Auto-generate slug from creator + title if not provided
        if Ash.Changeset.get_attribute(changeset, :slug) do
          changeset
        else
          title   = Ash.Changeset.get_attribute(changeset, :title)
          creator = Ash.Changeset.get_attribute(changeset, :creator)

          case title do
            nil -> changeset
            _ ->
              slug =
                [creator, title]
                |> Enum.reject(&is_nil/1)
                |> Enum.join(" ")
                |> String.downcase()
                |> String.replace(~r/[^a-z0-9]+/, "-")
                |> String.trim("-")
              Ash.Changeset.force_change_attribute(changeset, :slug, slug)
          end
        end
      end

      change fn changeset, _context ->
        # Set published_at when public is true
        public = Ash.Changeset.get_attribute(changeset, :public)
        published_at = Ash.Changeset.get_attribute(changeset, :published_at)

        if public && is_nil(published_at) do
          Ash.Changeset.force_change_attribute(changeset, :published_at, DateTime.utc_now())
        else
          changeset
        end
      end

      change fn changeset, _context ->
        # For books/comics, mirror date_finished → date_consumed so entity sync works
        media_type = Ash.Changeset.get_attribute(changeset, :media_type)

        if media_type in [:book, :comic] do
          date_finished = Ash.Changeset.get_attribute(changeset, :date_finished)
          Ash.Changeset.force_change_attribute(changeset, :date_consumed, date_finished)
        else
          changeset
        end
      end
    end

    update :update do
      accept [:title, :slug, :media_type, :creator, :date_published, :thumbnail_url,
              :status, :date_consumed, :date_started, :date_finished, :rating, :notes,
              :external_url, :public, :favourite, :published_at]
      require_atomic? false

      argument :tags, {:array, :map} do
        allow_nil? true
      end

      change manage_relationship(:tags, :tags,
        type: :append_and_remove,
        value_is_key: :name,
        on_lookup: :relate,
        on_no_match: :create,
        use_identities: [:unique_name]
      )

      change fn changeset, _context ->
        # Set published_at when public changes to true
        if Ash.Changeset.changing_attribute?(changeset, :public) do
          public = Ash.Changeset.get_attribute(changeset, :public)
          published_at = Ash.Changeset.get_attribute(changeset, :published_at)

          if public && is_nil(published_at) do
            Ash.Changeset.force_change_attribute(changeset, :published_at, DateTime.utc_now())
          else
            changeset
          end
        else
          changeset
        end
      end

      change fn changeset, _context ->
        # For books/comics, mirror date_finished → date_consumed so entity sync works
        media_type = Ash.Changeset.get_attribute(changeset, :media_type)

        if media_type in [:book, :comic] do
          date_finished = Ash.Changeset.get_attribute(changeset, :date_finished)
          Ash.Changeset.force_change_attribute(changeset, :date_consumed, date_finished)
        else
          changeset
        end
      end
    end

    update :publish do
      accept []
      require_atomic? false

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:public, true)
        |> Ash.Changeset.force_change_attribute(:published_at, DateTime.utc_now())
      end
    end

    update :unpublish do
      accept []
      require_atomic? false

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :public, false)
      end
    end
  end

  code_interface do
    define :list_media_logs, action: :read
    define :list_published_media_logs, action: :published
    define :list_by_media_type, action: :by_media_type, args: [:media_type]
    define :list_by_status, action: :by_status, args: [:status]
    define :list_consuming, action: :consuming
    define :get_media_log, action: :read, get?: true
    define :get_by_slug, action: :get_by_slug, args: [:slug], get?: true
    define :create_media_log, action: :create
    define :update_media_log, action: :update
    define :publish_media_log, action: :publish
    define :unpublish_media_log, action: :unpublish
    define :delete_media_log, action: :destroy
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  changes do
    change {Weakty.Changes.SyncEntity,
      entity_type: :media_log,
      title: :title,
      content: :notes,
      slug: :slug,
      source_path: "/media-logs",
      thumbnail_url: :thumbnail_url,
      rating: :rating,
      status: :status,
      favourite: :favourite,
      public: :public,
      published_at: :date_consumed,
      skip_if_nil: :date_consumed
    }, on: [:create, :update]

    change {Weakty.Changes.DestroyEntity,
      entity_type: :media_log
    }, on: [:destroy]
  end
end
