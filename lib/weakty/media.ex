defmodule Weakty.Media do
  alias Weakty.Media.Adapters.{OpenLibrary, MusicBrainz, TMDB}

  @adapters %{
    book: OpenLibrary,
    music: MusicBrainz,
    movie: TMDB
  }

  @doc """
  Returns the adapter module for the given media type atom, or nil if none exists.
  """
  def adapter_for(media_type) when is_atom(media_type) do
    Map.get(@adapters, media_type)
  end

  def adapter_for(media_type) when is_binary(media_type) do
    try do
      media_type |> String.to_existing_atom() |> adapter_for()
    rescue
      ArgumentError -> nil
    end
  end

  @doc """
  Searches for media using the appropriate adapter for the given media type.
  Returns {:ok, [MediaResult.t()]} or {:error, reason}.
  """
  def search(media_type, query) when is_binary(query) do
    dbg()
    case String.trim(query) do
      "" ->
        {:ok, []}

      trimmed ->
        case adapter_for(media_type) do
          nil -> {:ok, []}
          adapter -> adapter.search(trimmed)
        end
    end
  end
end
