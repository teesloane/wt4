defmodule Weakty.ImageProcessor do
  require Logger

  # Widths (in px) to generate as WebP thumbnails
  @widths [400, 800, 1200]
  @thumbs_subdir "thumbnails"

  @doc """
  Generates WebP thumbnail variants for an uploaded image file.

  Creates `{uuid}_400w.webp`, `{uuid}_800w.webp`, `{uuid}_1200w.webp` in
  `priv/static/uploads/thumbnails/`. Skips any width larger than the original.

  Gracefully degrades if libvips is unavailable: logs a warning and returns
  `:error` so uploads still succeed without thumbnails.
  """
  @supported_exts ~w(.jpg .jpeg .png .gif .webp)

  def generate_thumbnails(source_path, uuid) do
    ext = source_path |> Path.extname() |> String.downcase()

    unless ext in @supported_exts do
      {:error, "Unsupported file type: #{ext}"}
    else
      do_generate_thumbnails(source_path, uuid)
    end
  end

  defp do_generate_thumbnails(source_path, uuid) do
    thumbs_dir = Path.join([:code.priv_dir(:weakty), "static", "uploads", @thumbs_subdir])
    File.mkdir_p!(thumbs_dir)

    try do
      image = Image.open!(source_path)
      {orig_width, _height, _bands} = Image.shape(image)

      for width <- @widths, orig_width > width do
        scale = width / orig_width
        dest = Path.join(thumbs_dir, "#{uuid}_#{width}w.webp")

        image
        |> Image.resize!(scale)
        |> Image.write!(dest)
      end

      :ok
    rescue
      e ->
        reason = Exception.message(e)
        Logger.warning("[ImageProcessor] #{uuid}: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Returns an HTML `srcset` string for the given upload path, or `nil` if no
  thumbnails exist on disk (e.g. the image was uploaded before thumbnail support
  was added, or libvips was unavailable at upload time).

  Returns `nil` rather than an empty string so Phoenix HEEx omits the attribute.
  """
  def srcset_for(nil), do: nil

  def srcset_for(path) when is_binary(path) do
    case extract_uuid(path) do
      nil ->
        nil

      uuid ->
        thumbs_dir = Path.join([:code.priv_dir(:weakty), "static", "uploads", @thumbs_subdir])

        entries =
          @widths
          |> Enum.filter(fn w -> File.exists?(Path.join(thumbs_dir, "#{uuid}_#{w}w.webp")) end)
          |> Enum.map(fn w -> "/uploads/#{@thumbs_subdir}/#{uuid}_#{w}w.webp #{w}w" end)

        case entries do
          [] -> nil
          _ -> Enum.join(entries, ", ")
        end
    end
  end

  @doc """
  Returns all thumbnail disk paths for a UUID (whether or not they exist).
  Used by the cleanup worker.
  """
  def thumbnail_disk_paths(uuid) do
    thumbs_dir = Path.join([:code.priv_dir(:weakty), "static", "uploads", @thumbs_subdir])
    Enum.map(@widths, fn w -> Path.join(thumbs_dir, "#{uuid}_#{w}w.webp") end)
  end

  defp extract_uuid(path) do
    case Regex.run(~r|/uploads/([a-f0-9-]{36})\.\w+$|, path) do
      [_, uuid] -> uuid
      _ -> nil
    end
  end
end
