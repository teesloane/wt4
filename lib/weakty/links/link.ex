defmodule Weakty.Links.Link do
  use Ash.Resource,
  domain: Weakty.Links,
  data_layer: AshSqlite.DataLayer,
  extensions: [AshAdmin.Resource],
  authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "links"
    repo Weakty.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :url, :string do
      allow_nil? false
      public? true
    end

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :commentary, :string do
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
      through Weakty.Links.LinkTag
      source_attribute_on_join_resource :link_id
      destination_attribute_on_join_resource :tag_id
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:url, :title, :commentary, :slug, :user_id]

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
    end

    update :update do
      accept [:url, :title, :commentary]
    end
  end

  code_interface do
    define :list_links, action: :read
    define :get_link, action: :read, get?: true
    define :create_link, action: :create
    define :update_link, action: :update
    define :delete_link, action: :destroy
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  changes do
    change {Weakty.Changes.SyncEntity,
      entity_type: :link,
      title: :title,
      content: :commentary,
      url: :url,
      slug: :slug,
      source_path: "/links",
      public: :public,
      published_at: :inserted_at
    }, on: [:create, :update]

    change {Weakty.Changes.DestroyEntity,
      entity_type: :link
    }, on: [:destroy]
  end
end
