defmodule Weakty.Quotes.QuoteTag do
  use Ash.Resource,
    domain: Weakty.Quotes,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "quote_tags"
    repo Weakty.Repo
  end

  attributes do
    uuid_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :quote, Weakty.Quotes.Quote do
      allow_nil? false
      attribute_writable? true
      attribute_public? true
    end

    belongs_to :tag, Weakty.Tags.Tag do
      allow_nil? false
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:quote_id, :tag_id]
    end
  end

  identities do
    identity :unique_quote_tag, [:quote_id, :tag_id]
  end

  code_interface do
    define :create_quote_tag, action: :create
    define :delete_quote_tag, action: :destroy
  end
end
