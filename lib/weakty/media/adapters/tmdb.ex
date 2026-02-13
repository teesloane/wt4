defmodule Weakty.Media.Adapters.TMDB do
  @behaviour Weakty.Media.Adapter

  alias Weakty.Media.MediaResult

  @base_url "https://api.themoviedb.org/3"
  @image_base "https://image.tmdb.org/t/p/w500"

  @impl true
  def media_types, do: [:movie, :tv]

  @impl true
  def search(query) do
    with {:ok, api_key} <- get_api_key() do
      movie_task = Task.async(fn -> search_type("movie", query, api_key) end)
      tv_task = Task.async(fn -> search_type("tv", query, api_key) end)

      movie_results = Task.await(movie_task, 10_000)
      tv_results = Task.await(tv_task, 10_000)

      results = List.wrap(movie_results) ++ List.wrap(tv_results)
      {:ok, results}
    end
  end

  @impl true
  def fetch(composite_id) do
    with {:ok, {type, id}} <- parse_id(composite_id),
         {:ok, api_key} <- get_api_key() do
      url = "#{@base_url}/#{type}/#{id}?api_key=#{api_key}"

      case Req.get(url) do
        {:ok, %{status: 200, body: body}} ->
          {:ok, build_result(body, type)}

        {:ok, %{status: 401}} ->
          {:error, :invalid_api_key}

        {:ok, %{status: 404}} ->
          {:error, :not_found}

        {:ok, %{status: status}} ->
          {:error, {:http_error, status}}

        {:error, reason} ->
          {:error, {:request_failed, reason}}
      end
    end
  end

  defp search_type(type, query, api_key) do
    url = "#{@base_url}/search/#{type}?api_key=#{api_key}&query=#{URI.encode(query)}"

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        body
        |> Map.get("results", [])
        |> Enum.map(&build_result(&1, type))

      {:ok, %{status: 401}} ->
        []

      _ ->
        []
    end
  end

  defp build_result(item, type) do
    media_type = if type == "movie", do: :movie, else: :tv

    id = item["id"]
    external_id = "#{type}:#{id}"

    title =
      case type do
        "movie" -> item["title"]
        "tv" -> item["name"]
      end

    year =
      case type do
        "movie" -> item["release_date"]
        "tv" -> item["first_air_date"]
      end

    cover_url =
      case item["poster_path"] do
        nil -> nil
        path -> "#{@image_base}#{path}"
      end

    creators =
      case type do
        "tv" ->
          item
          |> Map.get("created_by", [])
          |> Enum.map(& &1["name"])
          |> Enum.reject(&is_nil/1)

        "movie" ->
          # Requires separate /credits endpoint — not fetched here
          []
      end

    %MediaResult{
      adapter: __MODULE__,
      external_id: external_id,
      media_type: media_type,
      title: title,
      year: year,
      cover_url: cover_url,
      creators: creators,
      extra: %{}
    }
  end

  defp parse_id("movie:" <> id), do: {:ok, {"movie", id}}
  defp parse_id("tv:" <> id), do: {:ok, {"tv", id}}
  defp parse_id(_), do: {:error, :invalid_id_format}

  defp get_api_key do
    case Application.fetch_env(:weakty, :tmdb_api_key) do
      {:ok, key} when is_binary(key) and key != "" -> {:ok, key}
      _ -> {:error, :tmdb_api_key_not_configured}
    end
  end
end
