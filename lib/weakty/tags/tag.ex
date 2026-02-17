defmodule Weakty.Tags.Tag do
  use Ash.Resource,
    domain: Weakty.Tags,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshAdmin.Resource],
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "tags"
    repo Weakty.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    many_to_many :links, Weakty.Links.Link do
      through Weakty.Links.LinkTag
      source_attribute_on_join_resource :tag_id
      destination_attribute_on_join_resource :link_id
    end

    many_to_many :posts, Weakty.Posts.Post do
      through Weakty.Posts.PostTag
      source_attribute_on_join_resource :tag_id
      destination_attribute_on_join_resource :post_id
    end

    many_to_many :media_logs, Weakty.MediaLogs.MediaLog do
      through Weakty.MediaLogs.MediaLogTag
      source_attribute_on_join_resource :tag_id
      destination_attribute_on_join_resource :media_log_id
    end

    many_to_many :projects, Weakty.Projects.Project do
      through Weakty.Projects.ProjectTag
      source_attribute_on_join_resource :tag_id
      destination_attribute_on_join_resource :project_id
    end

    many_to_many :entities, Weakty.Content.Entity do
      through Weakty.Content.EntityTag
      source_attribute_on_join_resource :tag_id
      destination_attribute_on_join_resource :entity_id
    end
  end

  identities do
    identity :unique_name, [:name]
    identity :unique_slug, [:slug]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :slug]

      # Auto-generate slug from name if not provided
      change fn changeset, _context ->
        if Ash.Changeset.get_attribute(changeset, :slug) do
          changeset
        else
          case Ash.Changeset.get_attribute(changeset, :name) do
            nil -> changeset
            name ->
              slug = name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
              Ash.Changeset.force_change_attribute(changeset, :slug, slug)
          end
        end
      end
    end

    update :update do
      primary? true
      accept [:name, :slug]
    end
  end

  code_interface do
    define :list_tags, action: :read
    define :get_tag, action: :read, get?: true
    define :create_tag, action: :create
    define :update_tag, action: :update
    define :delete_tag, action: :destroy
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end
end
