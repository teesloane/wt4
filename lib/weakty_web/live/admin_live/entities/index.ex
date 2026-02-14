defmodule WeaktyWeb.AdminLive.Entities.Index do
  use WeaktyWeb, :live_view

  import WeaktyWeb.AdminComponents

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Entities")
     |> assign(:current_path, "/admin/entities")
     |> assign(:filter_type, "all")
     |> load_entities(), layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def handle_event("filter", %{"type" => type}, socket) do
    {:noreply,
     socket
     |> assign(:filter_type, type)
     |> load_entities(type)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_header
      title="Entities"
      subtitle={"#{length(@entities)} entr#{if length(@entities) != 1, do: "ies", else: "y"}"}
    >
      <:actions>
        <div class="join">
          <%= for {label, type} <- [{"All", "all"}, {"Posts", "post"}, {"Links", "link"}, {"Projects", "project"}, {"Media", "media_log"}] do %>
            <button
              phx-click="filter"
              phx-value-type={type}
              class={"btn btn-sm join-item #{if @filter_type == type, do: "btn-active", else: "btn-ghost"}"}
            >
              <%= label %>
            </button>
          <% end %>
        </div>
      </:actions>
    </.admin_header>

    <div class="p-8">
      <%= if @entities == [] do %>
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body items-center text-center">
            <.icon name="hero-square-3-stack-3d" class="w-16 h-16 text-base-content/30" />
            <h2 class="card-title">No entities</h2>
            <p class="text-base-content/70">Entities are created automatically when you publish content</p>
          </div>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Type</th>
                <th>Title</th>
                <th>Tags</th>
                <th>Public</th>
                <th>Published</th>
              </tr>
            </thead>
            <tbody>
              <%= for entity <- @entities do %>
                <tr class="hover">
                  <td>
                    <span class={"badge badge-sm #{type_badge_class(entity.entity_type)}"}>
                      <%= entity.entity_type %>
                    </span>
                  </td>
                  <td>
                    <div class="font-medium">
                      <a
                        href={"#{entity.source_path}/#{entity.slug}"}
                        class="hover:underline"
                        target="_blank"
                      >
                        <%= entity.title || entity.slug %>
                      </a>
                    </div>
                    <%= if entity.content do %>
                      <div class="text-sm text-base-content/60 max-w-sm truncate">
                        <%= entity.content %>
                      </div>
                    <% end %>
                  </td>
                  <td>
                    <%= if entity.tags && entity.tags != [] do %>
                      <div class="flex gap-1 flex-wrap">
                        <%= for tag <- Enum.take(entity.tags, 3) do %>
                          <span class="badge badge-sm"><%= tag %></span>
                        <% end %>
                        <%= if length(entity.tags) > 3 do %>
                          <span class="badge badge-sm badge-ghost">+<%= length(entity.tags) - 3 %></span>
                        <% end %>
                      </div>
                    <% else %>
                      <span class="text-base-content/40">—</span>
                    <% end %>
                  </td>
                  <td>
                    <%= if entity.public do %>
                      <span class="badge badge-success badge-sm">public</span>
                    <% else %>
                      <span class="badge badge-ghost badge-sm">private</span>
                    <% end %>
                  </td>
                  <td>
                    <%= if entity.published_at do %>
                      <div class="text-sm"><%= Calendar.strftime(entity.published_at, "%b %d, %Y") %></div>
                    <% else %>
                      <span class="text-base-content/40">—</span>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  defp load_entities(socket, type \\ nil) do
    type = type || socket.assigns[:filter_type] || "all"

    entities =
      Weakty.Content.Entity
      |> then(fn query ->
        if type == "all" do
          query
        else
          require Ash.Query
          Ash.Query.filter(query, entity_type == ^type)
        end
      end)
      |> Ash.Query.sort(published_at: :desc)
      |> Ash.read!(domain: Weakty.Content)

    assign(socket, :entities, entities)
  end

  defp type_badge_class(type) do
    case to_string(type) do
      "post" -> "badge-primary"
      "link" -> "badge-secondary"
      "project" -> "badge-accent"
      "media_log" -> "badge-info"
      _ -> "badge-ghost"
    end
  end
end
