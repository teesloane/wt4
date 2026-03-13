defmodule Weakty.LinkChecker do
  require Logger

  @timeout 8_000
  @concurrency 15

  @doc """
  Checks all external links across posts (including TILs and quotes) and projects.
  Returns %{total: integer, broken: [link_result]}.

  Deduplicates URLs so each unique URL is only fetched once, then maps results
  back to all sources that reference it.
  """
  def check_all do
    links = gather_all_links()
    unique_urls = links |> Enum.map(& &1.url) |> Enum.uniq()

    url_results =
      unique_urls
      |> Task.async_stream(
        fn url -> {url, check_url(url)} end,
        max_concurrency: @concurrency,
        timeout: @timeout + 2_000,
        on_timeout: :kill_task
      )
      |> Enum.reduce(%{}, fn
        {:ok, {url, result}}, acc -> Map.put(acc, url, result)
        {:exit, _}, acc -> acc
      end)

    broken =
      links
      |> Enum.map(fn link ->
        result = Map.get(url_results, link.url, %{ok: false, status: nil, error: "timed out"})
        Map.put(link, :result, result)
      end)
      |> Enum.reject(fn link -> link.result.ok end)
      |> Enum.uniq_by(fn link -> {link.url, link.source_id} end)

    %{total: length(unique_urls), broken: broken}
  end

  # --- Link gathering ---

  defp gather_all_links do
    post_links() ++ project_links()
  end

  defp post_links do
    Ash.read!(Weakty.Posts.Post, domain: Weakty.Posts, authorize?: false)
    |> Enum.flat_map(fn post ->
      links = extract_links(post.markdown)

      Enum.map(links, fn url ->
        %{
          url: url,
          source_title: post.title,
          source_id: post.id,
          source_type: post_type_label(post.post_type),
          admin_path: admin_path_for_post(post)
        }
      end)
    end)
  end

  defp project_links do
    Ash.read!(Weakty.Projects.Project, domain: Weakty.Projects, authorize?: false)
    |> Enum.flat_map(fn project ->
      links = extract_links(project.markdown)

      Enum.map(links, fn url ->
        %{
          url: url,
          source_title: project.title,
          source_id: project.id,
          source_type: "Project",
          admin_path: "/admin/projects/#{project.id}/edit"
        }
      end)
    end)
  end

  defp extract_links(nil), do: []

  defp extract_links(markdown) do
    # [text](url) links
    md_links =
      ~r/\[[^\]]*\]\((https?:\/\/[^)]+)\)/
      |> Regex.scan(markdown, capture: :all_but_first)
      |> List.flatten()

    # bare https?:// URLs (not already inside a markdown link)
    bare_links =
      ~r/(?<!\()(https?:\/\/[^\s"'<>)\]]+)/
      |> Regex.scan(markdown, capture: :all_but_first)
      |> List.flatten()

    (md_links ++ bare_links)
    |> Enum.map(&clean_url/1)
    |> Enum.filter(&valid_url?/1)
    |> Enum.uniq()
  end

  defp clean_url(url) do
    # Strip trailing punctuation that got caught by the regex
    String.trim_trailing(url, ".,;:!?")
  end

  defp valid_url?(url) do
    uri = URI.parse(url)
    uri.scheme in ["http", "https"] and is_binary(uri.host) and uri.host != ""
  rescue
    _ -> false
  end

  # --- HTTP checking ---

  defp check_url(url) do
    opts = [
      max_redirects: 5,
      receive_timeout: @timeout,
      headers: [{"user-agent", "Mozilla/5.0 (compatible; WeaktyLinkChecker/1.0)"}],
      decode_body: false
    ]

    case Req.head(url, opts) do
      {:ok, %{status: status}} when status < 400 ->
        %{ok: true, status: status}

      {:ok, %{status: status}} when status in [403, 429] ->
        # Bot-blocking — server is alive, link is probably fine
        %{ok: true, status: status}

      {:ok, %{status: status}} ->
        # Some servers reject HEAD — retry with GET
        case Req.get(url, opts) do
          {:ok, %{status: s}} when s < 400 -> %{ok: true, status: s}
          {:ok, %{status: s}} when s in [403, 429] -> %{ok: true, status: s}
          {:ok, %{status: s}} -> %{ok: false, status: s}
          {:error, _} -> %{ok: false, status: status}
        end

      {:error, %{reason: reason}} ->
        %{ok: false, status: nil, error: format_error(reason)}
    end
  rescue
    e -> %{ok: false, status: nil, error: Exception.message(e)}
  end

  defp format_error(:timeout), do: "timeout"
  defp format_error(:econnrefused), do: "connection refused"
  defp format_error(:nxdomain), do: "domain not found"
  defp format_error(reason) when is_atom(reason), do: to_string(reason)
  defp format_error(reason), do: inspect(reason)

  # --- Helpers ---

  defp post_type_label(:til), do: "TIL"
  defp post_type_label(:quote), do: "Quote"
  defp post_type_label(:update), do: "Update"
  defp post_type_label(:page), do: "Page"
  defp post_type_label(_), do: "Post"

  defp admin_path_for_post(%{post_type: :til, id: id}), do: "/admin/til/#{id}/edit"
  defp admin_path_for_post(%{post_type: :quote, id: id}), do: "/admin/quotes/#{id}/edit"
  defp admin_path_for_post(%{id: id}), do: "/admin/posts/#{id}/edit"
end
