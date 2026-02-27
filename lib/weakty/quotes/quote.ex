defmodule Weakty.Quotes.Quote do
  use Ash.Resource,
    domain: Weakty.Quotes,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshAdmin.Resource],
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "quotes"
    repo Weakty.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :body, :string do
      allow_nil? false
      public? true
    end

    attribute :attribution, :string do
      public? true
    end

    attribute :attribution_url, :string do
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

    timestamps()
  end

  relationships do
    belongs_to :user, Weakty.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    many_to_many :tags, Weakty.Tags.Tag do
      through Weakty.Quotes.QuoteTag
      source_attribute_on_join_resource :quote_id
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
        quote = changeset.data
        import Ecto.Query

        case Weakty.Content.Entity.get_entity_by_source(:quote, quote.id) do
          {:ok, entity} -> Weakty.Content.Entity.delete_entity(entity)
          _ -> :ok
        end

        Weakty.Repo.delete_all(from qt in "quote_tags", where: qt.quote_id == ^quote.id)
        changeset
      end)
    end

    read :get_by_slug do
      get_by :slug
    end

    create :create do
      accept [:body, :attribution, :attribution_url, :slug, :user_id, :public]

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
          case Ash.Changeset.get_attribute(changeset, :body) do
            nil -> changeset
            body ->
              slug =
                body
                |> String.slice(0, 60)
                |> String.downcase()
                |> String.replace(~r/[^a-z0-9]+/, "-")
                |> String.trim("-")
              Ash.Changeset.force_change_attribute(changeset, :slug, slug)
          end
        end
      end
    end

    update :update do
      accept [:body, :attribution, :attribution_url, :public]
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
    end
  end

  code_interface do
    define :list_quotes, action: :read
    define :get_quote, action: :read, get?: true
    define :create_quote, action: :create
    define :update_quote, action: :update
    define :delete_quote, action: :destroy
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  changes do
    change {Weakty.Changes.SyncEntity,
      entity_type: :quote,
      title: :body,
      content: :attribution,
      url: :attribution_url,
      slug: :slug,
      source_path: "/quotes",
      public: :public,
      published_at: :inserted_at
    }, on: [:create, :update]

    change {Weakty.Changes.DestroyEntity,
      entity_type: :quote
    }, on: [:destroy]
  end
end
