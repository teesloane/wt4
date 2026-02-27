defmodule WeaktyWeb.TimelineLive.Index do
  use WeaktyWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Get all public entities and sort by published date (most recent first)
    entities =
      Weakty.Content.Entity.list_entities!()
      |> Ash.load!([:tags], domain: Weakty.Content)
      |> Enum.filter(& &1.public)
      |> Enum.sort_by(& &1.published_at, {:desc, DateTime})
      |> Enum.uniq_by(& {&1.entity_type, &1.slug})

    {:ok, assign(socket, entities: entities)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container>
      <h1 class="text-4xl font-normal mb-16 text-center uppercase tracking-wide averia">
        Archive
      </h1>

      <div class="divide-y divide-base-content/10">
        <%= for entity <- @entities do %>
          <div class="flex items-center gap-4 py-3 group">
            <span class="opacity-30 w-4 flex-shrink-0" title={to_string(entity.entity_type)}>
              <.icon name={entity_icon(entity.entity_type)} class="w-4 h-4" />
            </span>
            <%= if entity.entity_type == :media_log do %>
              <span class="flex-1 text-sm opacity-50 truncate"><%= entity.title %></span>
            <% else %>
              <a href={"#{entity.source_path}/#{entity.slug}"} class="flex-1 text-sm opacity-80 group-hover:opacity-100 transition-opacity truncate">
                <%= entity.title %>
              </a>
            <% end %>
            <time class="text-xs opacity-30 flex-shrink-0 tabular-nums">
              <%= Calendar.strftime(entity.published_at, "%Y-%m-%d") %>
            </time>
          </div>
        <% end %>
      </div>
    </.page_container>
    """
  end

  defp entity_icon(:post),      do: "hero-pencil"
  defp entity_icon(:link),      do: "hero-link"
  defp entity_icon(:til),       do: "hero-light-bulb"
  defp entity_icon(:bookmark),  do: "hero-bookmark"
  defp entity_icon(:media_log), do: "hero-play"
  defp entity_icon(:photo),     do: "hero-photo"
  defp entity_icon(:quote),     do: "hero-chat-bubble-left"
  defp entity_icon(_),          do: "hero-ellipsis-horizontal"
end
