defmodule WeaktyWeb.AreaLive.Index do
  use WeaktyWeb, :live_view

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    require Ash.Query

    areas =
      Weakty.Tags.Tag
      |> Ash.Query.filter(public == true)
      |> Ash.read!()
      |> Ash.load!([:links, :posts, :media_logs, :projects], domain: Weakty.Tags)
      |> Enum.sort_by(& &1.name)

    {:ok,
     socket
     |> assign(:page_title, "Areas")
     |> assign(:areas, areas)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container title="Areas of Interest">

      <%= if @areas == [] do %>
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body items-center text-center">
            <p class="text-base-content/70">No public areas yet</p>
          </div>
        </div>
      <% else %>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
          <%= for area <- @areas do %>
            <.link navigate={~p"/areas/#{area.slug}"} class="card bg-base-100 border border-base-300 hover:shadow-sm rounded-none transition-shadow">
              <%= if area.featured_image do %>
                <figure class="aspect-video">
                  <img src={area.featured_image} alt={area.name} class="w-full h-full object-cover" />
                </figure>
              <% end %>
              <div class="card-body">
                <h2 class="card-title"><%= area.name %></h2>
                <%= if area.description do %>
                  <p class="text-base-content/70 line-clamp-3">
                    <%= String.slice(area.description, 0..150) %><%= if String.length(area.description) > 150, do: "..." %>
                  </p>
                <% end %>
                <div class="card-actions justify-end mt-4">
                  <div class="text-sm text-base-content/60">
                    <%= length(area.posts) + length(area.links) + length(area.media_logs) + length(area.projects) %> items
                  </div>
                </div>
              </div>
            </.link>
          <% end %>
        </div>
      <% end %>
    </.page_container>
    """
  end
end
