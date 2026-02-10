defmodule Weakty.Posts.PostType do
  use Ash.Type.Enum,
  values: [
  :update,
  :post,
  :page,
  ]

end
