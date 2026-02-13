defmodule Weakty.Media.MediaResult do
  @type media_type :: :music | :book | :movie | :tv

  @type t :: %__MODULE__{
          adapter: module(),
          external_id: String.t(),
          media_type: media_type(),
          title: String.t() | nil,
          year: String.t() | nil,
          cover_url: String.t() | nil,
          creators: [String.t()],
          extra: map()
        }

  defstruct [
    :adapter,
    :external_id,
    :media_type,
    :title,
    :year,
    :cover_url,
    creators: [],
    extra: %{}
  ]
end
