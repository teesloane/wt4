defmodule Weakty.Posts.PostType do
  use Ash.Type.Enum,
    values: [
      :update,
      :post,
      :page,
      :til,
      :quote,
      :fiction,
      :process
    ]
end
