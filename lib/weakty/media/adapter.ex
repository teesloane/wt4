defmodule Weakty.Media.Adapter do
  alias Weakty.Media.MediaResult

  @callback search(query :: String.t()) :: {:ok, [MediaResult.t()]} | {:error, term()}
  @callback fetch(id :: String.t()) :: {:ok, MediaResult.t()} | {:error, term()}
  @callback media_types() :: [MediaResult.media_type()]
end
