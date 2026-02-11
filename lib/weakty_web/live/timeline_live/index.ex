defmodule WeaktyWeb.TimelineLive.Index do
  use WeaktyWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Get all public entities and sort by published date (most recent first)
    entities =
      Weakty.Content.Entity.list_entities!()
      |> Enum.filter(& &1.public)
      |> Enum.sort_by(& &1.published_at, {:desc, DateTime})
      |> Enum.uniq_by(& {&1.entity_type, &1.slug})

    {:ok, assign(socket, entities: entities)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto px-6 py-16">
      <h1 class="text-4xl font-normal mb-16 text-center uppercase tracking-wide averia">
        Archive
      </h1>

      <div class="relative">
        <%= for {entity, index} <- Enum.with_index(@entities) do %>
          <article class="relative pb-12">
            <!-- Timeline connector (not for last item) -->
            <%= if index < length(@entities) - 1 do %>
              <div class="absolute left-0 top-full h-12 w-px border-l-2 border-dashed border-base-300 opacity-40"></div>
            <% end %>

            <div class="flex items-center gap-3 text-sm opacity-60 mb-4">
              <span class="lowercase tracking-wide"><%= entity.entity_type %></span>
              <span>·</span>
              <time><%= Calendar.strftime(entity.published_at, "%d %b %Y") %></time>
            </div>

            <h2 class="text-2xl font-normal mb-3 averia">
              <a href={"#{entity.source_path}/#{entity.slug}"} class="hover:opacity-70 transition-opacity">
                <%= entity.title %>
              </a>
              <%= if entity.url do %>
                <a href={entity.url} target="_blank" rel="noopener noreferrer" class="text-base opacity-60 hover:opacity-100 ml-2">
                  →
                </a>
              <% end %>
            </h2>

            <%= if entity.content do %>
              <p class="opacity-80 leading-relaxed mb-4"><%= entity.content %></p>
            <% end %>

            <%= if entity.tags && length(entity.tags) > 0 do %>
              <div class="flex flex-wrap gap-3 text-sm opacity-60">
                <%= for tag <- entity.tags do %>
                  <span>#<%= tag %></span>
                <% end %>
              </div>
            <% end %>
          </article>
        <% end %>
      </div>
    </div>
    """
  end
end
