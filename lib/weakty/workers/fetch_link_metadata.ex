defmodule Weakty.Workers.FetchLinkMetadata do
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  @impl true
  def perform(%Oban.Job{args: %{"link_id" => link_id}}) do
    case Ash.get(Weakty.Links.Link, link_id, authorize?: false) do
      {:ok, link} ->
        fetch_and_store(link)

      {:error, reason} ->
        Logger.warning("FetchLinkMetadata: link #{link_id} not found: #{inspect(reason)}")
        {:error, :not_found}
    end
  end

  def fetch_and_store(link) do
    case Weakty.OpenGraph.fetch(link.url) do
      {:ok, og} ->
        og_image = if link.og_image_pinned, do: nil, else: maybe_download_image(og.image)

        attrs =
          %{}
          |> maybe_put(:og_title, og.title)
          |> maybe_put(:og_description, og.description)
          |> maybe_put(:og_image, og_image)

        if map_size(attrs) == 0 do
          :ok
        else
          link
          |> Ash.Changeset.for_update(:update_og, attrs, authorize?: false)
          |> Ash.update(authorize?: false)
          |> case do
            {:ok, _} ->
              :ok

            {:error, reason} ->
              Logger.warning(
                "FetchLinkMetadata: failed to update link #{link.id}: #{inspect(reason)}"
              )

              {:error, reason}
          end
        end

      {:error, reason} ->
        Logger.warning(
          "FetchLinkMetadata: failed to fetch OG for #{link.url}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp maybe_download_image(nil), do: nil

  defp maybe_download_image(url) do
    case Weakty.ImageDownloader.download(url, "link_thumbnails") do
      {:ok, local_path} ->
        local_path

      {:error, reason} ->
        Logger.warning(
          "FetchLinkMetadata: failed to download OG image #{url}: #{inspect(reason)}"
        )

        nil
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
