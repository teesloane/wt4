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

    attribute :public, :boolean do
      default false
      public? true
    end

    attribute :featured_image, :string do
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :description_html, :string do
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
    defaults [:read]

    destroy :destroy do
      primary? true
      require_atomic? false

      # Remove all relationships before deleting the tag
      change before_action(fn changeset, _context ->
        tag = changeset.data

        # Load all relationships
        tag = Ash.load!(tag, [:links, :posts, :media_logs, :projects, :entities], domain: Weakty.Tags)

        # Delete join table entries directly
        for link <- tag.links do
          case Ash.read(Weakty.Links.LinkTag, filter: [tag_id: tag.id, link_id: link.id]) do
            {:ok, [join | _]} -> Ash.destroy!(join)
            _ -> :ok
          end
        end

        for post <- tag.posts do
          case Ash.read(Weakty.Posts.PostTag, filter: [tag_id: tag.id, post_id: post.id]) do
            {:ok, [join | _]} -> Ash.destroy!(join)
            _ -> :ok
          end
        end

        for media_log <- tag.media_logs do
          case Ash.read(Weakty.MediaLogs.MediaLogTag, filter: [tag_id: tag.id, media_log_id: media_log.id]) do
            {:ok, [join | _]} -> Ash.destroy!(join)
            _ -> :ok
          end
        end

        for project <- tag.projects do
          case Ash.read(Weakty.Projects.ProjectTag, filter: [tag_id: tag.id, project_id: project.id]) do
            {:ok, [join | _]} -> Ash.destroy!(join)
            _ -> :ok
          end
        end

        for entity <- tag.entities do
          case Ash.read(Weakty.Content.EntityTag, filter: [tag_id: tag.id, entity_id: entity.id]) do
            {:ok, [join | _]} -> Ash.destroy!(join)
            _ -> :ok
          end
        end

        changeset
      end)
    end

    create :create do
      primary? true
      accept [:name, :slug, :public, :featured_image, :description]

      # Auto-generate slug from name if not provided
      change fn changeset, _context ->
        changeset =
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

        # Convert markdown to HTML if description is present
        case Ash.Changeset.get_attribute(changeset, :description) do
          nil -> changeset
          "" -> changeset
          markdown ->
            case Earmark.as_html(markdown) do
              {:ok, html, _} -> Ash.Changeset.force_change_attribute(changeset, :description_html, html)
              _ -> changeset
            end
        end
      end
    end

    update :update do
      primary? true
      accept [:name, :slug, :public, :featured_image, :description]
      require_atomic? false

      # Convert markdown to HTML if description is updated
      change fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :description) do
          nil -> changeset
          "" ->
            Ash.Changeset.force_change_attribute(changeset, :description_html, nil)
          markdown ->
            case Earmark.as_html(markdown) do
              {:ok, html, _} -> Ash.Changeset.force_change_attribute(changeset, :description_html, html)
              _ -> changeset
            end
        end
      end
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
