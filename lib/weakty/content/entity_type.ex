defmodule Weakty.Content.EntityType do
  use Ash.Type.Enum,
    values: [
      :link,
      :post,
      :til,
      :bookmark,
      :media_log,
      :photo,
      :quote
    ]
end
