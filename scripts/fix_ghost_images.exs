#!/usr/bin/env elixir

# Fixes posts with __GHOST_URL__ image references by:
#   1. Assigning each unique ghost image a UUID
#   2. Copying it to priv/static/uploads/{uuid}.{ext}
#   3. Generating thumbnails via Weakty.ImageProcessor
#   4. Updating featured_image, markdown, and html in the DB
#
# Usage:
#   mix run scripts/fix_ghost_images.exs

import Ecto.Query

app_root = File.cwd!()
ghost_base = Path.join(app_root, "ghost_images")
upload_base = Path.join(app_root, "priv/static/uploads")

IO.puts("Ghost images source: #{ghost_base}")
IO.puts("Upload destination:  #{upload_base}")
IO.puts("")

# --- Build a map of ghost_suffix => uuid for deduplication ---
# We scan all posts upfront so that the same source image referenced
# in multiple posts always resolves to the same UUID.

posts =
  Weakty.Repo.all(
    from p in "posts",
      where:
        like(p.featured_image, "%GHOST_URL%") or
          like(p.markdown, "%GHOST_URL%") or
          like(p.html, "%GHOST_URL%"),
      select: %{
        id: p.id,
        title: p.title,
        featured_image: p.featured_image,
        markdown: p.markdown,
        html: p.html
      }
  )

IO.puts("Found #{length(posts)} posts with ghost image URLs\n")

# Collect every unique ghost suffix across all text fields
all_suffixes =
  posts
  |> Enum.flat_map(fn post ->
    fields = [post.featured_image, post.markdown, post.html]

    Enum.flat_map(fields, fn text ->
      if text && String.contains?(text, "__GHOST_URL__") do
        Regex.scan(~r/__GHOST_URL__\/content\/images\/([^\s\)\"\>]+)/, text, capture: :all_but_first)
        |> Enum.map(fn [s] -> s end)
      else
        []
      end
    end)
  end)
  |> Enum.uniq()

IO.puts("Unique images to process: #{length(all_suffixes)}\n")

# Copy each image and build suffix => new_url map
suffix_to_url =
  Enum.reduce(all_suffixes, %{}, fn suffix, acc ->
    src = Path.join(ghost_base, suffix)

    if File.exists?(src) do
      ext = Path.extname(suffix)
      uuid = Ecto.UUID.generate()
      dest = Path.join(upload_base, "#{uuid}#{ext}")
      new_url = "/uploads/#{uuid}#{ext}"

      File.mkdir_p!(upload_base)
      File.copy!(src, dest)
      IO.puts("Copied  #{suffix}")
      IO.puts("     -> #{new_url}")

      case Weakty.ImageProcessor.generate_thumbnails(dest, uuid) do
        :ok -> IO.puts("     -> thumbnails generated")
        {:error, reason} -> IO.puts("     -> thumbnails skipped (#{reason})")
      end

      Map.put(acc, suffix, new_url)
    else
      IO.puts("WARNING: Not found: #{src}")
      acc
    end
  end)

IO.puts("")

# Replace __GHOST_URL__/content/images/{suffix} with new_url in a string
replace_all = fn text ->
  if text && String.contains?(text, "__GHOST_URL__") do
    Regex.replace(
      ~r/__GHOST_URL__\/content\/images\/([^\s\)\"\>]+)/,
      text,
      fn _full, suffix ->
        Map.get(suffix_to_url, suffix, "__GHOST_URL__/content/images/#{suffix}")
      end
    )
  else
    text
  end
end

# Update each post
Enum.each(posts, fn post ->
  IO.puts("Updating: #{post.title}")

  new_featured = replace_all.(post.featured_image)
  new_markdown = replace_all.(post.markdown)
  new_html = replace_all.(post.html)

  changes =
    []
    |> then(&if new_featured != post.featured_image, do: [{:featured_image, new_featured} | &1], else: &1)
    |> then(&if new_markdown != post.markdown, do: [{:markdown, new_markdown} | &1], else: &1)
    |> then(&if new_html != post.html, do: [{:html, new_html} | &1], else: &1)

  if changes != [] do
    Weakty.Repo.update_all(
      from(p in "posts", where: p.id == ^post.id),
      set: changes
    )
    IO.puts("  Updated #{length(changes)} field(s)")
  else
    IO.puts("  (no changes)")
  end
end)

IO.puts("\nDone!")
