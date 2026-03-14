defmodule Weakty.OpenGraph do
  require Logger

  @doc """
  Fetches Open Graph metadata from the given URL.
  Returns {:ok, %{title, description, image}} or {:error, reason}.
  """
  def fetch(url) do
    headers = [{"user-agent", "Mozilla/5.0 (compatible; Weakty/1.0; +https://weakty.com)"}]

    case Req.get(url, max_redirects: 5, headers: headers, receive_timeout: 10_000) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        {:ok, parse(body)}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse(html) do
    %{
      title: extract_og(html, "og:title") || extract_meta_name(html, "title") || extract_title_tag(html),
      description: extract_og(html, "og:description") || extract_meta_name(html, "description"),
      image: extract_og(html, "og:image")
    }
  end

  defp extract_og(html, property) do
    prop = Regex.escape(property)

    # property before content
    result =
      Regex.run(
        ~r/<meta[^>]+property=["']#{prop}["'][^>]+content=["']([^"']+)["']/i,
        html
      )

    # content before property
    result =
      result ||
        Regex.run(
          ~r/<meta[^>]+content=["']([^"']+)["'][^>]+property=["']#{prop}["']/i,
          html
        )

    case result do
      [_, content] -> content |> String.trim() |> decode_html_entities()
      nil -> nil
    end
  end

  defp extract_meta_name(html, name) do
    n = Regex.escape(name)

    result =
      Regex.run(~r/<meta[^>]+name=["']#{n}["'][^>]+content=["']([^"']+)["']/i, html) ||
        Regex.run(~r/<meta[^>]+content=["']([^"']+)["'][^>]+name=["']#{n}["']/i, html)

    case result do
      [_, content] -> content |> String.trim() |> decode_html_entities()
      nil -> nil
    end
  end

  defp extract_title_tag(html) do
    case Regex.run(~r/<title[^>]*>([^<]+)<\/title>/i, html) do
      [_, title] -> title |> String.trim() |> decode_html_entities()
      nil -> nil
    end
  end

  defp decode_html_entities(nil), do: nil

  defp decode_html_entities(text) do
    text
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&apos;", "'")
    |> String.replace(~r/&#\d+;/, fn match ->
      n = match |> String.slice(2..-2//1) |> String.to_integer()
      List.to_string([n])
    end)
  end
end
