defmodule Weakty.Media.Adapters.MusicBrainz do
  @behaviour Weakty.Media.Adapter

  alias Weakty.Media.MediaResult

  @base_url "https://musicbrainz.org/ws/2"
  @cover_url "https://coverartarchive.org/release"
  @user_agent "Weakty/0.1 (https://weakty.com)"

  @impl true
  def media_types, do: [:music]

  @impl true
  def search(query) do
    url = "#{@base_url}/release?query=#{URI.encode(query)}&fmt=json"

    case Req.get(url, headers: [{"User-Agent", @user_agent}]) do
      {:ok, %{status: 200, body: body}} ->
        results =
          body
          |> Map.get("releases", [])
          |> Enum.map(&build_result/1)

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
  def fetch(mbid) do
    url = "#{@base_url}/release/#{mbid}?inc=artists+labels+recordings&fmt=json"

    case Req.get(url, headers: [{"User-Agent", @user_agent}]) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, build_result(body)}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp build_result(release) do
    id = release["id"]
    has_front_cover = get_in(release, ["cover-art-archive", "front"]) == true

    cover_url =
      if has_front_cover do
        "#{@cover_url}/#{id}/front-250"
      end

    creators =
      release
      |> Map.get("artist-credit", [])
      |> Enum.map(fn ac -> get_in(ac, ["artist", "name"]) end)
      |> Enum.reject(&is_nil/1)

    year =
      release["date"] ||
        case release["first-release-date"] do
          nil -> nil
          date -> date
        end

    %MediaResult{
      adapter: __MODULE__,
      external_id: id,
      media_type: :music,
      title: release["title"],
      year: year,
      cover_url: cover_url,
      creators: creators,
      extra: %{
        "status" => release["status"],
        "label-info" => release["label-info"],
        "track-count" => release["track-count"]
      }
    }
  end
end
