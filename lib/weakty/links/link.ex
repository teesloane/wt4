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

  code_interface do
    define :list_links, action: :read
    define :get_link, action: :read, get?: true
    define :create_link, action: :create
    define :update_link, action: :update
    define :delete_link, action: :destroy
  end

  actions do
    defaults [:read]

    destroy :destroy do
      primary? true
      require_atomic? false

      # Clean up entity and join table entries before deletion
      change before_action(fn changeset, _context ->
               link = changeset.data
               import Ecto.Query

               # Delete associated entity if it exists
               case Weakty.Content.Entity.get_entity_by_source(:link, link.id) do
                 {:ok, entity} -> Weakty.Content.Entity.delete_entity(entity)
                 _ -> :ok
               end

               # Delete link_tags join table entries
               Weakty.Repo.delete_all(from lt in "link_tags", where: lt.link_id == ^link.id)

               changeset
             end)
    end

    read :get_by_slug do
      get_by :slug
    end

    create :create do
      accept [:url, :title, :commentary, :slug, :user_id, :public]

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
            nil ->
              changeset

            title ->
              slug =
                title
                |> String.downcase()
                |> String.replace(~r/[^a-z0-9]+/, "-")
                |> String.trim("-")

              Ash.Changeset.force_change_attribute(changeset, :slug, slug)
          end
        end
      end
    end

    update :update do
      accept [:url, :title, :commentary, :public]
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
            published_at: :inserted_at},
           on: [:create, :update]

    change {Weakty.Changes.DestroyEntity, entity_type: :link},
      on: [:destroy]
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

  identities do
    identity :unique_slug, [:slug]
  end
end
