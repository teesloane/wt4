defmodule Weakty.Workers.CleanupOrphanedUploads do
  use Oban.Worker, queue: :default

  @uploads_dir Path.join(["priv", "static", "uploads"])

  @impl true
  def perform(_job) do
    posts = Ash.read!(Weakty.Posts.Post, domain: Weakty.Posts, authorize?: false)

    referenced =
      posts
      |> Enum.flat_map(fn post -> [post.featured_image | (post.content_images || [])] end)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&Path.basename/1)
      |> MapSet.new()

    uploads_dir = Application.app_dir(:weakty, @uploads_dir)

    if File.exists?(uploads_dir) do
      uploads_dir
      |> File.ls!()
      |> Enum.each(fn file ->
        unless MapSet.member?(referenced, file) do
          File.rm!(Path.join(uploads_dir, file))
          require Logger
          Logger.info("Deleted orphaned upload: #{file}")
        end
      end)
    end

    :ok
  end
end
