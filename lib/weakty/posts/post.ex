defmodule Weakty.Posts.Post do
  use Ash.Resource,
    domain: Weakty.Posts,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshAdmin.Resource],
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "posts"
    repo Weakty.Repo
  end

  code_interface do
    define :list_posts, action: :read
    define :list_published_posts, action: :published
    define :list_drafts, action: :drafts
    define :list_posts_only, action: :posts
    define :list_updates_only, action: :updates
    define :list_published_posts_only, action: :published_posts
    define :list_published_updates, action: :published_updates
    define :list_tils, action: :tils
    define :list_quotes, action: :quotes
    define :list_fiction, action: :fiction
    define :get_post, action: :read, get?: true
    define :get_by_slug, action: :get_by_slug
    define :create_post, action: :create
    define :update_post, action: :update
    define :publish_post, action: :publish
    define :unpublish_post, action: :unpublish
    define :delete_post, action: :destroy
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
               post = changeset.data
               import Ecto.Query

               # Delete associated entity if it exists
               case Weakty.Content.Entity.get_entity_by_source(:post, post.id) do
                 {:ok, entity} when not is_nil(entity) ->
                   Weakty.Content.Entity.delete_entity(entity)

                 _ ->
                   :ok
               end

               # Delete post_tags join table entries
               Weakty.Repo.delete_all(from pt in "post_tags", where: pt.post_id == ^post.id)

               changeset
             end)
    end

    create :create do
      accept [
        :title,
        :slug,
        :markdown,
        :html,
        :featured_image,
        :content_images,
        :excerpt,
        :status,
        :featured,
        :public,
        :published_at,
        :user_id,
        :post_type,
        :attribution,
        :attribution_url
      ]

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

      change Weakty.Posts.Changes.ConvertMarkdownToHtml
    end

    update :update do
      accept [
        :title,
        :slug,
        :markdown,
        :html,
        :featured_image,
        :content_images,
        :excerpt,
        :status,
        :featured,
        :public,
        :published_at,
        :post_type,
        :attribution,
        :attribution_url
      ]

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

      change Weakty.Posts.Changes.ConvertMarkdownToHtml
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

    read :posts do
      prepare build(sort: [published_at: :desc])
      filter expr(post_type == :post)
    end

    read :updates do
      prepare build(sort: [published_at: :desc])
      filter expr(post_type == :update)
    end

    read :published_posts do
      prepare build(sort: [published_at: :desc])
      filter expr(status == :published and post_type in [:post, :fiction])
    end

    read :published_updates do
      prepare build(sort: [published_at: :desc])
      filter expr(status == :published and post_type == :update)
    end

    read :tils do
      prepare build(sort: [published_at: :desc])
      filter expr(post_type == :til)
    end

    read :quotes do
      prepare build(sort: [inserted_at: :desc])
      filter expr(post_type == :quote)
    end

    read :fiction do
      prepare build(sort: [published_at: :desc])
      filter expr(status == :published and post_type == :fiction)
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  changes do
    change {Weakty.Changes.SyncEntity,
            entity_type: :post,
            subtype: :post_type,
            title: :title,
            content: {Weakty.Posts.Helpers, :content_for_entity},
            slug: :slug,
            source_path: {Weakty.Posts.Helpers, :source_path_for_entity},
            hero_url: :featured_image,
            public: :public,
            published_at: :published_at,
            status: :status},
           on: [:create, :update]

    change {Weakty.Changes.DestroyEntity, entity_type: :post},
      on: [:destroy]
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

    attribute :content_images, {:array, :string} do
      public? true
      default []
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

    attribute :post_type, Weakty.Posts.PostType do
      allow_nil? false
      public? true
      default :post
    end

    attribute :attribution, :string do
      public? true
    end

    attribute :attribution_url, :string do
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
      through Weakty.Posts.PostTag
      source_attribute_on_join_resource :post_id
      destination_attribute_on_join_resource :tag_id
    end
  end

  identities do
    identity :unique_slug, [:slug]
  end
end
