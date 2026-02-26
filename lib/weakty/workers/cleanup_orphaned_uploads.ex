defmodule Weakty.Workers.CleanupOrphanedUploads do
  use Oban.Worker, queue: :default
  require Logger

  @uploads_dir Path.join(["priv", "static", "uploads"])

  @impl true
  def perform(_job) do
    # Posts → root uploads/ files
    posts = Ash.read!(Weakty.Posts.Post, domain: Weakty.Posts, authorize?: false)

    post_refs =
      posts
      |> Enum.flat_map(fn post -> [post.featured_image | (post.content_images || [])] end)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&Path.basename/1)
      |> MapSet.new()

    # MediaLogs → uploads/media/ files
    media_logs = Ash.read!(Weakty.MediaLogs.MediaLog, domain: Weakty.MediaLogs, authorize?: false)

    media_refs =
      media_logs
      |> Enum.map(& &1.thumbnail_url)
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(&String.starts_with?(&1, "/uploads/media/"))
      |> Enum.map(&Path.basename/1)
      |> MapSet.new()

    uploads_dir = Application.app_dir(:weakty, @uploads_dir)
    media_dir = Path.join(uploads_dir, "media")

    # Clean root uploads/ — skip subdirectories (e.g. the media/ folder)
    if File.exists?(uploads_dir) do
      uploads_dir
      |> File.ls!()
      |> Enum.reject(&File.dir?(Path.join(uploads_dir, &1)))
      |> Enum.each(fn file ->
        unless MapSet.member?(post_refs, file) do
          File.rm!(Path.join(uploads_dir, file))
          Logger.info("Deleted orphaned upload: #{file}")
        end
      end)
    end

    # Clean uploads/media/
    if File.exists?(media_dir) do
      media_dir
      |> File.ls!()
      |> Enum.each(fn file ->
        unless MapSet.member?(media_refs, file) do
          File.rm!(Path.join(media_dir, file))
          Logger.info("Deleted orphaned media upload: #{file}")
        end
      end)
    end

    :ok
  end
end
