defmodule Weakty.ImageDownloader do
  require Logger

  @doc """
  If `url` is an external HTTP(S) URL, downloads it to `priv/static/uploads/<subdir>/`
  and returns the local path. If already local or download fails, returns the original value.
  """
  def maybe_download(nil, _subdir), do: nil

  def maybe_download(url, subdir) when is_binary(url) do
    if String.starts_with?(url, "http") do
      case download(url, subdir) do
        {:ok, local_path} ->
          local_path

        {:error, reason} ->
          Logger.warning("Image download failed for #{url}: #{inspect(reason)}")
          url
      end
    else
      url
    end
  end

  def download(url, subdir) do
    with {:ok, resp} <-
           Req.get(url,
             max_redirects: 10,
             decode_body: false,
             headers: [{"user-agent", "Weakty/0.1 (https://weakty.com)"}]
           ),
         200 <- resp.status,
         ext <- detect_ext(resp) do
      uuid = Ecto.UUID.generate()
      filename = "#{uuid}.#{ext}"
      dir = Path.join([:code.priv_dir(:weakty), "static", "uploads", subdir])
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, filename), resp.body)
      {:ok, "/uploads/#{subdir}/#{filename}"}
    else
      status when is_integer(status) -> {:error, "HTTP #{status}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp detect_ext(resp) do
    content_type =
      resp.headers
      |> Enum.find_value("image/jpeg", fn
        {"content-type", v} when is_binary(v) -> v
        {"content-type", [v | _]} -> v
        _ -> false
      end)
      |> String.split(";")
      |> List.first()
      |> String.trim()

    case content_type do
      "image/png" -> "png"
      "image/gif" -> "gif"
      "image/webp" -> "webp"
      _ -> "jpg"
    end
  end
end
