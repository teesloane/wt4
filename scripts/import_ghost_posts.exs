#!/usr/bin/env elixir

# Script to import Ghost posts from a JSON export file
#
# Usage:
#   mix run scripts/import_ghost_posts.exs <path_to_ghost_export.json> <user_email>
#
# Example:
#   mix run scripts/import_ghost_posts.exs ghost_export.json weakty@fastmail.com

defmodule GhostImporter do
  @moduledoc """
  Imports posts from a Ghost JSON export into Weakty's posts table.
  """

  def run(json_path, user_email) do
    IO.puts("Starting Ghost import...")
    IO.puts("JSON file: #{json_path}")
    IO.puts("User email: #{user_email}")
    IO.puts("")

    # Delete all existing posts first
    delete_all_posts()

    # Read and parse the JSON file
    json_data = read_json_file(json_path)

    # Ghost exports are an array with a single object
    # db_data = case json_data do
    #   [first | _] -> Map.get(first, "data", %{})
    #   %{"db" => %{"data" => data}} -> data
    #   %{"data" => data} -> data
    #   _ -> %{}
    # end

    db_data = json_data |> Map.get("db") |> Enum.at(0) |> Map.get("data")

    # Extract posts from the nested structure
    posts = Map.get(db_data, "posts", [])

    IO.puts("Found #{length(posts)} total items in Ghost export")

    # Filter to only posts (not pages) and published/draft items
    importable_posts = Enum.filter(posts, fn post ->
      post["type"] == "post"
    end)
    IO.puts("Found #{length(importable_posts)} posts to import (excluding pages)")
    IO.puts("")

    # Get the user
    user = get_user(user_email)
    IO.puts("Importing posts for user: #{user.email} (#{user.id})")
    IO.puts("")

    # Extract tags if available
    ghost_tags = Map.get(db_data, "tags", [])
    posts_tags = Map.get(db_data, "posts_tags", [])

    # Import each post
    results = Enum.map(importable_posts, fn ghost_post ->
      import_post(ghost_post, user.id, ghost_tags, posts_tags)
    end)

    # Report results
    successful = Enum.count(results, fn {status, _} -> status == :ok end)
    failed = Enum.count(results, fn {status, _} -> status == :error end)

    IO.puts("")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Import complete!")
    IO.puts("Successfully imported: #{successful}")
    IO.puts("Failed: #{failed}")
    IO.puts("=" |> String.duplicate(60))

    if failed > 0 do
      IO.puts("\nFailed imports:")
      results
      |> Enum.filter(fn {status, _} -> status == :error end)
      |> Enum.each(fn {:error, error} ->
        IO.puts("  - #{inspect(error)}")
      end)
    end
  end

  defp delete_all_posts do
    IO.write("Deleting all existing posts... ")

    case Weakty.Posts.Post
         |> Ash.Query.for_read(:read)
         |> Ash.read() do
      {:ok, posts} ->
        deleted_count = Enum.reduce(posts, 0, fn post, count ->
          case Weakty.Posts.Post.delete_post(post) do
            :ok -> count + 1
            {:error, _} -> count
          end
        end)
        IO.puts("Deleted #{deleted_count} posts")
        IO.puts("")

      {:error, error} ->
        IO.puts("Error reading posts: #{inspect(error)}")
        System.halt(1)
    end
  end

  defp read_json_file(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> data
          {:error, error} ->
            IO.puts("Error parsing JSON: #{inspect(error)}")
            System.halt(1)
        end
      {:error, reason} ->
        IO.puts("Error reading file: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp get_user(email) do
    case Weakty.Accounts.User
         |> Ash.Query.for_read(:get_by_email, %{email: email})
         |> Ash.read_one() do
      {:ok, user} when not is_nil(user) ->
        user
      {:ok, nil} ->
        IO.puts("Error: User with email '#{email}' not found")
        IO.puts("Please create a user first or use a different email")
        System.halt(1)
      {:error, error} ->
        IO.puts("Error fetching user: #{inspect(error)}")
        System.halt(1)
    end
  end

  defp import_post(ghost_post, user_id, ghost_tags, posts_tags) do
    title = ghost_post["title"]
    slug = ghost_post["slug"]

    IO.write("Importing: #{title} (#{slug})... ")

    # Convert Ghost HTML to markdown
    markdown = convert_html_to_markdown(ghost_post["html"])

    # Map Ghost fields to Weakty Post fields
    post_attrs = %{
      title: title,
      slug: slug,
      markdown: markdown,
      html: ghost_post["html"],
      featured_image: ghost_post["feature_image"],
      excerpt: ghost_post["custom_excerpt"],
      status: parse_status(ghost_post["status"]),
      featured: parse_boolean(ghost_post["featured"]),
      public: parse_visibility(ghost_post["visibility"]),
      published_at: parse_datetime(ghost_post["published_at"]),
      post_type: parse_post_type(ghost_post["type"]),
      user_id: user_id
    }

    # Skip tags for now - they can be imported separately
    # tags = get_post_tags(ghost_post["id"], ghost_tags, posts_tags)
    # post_attrs = if length(tags) > 0 do
    #   Map.put(post_attrs, :tags, tags)
    # else
    #   post_attrs
    # end

    case Weakty.Posts.Post
         |> Ash.Changeset.for_create(:create, post_attrs)
         |> Ash.create() do
      {:ok, _post} ->
        IO.puts("✓")
        {:ok, slug}
      {:error, error} ->
        IO.puts("✗")
        IO.puts("  Error: #{inspect(error)}")
        {:error, %{slug: slug, error: error}}
    end
  end

  defp parse_status("published"), do: :published
  defp parse_status("draft"), do: :draft
  defp parse_status(_), do: :draft

  defp parse_post_type("post"), do: :post
  defp parse_post_type("page"), do: :page
  defp parse_post_type(_), do: :post

  defp parse_boolean(1), do: true
  defp parse_boolean(0), do: false
  defp parse_boolean(true), do: true
  defp parse_boolean(false), do: false
  defp parse_boolean(_), do: false

  defp parse_visibility("public"), do: true
  defp parse_visibility(_), do: false

  defp parse_datetime(nil), do: nil
  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _offset} -> datetime
      {:error, _} -> nil
    end
  end

  defp convert_html_to_markdown(nil), do: ""
  defp convert_html_to_markdown(""), do: ""
  defp convert_html_to_markdown(html) when is_binary(html) do
    case Htmd.convert(html) do
      {:ok, markdown} -> markdown
      {:error, _} ->
        IO.puts("Warning: Failed to convert HTML to markdown, using empty string")
        ""
    end
  end

  defp get_post_tags(ghost_post_id, ghost_tags, posts_tags) do
    # Find all tag IDs for this post
    tag_ids = posts_tags
    |> Enum.filter(fn pt -> pt["post_id"] == ghost_post_id end)
    |> Enum.map(fn pt -> pt["tag_id"] end)

    # Get the tag names - use string keys to match JSON format
    ghost_tags
    |> Enum.filter(fn tag -> tag["id"] in tag_ids end)
    |> Enum.map(fn tag -> %{"name" => tag["name"]} end)
  end
end

# Main execution — only runs when invoked directly (not when loaded via Code.require_file)
if System.argv() != [] do
  case System.argv() do
    [json_path, user_email] ->
      GhostImporter.run(json_path, user_email)

    _ ->
      IO.puts("""
      Usage: mix run scripts/import_ghost_posts.exs <path_to_ghost_export.json> <user_email>

      Example:
        mix run scripts/import_ghost_posts.exs ghost_export.json weakty@fastmail.com

      Arguments:
        <path_to_ghost_export.json>  Path to your Ghost JSON export file
        <user_email>                 Email of the user to assign posts to
      """)
      System.halt(1)
  end
end
