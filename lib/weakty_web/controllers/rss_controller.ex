defmodule WeaktyWeb.RssController do
  use WeaktyWeb, :controller

  def posts(conn, _params) do
    require Ash.Query

    # Get all published posts, sorted by published date (newest first)
    posts =
      Weakty.Posts.Post
      |> Ash.Query.filter(status == :published)
      |> Ash.Query.sort(published_at: :desc)
      |> Ash.read!()
      |> Ash.load!([:tags], domain: Weakty.Posts)
      |> Enum.reject(&is_nil/1)

    # Build the RSS XML
    rss_xml = build_rss(posts)

    conn
    |> put_resp_content_type("application/rss+xml")
    |> send_resp(200, rss_xml)
  end

  defp build_rss(posts) do
    last_build_date =
      case List.first(posts) do
        nil -> DateTime.utc_now()
        post -> post.published_at || post.updated_at
      end

    """
    <?xml version="1.0" encoding="UTF-8" ?>
    <rss
        xmlns:dc="http://purl.org/dc/elements/1.1/"
        xmlns:content="http://purl.org/rss/1.0/modules/content/"
        xmlns:atom="http://www.w3.org/2005/Atom"
        version="2.0"
        xmlns:media="http://search.yahoo.com/mrss/"
    >
      <channel>
        <title><![CDATA[Weakty]]></title>
        <description><![CDATA[Hello, I'm Ty.]]></description>
        <link>https://weakty.com/</link>
        <image>
          <url>https://weakty.com/favicon.png</url>
          <title>Weakty</title>
          <link>https://weakty.com/</link>
        </image>
        <generator>Weakty Phoenix</generator>
        <lastBuildDate>#{format_rfc822(last_build_date)}</lastBuildDate>
        <atom:link href="https://weakty.com/rss/" rel="self" type="application/rss+xml" />
        <ttl>60</ttl>
        #{Enum.map_join(posts, "\n", &build_item/1)}
      </channel>
    </rss>
    """
  end

  defp build_item(nil), do: ""

  defp build_item(post) do
    """
    <item>
      <title><![CDATA[#{escape_cdata(post.title || "Untitled")}]]></title>
      <description><![CDATA[#{escape_cdata(post.excerpt || "")}]]></description>
      <link>https://weakty.com/posts/#{post.slug || post.id}/</link>
      <guid isPermaLink="false">#{post.id}</guid>
      #{build_categories(post.tags)}
      <dc:creator><![CDATA[Ty]]></dc:creator>
      <pubDate>#{format_rfc822(post.published_at)}</pubDate>
      <content:encoded><![CDATA[#{escape_cdata(post.html || "")}]]></content:encoded>
      #{build_media(post.featured_image)}
    </item>
    """
  end

  defp build_categories(tags) when is_list(tags) do
    Enum.map_join(tags, "\n", fn tag ->
      "<category><![CDATA[#{escape_cdata(tag.name)}]]></category>"
    end)
  end

  defp build_categories(_), do: ""

  defp build_media(nil), do: ""

  defp build_media(url) do
    """
    <media:content url="#{escape_xml(url)}" medium="image" />
    """
  end

  # Format datetime as RFC 822 (RSS requirement)
  defp format_rfc822(nil), do: format_rfc822(DateTime.utc_now())

  defp format_rfc822(datetime) do
    Calendar.strftime(datetime, "%a, %d %b %Y %H:%M:%S GMT")
  end

  # Escape CDATA content (handle ]]> sequence)
  defp escape_cdata(nil), do: ""

  defp escape_cdata(str) do
    String.replace(str, "]]>", "]]]]><![CDATA[>")
  end

  # Escape XML entities
  defp escape_xml(nil), do: ""

  defp escape_xml(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
