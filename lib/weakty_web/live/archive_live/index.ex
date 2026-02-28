defmodule WeaktyWeb.ArchiveLive.Index do
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

      <div class="capitalize">
        <%= for entity <- @entities do %>
          <div class="flex items-center gap-4 py-3 group text-sm">
            <time class=" opacity-30 flex-shrink-0">
              <%= Calendar.strftime(entity.published_at, "%Y-%m-%d") %>
            </time>
            <span class="opacity-30 min-w-32 flex-shrink-0" title={to_string(entity.entity_type)}>
              <%= entity.subtype || entity.entity_type %>
            </span>
            <%= if entity.entity_type == :media_log do %>
              <span class="flex-1 w-2/4 text-sm opacity-50 truncate"><%= entity.title %></span>
            <% else %>
              <a href={"#{entity.source_path}/#{entity.slug}"} class="flex-1  opacity-80 group-hover:opacity-100 transition-opacity truncate">
                <%= entity.title %>
              </a>
            <% end %>
          </div>
        <% end %>
      </div>
    </.page_container>
    """
  end

end
