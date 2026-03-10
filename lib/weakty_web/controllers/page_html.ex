defmodule WeaktyWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use WeaktyWeb, :html

  embed_templates "page_html/*"

  # for displaying a chunk of html, but strips the text
  # out first so that we don't have to worry about
  # the truncating happening mid-tag
  def truncate_html(html, max) when is_binary(html) do
    text = html
      |> String.replace(~r/<li[^>]*>/i, "\n• ")
      |> String.replace(~r/<\/?(p|div|br|h[1-6]|ul|ol|blockquote)[^>]*>/i, "\n")
      |> then(&Regex.replace(~r/<[^>]+>/s, &1, ""))
      |> decode_html_entities()
      |> String.replace(~r/\n{3,}/, "\n\n")
      |> String.trim()
    if String.length(text) <= max do
      text
    else
      truncated = String.slice(text, 0, max)
      # Trim back to last word boundary without collapsing internal whitespace
      trimmed = case Regex.run(~r/\s\S*$/, truncated) do
        [tail] -> String.slice(truncated, 0, String.length(truncated) - String.length(tail))
        nil -> truncated
      end
      trimmed
      |> String.replace(~r/\p{P}+$/u, "")
      |> String.trim_trailing()
      |> Kernel.<>("…")
    end
  end

  def truncate_html(_, _), do: ""

  defp decode_html_entities(text) do
    text
    |> String.replace("&amp;", "&")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&apos;", "'")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&nbsp;", " ")
  end

  attr :href, :string, required: true
  attr :label, :string, required: true

  def view_all(assigns) do
    ~H"""
    <div class="mt-5">
      <a href={@href} class="text-xs opacity-50 hover:opacity-70 transition-opacity">
        <%= @label %> →
      </a>
    </div>
    """
  end

  slot :inner_block, required: true

  def home_grid_header(assigns) do
    ~H"""
      <p class="text-xs uppercase tracking-widest opacity-50 mb-6">
      <%= render_slot(@inner_block) %>
      </p>
    """
  end
end
