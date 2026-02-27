defmodule Weakty.Tils do
  use Ash.Domain, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Weakty.Tils.Til
    resource Weakty.Tils.TilTag
  end
end
