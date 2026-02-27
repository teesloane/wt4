defmodule Weakty.Quotes do
  use Ash.Domain, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Weakty.Quotes.Quote
    resource Weakty.Quotes.QuoteTag
  end
end
