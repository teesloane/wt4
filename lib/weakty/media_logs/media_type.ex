defmodule Weakty.MediaLogs.MediaType do
  use Ash.Type.Enum,
    values: [
      :book,
      :comic,
      :movie,
      :music,
      :video_game
    ]
end
