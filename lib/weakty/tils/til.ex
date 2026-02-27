defmodule Weakty.Tils.Til do
  use Ash.Resource,
    domain: Weakty.Tils,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshAdmin.Resource],
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "tils"
    repo Weakty.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :body, :string do
      allow_nil? false
      public? true
    end

    attribute :html, :string do
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :public, :boolean do
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
      through Weakty.Tils.TilTag
      source_attribute_on_join_resource :til_id
      destination_attribute_on_join_resource :tag_id
    end
  end

  identities do
    identity :unique_slug, [:slug]
  end

  actions do
    defaults [:read]

    destroy :destroy do
      primary? true
      require_atomic? false

      change before_action(fn changeset, _context ->
        til = changeset.data
        import Ecto.Query

        case Weakty.Content.Entity.get_entity_by_source(:til, til.id) do
          {:ok, entity} -> Weakty.Content.Entity.delete_entity(entity)
          _ -> :ok
        end

        Weakty.Repo.delete_all(from tt in "til_tags", where: tt.til_id == ^til.id)
        changeset
      end)
    end

    read :get_by_slug do
      get_by :slug
    end

    create :create do
      accept [:title, :body, :slug, :user_id, :public, :published_at]

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
        if Ash.Changeset.get_attribute(changeset, :slug) do
          changeset
        else
          case Ash.Changeset.get_attribute(changeset, :title) do
            nil -> changeset
            title ->
              slug = title |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
              Ash.Changeset.force_change_attribute(changeset, :slug, slug)
          end
        end
      end

      change fn changeset, _context ->
        if Ash.Changeset.get_attribute(changeset, :published_at) do
          changeset
        else
          Ash.Changeset.force_change_attribute(changeset, :published_at, DateTime.utc_now())
        end
      end

      change Weakty.Tils.Changes.ConvertMarkdownToHtml
    end

    update :update do
      accept [:title, :body, :public, :published_at]
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

      change Weakty.Tils.Changes.ConvertMarkdownToHtml
    end
  end

  code_interface do
    define :list_tils, action: :read
    define :get_til, action: :read, get?: true
    define :create_til, action: :create
    define :update_til, action: :update
    define :delete_til, action: :destroy
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  changes do
    change {Weakty.Changes.SyncEntity,
      entity_type: :til,
      title: :title,
      content: :body,
      slug: :slug,
      source_path: "/til",
      public: :public,
      published_at: :published_at
    }, on: [:create, :update]

    change {Weakty.Changes.DestroyEntity,
      entity_type: :til
    }, on: [:destroy]
  end
end
