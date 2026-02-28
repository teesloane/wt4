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
     |> assign(:search, "")
     |> assign(:sort_by, "published_at")
     |> assign(:sort_dir, "desc")
     |> load_entities(), layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def handle_event("filter", %{"type" => type}, socket) do
    {:noreply, socket |> assign(:filter_type, type) |> load_entities()}
  end

  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, socket |> assign(:search, q) |> load_entities()}
  end

  def handle_event("sort", %{"col" => col}, socket) do
    {sort_by, sort_dir} =
      if socket.assigns.sort_by == col do
        {col, if(socket.assigns.sort_dir == "asc", do: "desc", else: "asc")}
      else
        {col, "asc"}
      end

    {:noreply, socket |> assign(:sort_by, sort_by) |> assign(:sort_dir, sort_dir) |> load_entities()}
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
      <div class="mb-6">
        <form phx-change="search" class="max-w-sm">
          <input
            type="text"
            name="q"
            value={@search}
            placeholder="Search by title..."
            phx-debounce="200"
            class="input input-bordered input-sm w-full"
          />
        </form>
      </div>

      <%= if @entities == [] do %>
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body items-center text-center">
            <.icon name="hero-square-3-stack-3d" class="w-16 h-16 text-base-content/30" />
            <h2 class="card-title">No results</h2>
            <p class="text-base-content/70">Entities are created automatically when you publish content</p>
          </div>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="table table-zebra">
            <thead>
              <tr>
                <.sort_th col="entity_type" label="Type" sort_by={@sort_by} sort_dir={@sort_dir} />
                <.sort_th col="title" label="Title" sort_by={@sort_by} sort_dir={@sort_dir} />
                <th>Tags</th>
                <.sort_th col="public" label="Public" sort_by={@sort_by} sort_dir={@sort_dir} />
                <.sort_th col="published_at" label="Published" sort_by={@sort_by} sort_dir={@sort_dir} />
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for entity <- @entities do %>
                <tr class="hover">
                  <td>
                    <span class={"badge badge-sm"}>
                      <%= entity.subtype || entity.entity_type %>
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
                          <span class="badge badge-sm"><%= tag.name %></span>
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
                  <td>
                    <.link navigate={edit_path_for_entity(entity)} class="btn btn-ghost btn-xs">
                      <.icon name="hero-pencil" class="w-4 h-4" />
                      Edit
                    </.link>
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

  defp sort_th(assigns) do
    ~H"""
    <th
      class="cursor-pointer select-none hover:bg-base-300 whitespace-nowrap"
      phx-click="sort"
      phx-value-col={@col}
    >
      <%= @label %>
      <%= if @sort_by == @col do %>
        <span class="text-primary ml-1"><%= if @sort_dir == "asc", do: "↑", else: "↓" %></span>
      <% end %>
    </th>
    """
  end

  defp load_entities(socket) do
    type = socket.assigns[:filter_type] || "all"
    search = socket.assigns[:search] || ""
    sort_by = socket.assigns[:sort_by] || "published_at"
    sort_dir = socket.assigns[:sort_dir] || "desc"

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
      |> Ash.load!([:tags], domain: Weakty.Content)
      |> filter_by_search(search)
      |> sort_results(sort_by, sort_dir)

    assign(socket, :entities, entities)
  end

  defp filter_by_search(list, ""), do: list
  defp filter_by_search(list, q) do
    q = String.downcase(q)
    Enum.filter(list, fn e ->
      String.contains?(String.downcase(e.title || e.slug || ""), q)
    end)
  end

  defp sort_results(list, sort_by, sort_dir) do
    sorted =
      Enum.sort_by(list, fn e ->
        case sort_by do
          "entity_type"  -> to_string(e.entity_type)
          "title"        -> String.downcase(e.title || e.slug || "")
          "public"       -> if(e.public, do: 1, else: 0)
          _              ->
            if e.published_at, do: DateTime.to_unix(e.published_at, :microsecond), else: 0
        end
      end)

    if sort_dir == "desc", do: Enum.reverse(sorted), else: sorted
  end


  defp edit_path_for_entity(entity) do
    case {entity.entity_type, entity.subtype} do
      {:post, "til"} -> "/admin/til/#{entity.source_id}/edit"
      {:post, "quote"} -> "/admin/quotes/#{entity.source_id}/edit"
      {:post, _} -> "/admin/posts/#{entity.source_id}/edit"
      {:project, _} -> "/admin/projects/#{entity.source_id}/edit"
      {:link, _} -> "/admin/links/#{entity.source_id}/edit"
      {:media_log, _} -> "/admin/media-logs/#{entity.source_id}/edit"
      _ -> "#"
    end
  end
end
