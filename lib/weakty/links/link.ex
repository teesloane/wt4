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
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:url, :title, :commentary, :user_id]
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
end
