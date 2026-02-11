defmodule WeaktyWeb.TimelineLive.Index do
  use WeaktyWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    entities = Weakty.Content.Entity.list_entities!()
    {:ok, assign(socket, entities: entities)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto px-6 py-16">
      <h1 class="text-4xl font-normal mb-16 text-center uppercase tracking-wide averia">
        Archive
      </h1>

      <div class="space-y-12">
        <%= for entity <- @entities do %>
          <article class="border-b border-base-300 pb-12 last:border-b-0">
            <div class="flex items-center justify-center gap-3 text-sm opacity-60 mb-4">
              <span class="lowercase tracking-wide"><%= entity.entity_type %></span>
              <span>·</span>
              <time><%= Calendar.strftime(entity.published_at, "%d %b %Y") %></time>
            </div>

            <h2 class="text-2xl font-normal mb-3 text-center averia">
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
              <p class="opacity-80 leading-relaxed mb-4 max-w-xl mx-auto text-center"><%= entity.content %></p>
            <% end %>

            <%= if entity.tags && length(entity.tags) > 0 do %>
              <div class="flex flex-wrap gap-3 justify-center text-sm opacity-60">
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
