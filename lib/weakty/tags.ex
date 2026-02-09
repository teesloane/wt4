defmodule Weakty.Tags do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Weakty.Tags.Tag
  end
end
