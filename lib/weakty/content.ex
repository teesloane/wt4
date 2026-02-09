defmodule Weakty.Content do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  admin do
    show? false
  end

  resources do
    resource Weakty.Content.Entity
  end
end
