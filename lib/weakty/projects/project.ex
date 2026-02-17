defmodule Weakty.Projects.Project do
  use Ash.Resource,
    domain: Weakty.Projects,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshAdmin.Resource],
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "projects"
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

    attribute :markdown, :string do
      allow_nil? false
      public? true
    end

    attribute :html, :string do
      public? true
    end

    attribute :featured_image, :string do
      public? true
    end

    attribute :excerpt, :string do
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      default :draft
      public? true
      constraints one_of: [:draft, :published]
    end

    attribute :project_status, :atom do
      allow_nil? false
      default :ongoing
      public? true
      constraints one_of: [:ongoing, :hiatus, :completed]
    end

    attribute :featured, :boolean do
      allow_nil? false
      default false
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

    attribute :links, {:array, :map} do
      public? true
      default []
    end

    attribute :start_date, :date do
      public? true
    end

    attribute :end_date, :date do
      public? true
    end

    attribute :images, {:array, :string} do
      public? true
      default []
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Weakty.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    many_to_many :tags, Weakty.Tags.Tag do
      through Weakty.Projects.ProjectTag
      source_attribute_on_join_resource :project_id
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

    destroy :destroy do
      primary? true
      require_atomic? false

      # Clean up entity and join table entries before deletion
      change before_action(fn changeset, _context ->
        project = changeset.data
        import Ecto.Query

        # Delete associated entity if it exists
        case Weakty.Content.Entity.get_entity_by_source(:project, project.id) do
          {:ok, entity} -> Weakty.Content.Entity.delete_entity(entity)
          _ -> :ok
        end

        # Delete project_tags join table entries
        Weakty.Repo.delete_all(from pt in "project_tags", where: pt.project_id == ^project.id)

        changeset
      end)
    end

    create :create do
      accept [:title, :slug, :markdown, :html, :featured_image, :excerpt,
              :status, :project_status, :featured, :public, :published_at,
              :user_id, :links, :start_date, :end_date, :images]

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
        # Auto-generate slug from title if not provided
        if Ash.Changeset.get_attribute(changeset, :slug) do
          changeset
        else
          case Ash.Changeset.get_attribute(changeset, :title) do
            nil -> changeset
            title ->
              slug = title
                |> String.downcase()
                |> String.replace(~r/[^a-z0-9]+/, "-")
                |> String.trim("-")
              Ash.Changeset.force_change_attribute(changeset, :slug, slug)
          end
        end
      end

      change fn changeset, _context ->
        # Set published_at when status changes to published
        status = Ash.Changeset.get_attribute(changeset, :status)
        published_at = Ash.Changeset.get_attribute(changeset, :published_at)

        if status == :published && is_nil(published_at) do
          Ash.Changeset.force_change_attribute(changeset, :published_at, DateTime.utc_now())
        else
          changeset
        end
      end

      change Weakty.Projects.Changes.ConvertMarkdownToHtml
    end

    update :update do
      accept [:title, :slug, :markdown, :html, :featured_image, :excerpt,
              :status, :project_status, :featured, :public, :published_at,
              :links, :start_date, :end_date, :images]
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
        # Set published_at when status changes to published
        if Ash.Changeset.changing_attribute?(changeset, :status) do
          status = Ash.Changeset.get_attribute(changeset, :status)
          published_at = Ash.Changeset.get_attribute(changeset, :published_at)

          if status == :published && is_nil(published_at) do
            Ash.Changeset.force_change_attribute(changeset, :published_at, DateTime.utc_now())
          else
            changeset
          end
        else
          changeset
        end
      end

      change Weakty.Projects.Changes.ConvertMarkdownToHtml
    end

    update :publish do
      accept []
      require_atomic? false

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :published)
        |> Ash.Changeset.force_change_attribute(:published_at, DateTime.utc_now())
      end
    end

    update :unpublish do
      accept []
      require_atomic? false

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :status, :draft)
      end
    end

    read :published do
      prepare build(sort: [published_at: :desc])
      filter expr(status == :published)
    end

    read :drafts do
      prepare build(sort: [updated_at: :desc])
      filter expr(status == :draft)
    end

    read :ongoing do
      prepare build(sort: [start_date: :desc])
      filter expr(project_status == :ongoing)
    end

    read :completed do
      prepare build(sort: [end_date: :desc])
      filter expr(project_status == :completed)
    end

    read :published_projects do
      prepare build(sort: [published_at: :desc])
      filter expr(status == :published)
    end
  end

  code_interface do
    define :list_projects, action: :read
    define :list_published_projects, action: :published
    define :list_drafts, action: :drafts
    define :list_ongoing, action: :ongoing
    define :list_completed, action: :completed
    define :get_project, action: :read, get?: true
    define :create_project, action: :create
    define :update_project, action: :update
    define :publish_project, action: :publish
    define :unpublish_project, action: :unpublish
    define :delete_project, action: :destroy
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  changes do
    change {Weakty.Changes.SyncEntity,
      entity_type: :project,
      title: :title,
      content: :markdown,
      slug: :slug,
      source_path: "/projects",
      hero_url: :featured_image,
      public: :public,
      published_at: :published_at,
      status: :status
    }, on: [:create, :update]

    change {Weakty.Changes.DestroyEntity,
      entity_type: :project
    }, on: [:destroy]
  end
end
