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
    text = Regex.replace(~r/<[^>]+>/s, html, "")
    if String.length(text) <= max do
      text
    else
      text
      |> String.slice(0, max)
      |> String.split(~r/\s+/)
      |> Enum.drop(-1)
      |> Enum.join(" ")
      # remove any trailing punctuation if necessary
      |> String.replace(~r/\p{P}+$/u, "")
      |> Kernel.<>("…")
    end
  end

  def truncate_html(_, _), do: ""

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
