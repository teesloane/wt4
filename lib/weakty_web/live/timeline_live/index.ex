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
    <div class="mx-auto max-w-4xl px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">Archive</h1>

      <div class="space-y-4">
        <%= for entity <- @entities do %>
          <div class="card bg-base-200 shadow-sm">
            <div class="card-body">
              <div class="flex items-center gap-2 text-sm opacity-60">
                <span class="badge badge-outline"><%= entity.entity_type %></span>
                <time><%= Calendar.strftime(entity.published_at, "%B %d, %Y") %></time>
              </div>

              <h2 class="card-title">
                <a href={"#{entity.source_path}/#{entity.slug}"} class="link">
                  <%= entity.title %>
                </a>
                <%= if entity.url do %>
                  <a href={entity.url} target="_blank" class="text-sm opacity-60 link">
                    (external)
                  </a>
                <% end %>
              </h2>

              <%= if entity.content do %>
                  <p class="text-base-content/70"><%= entity.content %></p>
              <% end %>

              <%= if entity.tags && length(entity.tags) > 0 do %>
                <div class="flex flex-wrap gap-2 mt-2">
                  <%= for tag <- entity.tags do %>
                    <span class="badge badge-sm badge-ghost"><%= tag %></span>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
