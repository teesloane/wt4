defmodule Weakty.Media.Adapters.OpenLibrary do
  @behaviour Weakty.Media.Adapter

  alias Weakty.Media.MediaResult

  @search_url "https://openlibrary.org/search.json"
  @works_url "https://openlibrary.org/works"
  @cover_url "https://covers.openlibrary.org/b/id"

  @impl true
  def media_types, do: [:book]

  @impl true
  def search(query) do
    url = "#{@search_url}?q=#{URI.encode(query)}&fields=key,title,author_name,first_publish_year,cover_i,isbn"

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        results =
          body
          |> Map.get("docs", [])
          |> Enum.map(&build_search_result/1)

        {:ok, results}

      {:ok, %{status: 404}} ->
        {:ok, []}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @impl true
  def fetch(key) do
    # key may be "OL45804W" or "/works/OL45804W"
    normalized_key = key |> String.replace_leading("/works/", "") |> String.replace_leading("/", "")
    url = "#{@works_url}/#{normalized_key}.json"

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, build_fetch_result(body, normalized_key)}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp build_search_result(doc) do
    cover_url =
      case doc["cover_i"] do
        nil -> nil
        id -> "#{@cover_url}/#{id}-M.jpg"
      end

    year =
      case doc["first_publish_year"] do
        nil -> nil
        y -> to_string(y)
      end

    %MediaResult{
      adapter: __MODULE__,
      external_id: doc["key"] |> String.replace_leading("/works/", ""),
      media_type: :book,
      title: doc["title"],
      year: year,
      cover_url: cover_url,
      creators: doc["author_name"] || [],
      extra: %{"isbn" => doc["isbn"]}
    }
  end

  defp build_fetch_result(work, key) do
    cover_url =
      case get_in(work, ["covers"]) do
        [id | _] when is_integer(id) -> "#{@cover_url}/#{id}-M.jpg"
        _ -> nil
      end

    year =
      case work["first_publish_date"] do
        nil -> nil
        date -> date
      end

    author_keys =
      work
      |> Map.get("authors", [])
      |> Enum.map(fn a ->
        case a do
          %{"author" => %{"key" => k}} -> k
          %{"key" => k} -> k
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    %MediaResult{
      adapter: __MODULE__,
      external_id: key,
      media_type: :book,
      title: work["title"],
      year: year,
      cover_url: cover_url,
      creators: [],
      extra: %{"author_keys" => author_keys}
    }
  end
end
