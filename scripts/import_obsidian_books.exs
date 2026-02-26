#!/usr/bin/env elixir

# Import book entries from Obsidian markdown files into Weakty's media_logs table.
#
# Usage:
#   mix run scripts/import_obsidian_books.exs <books_directory> <user_email>
#
# Example:
#   mix run scripts/import_obsidian_books.exs docs/plans/books weakty@fastmail.com
#
# YAML field normalization applied:
#   title         — strips "Author - Title" prefixes if the author field matches
#   author        — string or YAML array → comma-joined string → creator
#   cover/image   — http(s) URLs only; Obsidian [[internal links]] are ignored
#   publish/year  — full date or year-only → date_published (year → Jan 1)
#   started       — date_started  ("--" treated as nil)
#   finished/lastRead — date_finished
#   rating        — 0–10 integer/string → 1–5 scale (0 = unrated → nil)
#   type          — book → :book, manga/comic → :comic (default: :book)
#   status        — read → :consumed, reading → :consuming, unread → :want_to_consume
#   url           — open-library / external URLs → external_url

defmodule ObsidianBookImporter do
  def run(books_dir, user_email) do
    IO.puts("Starting Obsidian book import...")
    IO.puts("Books directory: #{books_dir}")
    IO.puts("User email: #{user_email}")
    IO.puts("")

    user = get_user(user_email)
    IO.puts("User: #{user.email} (#{user.id})")
    IO.puts("")

    files = scan_book_files(books_dir)
    IO.puts("Processing #{length(files)} markdown files...\n")

    results = Enum.map(files, &import_book(&1, user.id))

    successful = Enum.count(results, fn {s, _} -> s == :ok end)
    skipped    = Enum.count(results, fn {s, _} -> s == :skip end)
    failed     = Enum.count(results, fn {s, _} -> s == :error end)

    IO.puts("")
    IO.puts(String.duplicate("=", 60))
    IO.puts("Import complete!")
    IO.puts("  Imported: #{successful}")
    IO.puts("  Skipped:  #{skipped}")
    IO.puts("  Failed:   #{failed}")
    IO.puts(String.duplicate("=", 60))

    if failed > 0 do
      IO.puts("\nFailed imports:")
      results
      |> Enum.filter(fn {s, _} -> s == :error end)
      |> Enum.each(fn {:error, info} ->
        IO.puts("  #{info.file}: #{inspect(info.error)}")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # File scanning
  # ---------------------------------------------------------------------------

  defp scan_book_files(dir) do
    dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".md"))
    |> Enum.sort()
    |> Enum.map(fn filename ->
      path = Path.join(dir, filename)
      content = File.read!(path)
      parse_file(filename, content)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_file(filename, content) do
    case Regex.run(~r/\A---\r?\n(.*?)\r?\n---\r?\n?(.*)/s, content) do
      [_, yaml_str, body] ->
        %{
          filename: filename,
          frontmatter: parse_yaml(yaml_str),
          notes: extract_notes(body)
        }
      _ ->
        nil  # no YAML frontmatter — skip file
    end
  end

  # ---------------------------------------------------------------------------
  # Minimal YAML parser (handles key: value, key:\n  - list, inline [arrays])
  # ---------------------------------------------------------------------------

  defp parse_yaml(yaml_str) do
    yaml_str
    |> String.split("\n")
    |> Enum.reduce({%{}, nil}, fn line, {acc, cur_key} ->
      parse_yaml_line(line, acc, cur_key)
    end)
    |> elem(0)
  end

  defp parse_yaml_line(line, acc, cur_key) do
    cond do
      # List item under the previous key
      Regex.match?(~r/^\s+-\s*(.*)$/, line) ->
        [_, value] = Regex.run(~r/^\s+-\s*(.*)$/, line)
        item = clean_yaml_value(value)
        new_acc = case Map.get(acc, cur_key) do
          nil                           -> Map.put(acc, cur_key, [item])
          existing when is_list(existing) -> Map.put(acc, cur_key, existing ++ [item])
          existing                       -> Map.put(acc, cur_key, [existing, item])
        end
        {new_acc, cur_key}

      # key: value
      Regex.match?(~r/^([\w]+):\s+(.+)$/, line) ->
        [_, key, value] = Regex.run(~r/^([\w]+):\s+(.+)$/, line)
        {Map.put(acc, key, clean_yaml_value(value)), key}

      # key: (empty — list items follow, or intentionally blank)
      Regex.match?(~r/^([\w]+):\s*$/, line) ->
        [_, key] = Regex.run(~r/^([\w]+):\s*$/, line)
        {acc, key}

      true ->
        {acc, cur_key}
    end
  end

  defp clean_yaml_value(value) do
    v = String.trim(value)

    # Strip surrounding quotes
    v = cond do
      String.starts_with?(v, "\"") and String.ends_with?(v, "\"") ->
        String.slice(v, 1..-2//1)
      String.starts_with?(v, "'") and String.ends_with?(v, "'") ->
        String.slice(v, 1..-2//1)
      true ->
        v
    end

    # Expand inline YAML arrays: [a, b, c] → ["a", "b", "c"]
    if Regex.match?(~r/^\[.*\]$/, v) do
      v
      |> String.slice(1..-2//1)
      |> String.split(",")
      |> Enum.map(&String.trim/1)
    else
      v
    end
  end

  # ---------------------------------------------------------------------------
  # Notes body: strip image embeds, trim whitespace
  # ---------------------------------------------------------------------------

  defp extract_notes(body) do
    cleaned =
      body
      |> String.replace(~r/!\[\[.*?\]\]/, "")     # Obsidian image embeds
      |> String.replace(~r/!\[.*?\]\(.*?\)/, "")  # Markdown images
      |> String.trim()

    if cleaned == "", do: nil, else: cleaned
  end

  # ---------------------------------------------------------------------------
  # Book import
  # ---------------------------------------------------------------------------

  defp import_book(%{filename: filename, frontmatter: fm, notes: notes}, user_id) do
    basename = Path.basename(filename, ".md")
    IO.write("  #{basename}... ")

    case build_attrs(fm, notes, user_id) do
      {:skip, reason} ->
        IO.puts("skip (#{reason})")
        {:skip, filename}

      {:ok, attrs} ->
        case Weakty.MediaLogs.MediaLog
             |> Ash.Changeset.for_create(:create, attrs)
             |> Ash.create() do
          {:ok, _log} ->
            IO.puts("✓  [#{attrs.media_type}, #{attrs.status}]")
            {:ok, filename}

          {:error, error} ->
            IO.puts("✗")
            IO.puts("     #{inspect(error)}")
            {:error, %{file: filename, error: error}}
        end
    end
  end

  defp build_attrs(fm, notes, user_id) do
    title = extract_title(fm)

    cond do
      is_blank(title) ->
        {:skip, "no title"}

      # Files with no book-specific fields are likely index or notes files
      is_blank(Map.get(fm, "status")) and
      is_blank(Map.get(fm, "author")) and
      is_blank(Map.get(fm, "rating")) ->
        {:skip, "no book metadata (likely index or notes file)"}

      true ->
        status        = extract_status(fm)
        date_finished = parse_date(Map.get(fm, "finished") || Map.get(fm, "lastRead"))

        attrs = %{
          title:          title,
          media_type:     extract_media_type(fm),
          status:         status,
          creator:        extract_author(fm),
          date_published: parse_date(Map.get(fm, "publish") || Map.get(fm, "year")),
          date_started:   parse_date(Map.get(fm, "started")),
          date_finished:  date_finished,
          # date_consumed drives entity creation; for books, mirror date_finished when consumed
          date_consumed:  if(status == :consumed, do: date_finished, else: nil),
          rating:         extract_rating(fm),
          notes:          notes,
          thumbnail_url:  extract_cover(fm),
          external_url:   extract_external_url(fm),
          public:         true,
          user_id:        user_id
        }
        |> reject_nils()

        {:ok, attrs}
    end
  end

  # ---------------------------------------------------------------------------
  # Field extractors
  # ---------------------------------------------------------------------------

  # Strip "Author Name - Title" patterns where the author field matches the prefix.
  # e.g. title: "R.F. Kuang - Babel", author: "R. F. Kuang" → "Babel"
  defp extract_title(fm) do
    raw    = fm |> Map.get("title", "") |> str() |> String.trim()
    author = extract_author(fm) |> str()

    case Regex.run(~r/^(.+?) - (.+)$/, raw) do
      [_, prefix, rest] ->
        if norm(author) != "" and String.contains?(norm(prefix), norm(author)) do
          String.trim(rest)
        else
          raw
        end
      _ ->
        raw
    end
  end

  # type: manga or comic (or genre/tags containing "manga") → :comic; else :book
  defp extract_media_type(fm) do
    type  = fm |> Map.get("type", "") |> str() |> String.downcase()
    genre = fm |> Map.get("genre") |> list_or_string() |> String.downcase()
    tags  = fm |> Map.get("tags")  |> list_or_string() |> String.downcase()

    cond do
      type in ["manga", "comic"] -> :comic
      String.contains?(genre, "manga") -> :comic
      String.contains?(tags, "manga")  -> :comic
      String.contains?(tags, "comic")  -> :comic
      true -> :book
    end
  end

  defp extract_status(fm) do
    s    = fm |> Map.get("status", "") |> str() |> String.downcase()
    read = Map.get(fm, "read")

    cond do
      s in ["read", "finished", "completed"]                   -> :consumed
      s in ["reading", "currently reading", "in progress"]     -> :consuming
      s in ["unread", "to read", "want to read"]               -> :want_to_consume
      s in ["dnf", "abandoned", "dropped"]                     -> :abandoned
      s in ["on hold", "paused"]                               -> :on_hold
      read == false or read == "false"                         -> :want_to_consume
      true                                                     -> :want_to_consume
    end
  end

  defp extract_author(fm) do
    case Map.get(fm, "author") do
      nil ->
        nil
      authors when is_list(authors) ->
        joined = authors |> Enum.map(&str/1) |> Enum.join(", ")
        if joined == "", do: nil, else: joined
      author ->
        s = author |> str() |> String.trim()
        if s == "", do: nil, else: s
    end
  end

  # Maps 0–10 rating scale to Weakty's 1–5 (0 = unrated → nil).
  # Also accepts onlineRating / personalRating as fallbacks.
  defp extract_rating(fm) do
    raw = Map.get(fm, "rating") || Map.get(fm, "personalRating")
    case parse_num(raw) do
      nil -> nil
      n   -> map_rating(round(n))
    end
  end

  defp map_rating(0),               do: nil
  defp map_rating(n) when n in 1..2, do: 1
  defp map_rating(n) when n in 3..4, do: 2
  defp map_rating(n) when n in 5..6, do: 3
  defp map_rating(n) when n in 7..8, do: 4
  defp map_rating(n) when n in 9..10, do: 5
  defp map_rating(_),                do: nil

  # Returns HTTP(S) URLs only; Obsidian [[internal]] links are discarded.
  # Downloads external URLs to local storage and returns the local path.
  defp extract_cover(fm) do
    url = Map.get(fm, "cover") || Map.get(fm, "image")

    case http_url(url) do
      nil -> nil
      external_url -> Weakty.ImageDownloader.maybe_download(external_url, "media")
    end
  end

  defp extract_external_url(fm) do
    http_url(Map.get(fm, "url"))
  end

  defp http_url(nil), do: nil
  defp http_url(v) when is_binary(v) do
    s = String.trim(v)
    if String.starts_with?(s, "http"), do: s, else: nil
  end
  defp http_url(_), do: nil

  # ---------------------------------------------------------------------------
  # Date parsing
  # ---------------------------------------------------------------------------

  defp parse_date(nil), do: nil
  defp parse_date(list) when is_list(list), do: parse_date(List.first(list))
  defp parse_date(v) do
    s = v |> str() |> String.trim()
    cond do
      s in ["", "--", "null", "false", "true"] ->
        nil
      Regex.match?(~r/^\d{4}-\d{2}-\d{2}$/, s) ->
        case Date.from_iso8601(s) do
          {:ok, d} -> d
          _        -> nil
        end
      Regex.match?(~r/^\d{4}$/, s) ->
        Date.new!(String.to_integer(s), 1, 1)
      true ->
        nil
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp parse_num(nil), do: nil
  defp parse_num(n) when is_number(n), do: n
  defp parse_num(s) when is_binary(s) do
    case Float.parse(s) do
      {n, _} -> n
      :error -> nil
    end
  end
  defp parse_num(_), do: nil

  # Normalise a name for fuzzy comparison: lowercase, letters only
  defp norm(s), do: s |> str() |> String.downcase() |> String.replace(~r/[^a-z]/, "")

  defp str(nil), do: ""
  defp str(v) when is_binary(v), do: v
  defp str(v), do: to_string(v)

  defp list_or_string(nil), do: ""
  defp list_or_string(list) when is_list(list), do: Enum.join(Enum.map(list, &str/1), " ")
  defp list_or_string(v), do: str(v)

  defp is_blank(nil), do: true
  defp is_blank(""), do: true
  defp is_blank([]), do: true
  defp is_blank(_), do: false

  defp reject_nils(map) do
    map |> Enum.reject(fn {_k, v} -> is_nil(v) end) |> Map.new()
  end

  # ---------------------------------------------------------------------------
  # User lookup
  # ---------------------------------------------------------------------------

  defp get_user(email) do
    case Weakty.Accounts.User
         |> Ash.Query.for_read(:get_by_email, %{email: email})
         |> Ash.read_one() do
      {:ok, user} when not is_nil(user) ->
        user
      {:ok, nil} ->
        IO.puts("Error: no user found with email '#{email}'")
        System.halt(1)
      {:error, error} ->
        IO.puts("Error looking up user: #{inspect(error)}")
        System.halt(1)
    end
  end
end

# Entry point — only runs when invoked directly (not when loaded via Code.require_file)
if System.argv() != [] do
  case System.argv() do
    [books_dir, user_email] ->
      ObsidianBookImporter.run(books_dir, user_email)
    _ ->
      IO.puts("""
      Usage: mix run scripts/import_obsidian_books.exs <books_directory> <user_email>

      Example:
        mix run scripts/import_obsidian_books.exs docs/plans/books weakty@fastmail.com
      """)
      System.halt(1)
  end
end
