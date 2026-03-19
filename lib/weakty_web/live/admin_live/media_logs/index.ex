defmodule WeaktyWeb.AdminLive.MediaLogs.Index do
  use WeaktyWeb, :live_view

  import WeaktyWeb.AdminComponents

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  require Ash.Query

  @per_page 25

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Media Logs")
     |> assign(:current_path, "/admin/media-logs")
     |> assign(:media_type_filter, "all")
     |> assign(:status_filter, "all")
     |> assign(:search, "")
     |> assign(:sort_by, "date")
     |> assign(:sort_dir, "desc")
     |> assign(:page, 1)
     |> assign(:total_count, 0)
     |> assign(:total_pages, 1)
     |> assign(:media_logs, []), layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      socket
      |> assign(:media_type_filter, Map.get(params, "type", "all"))
      |> assign(:status_filter, Map.get(params, "status", "all"))
      |> assign(:search, Map.get(params, "q", ""))
      |> assign(:sort_by, Map.get(params, "sort", "date"))
      |> assign(:sort_dir, Map.get(params, "dir", "desc"))
      |> assign(:page, parse_page(params["page"]))
      |> load_media_logs()

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    require Logger

    media_log = Ash.get!(Weakty.MediaLogs.MediaLog, id, authorize?: false)

    case Ash.destroy(media_log, authorize?: false) do
      :ok ->
        {:noreply, socket |> put_flash(:info, "Deleted.") |> load_media_logs()}

      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Deleted.") |> load_media_logs()}

      {:error, reason} ->
        Logger.error("MediaLog delete failed: #{inspect(reason)}")
        {:noreply, put_flash(socket, :error, "Failed to delete")}
    end
  end

  def handle_event("filter_media_type", %{"media_type" => media_type}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, %{type: media_type, page: 1}))}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, %{status: status, page: 1}))}
  end

  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, %{q: q, page: 1}))}
  end

  def handle_event("sort", %{"col" => col}, socket) do
    dir =
      if socket.assigns.sort_by == col do
        if socket.assigns.sort_dir == "asc", do: "desc", else: "asc"
      else
        "asc"
      end

    {:noreply, push_patch(socket, to: build_path(socket, %{sort: col, dir: dir, page: 1}))}
  end

  def handle_event("page", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, %{page: page}))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_header
      title="Media Logs"
      subtitle={"#{@total_count} media log#{if @total_count != 1, do: "s"}"}
    >
      <:actions>
        <.link navigate="/admin/media-logs/new" class="btn btn-primary">
          <.icon name="hero-plus" class="w-4 h-4" /> New Media Log
        </.link>
      </:actions>
    </.admin_header>

    <div class="p-8">
      <div class="mb-6 flex flex-wrap gap-3 items-end">
        <form phx-change="search" class="flex-1 min-w-48 max-w-sm">
          <input
            type="text"
            value={@search}
            name="q"
            placeholder="Search title or creator..."
            phx-debounce="200"
            class="input input-bordered input-sm w-full"
          />
        </form>

        <form class="flex gap-3">
          <select
            phx-change="filter_media_type"
            name="media_type"
            class="select select-bordered select-sm w-44"
          >
            <option value="all" selected={@media_type_filter == "all"}>All Types</option>
            <option value="book" selected={@media_type_filter == "book"}>Books</option>
            <option value="comic" selected={@media_type_filter == "comic"}>Comics</option>
            <option value="movie" selected={@media_type_filter == "movie"}>Movies</option>
            <option value="music" selected={@media_type_filter == "music"}>Music</option>
            <option value="video_game" selected={@media_type_filter == "video_game"}>Games</option>
          </select>

          <select
            phx-change="filter_status"
            name="status"
            class="select select-bordered select-sm w-44"
          >
            <option value="all" selected={@status_filter == "all"}>All Status</option>
            <option value="consuming" selected={@status_filter == "consuming"}>In Progress</option>
            <option value="consumed" selected={@status_filter == "consumed"}>Done</option>
            <option value="want_to_consume" selected={@status_filter == "want_to_consume"}>
              Want to
            </option>
            <option value="on_hold" selected={@status_filter == "on_hold"}>On Hold</option>
            <option value="abandoned" selected={@status_filter == "abandoned"}>Abandoned</option>
          </select>
        </form>
      </div>

      <%= if @media_logs == [] do %>
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body items-center text-center">
            <.icon name="hero-book-open" class="w-16 h-16 text-base-content/30" />
            <h2 class="card-title">No results</h2>
            <p class="text-base-content/70">Try adjusting your search or filters</p>
          </div>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="table table-zebra">
            <thead>
              <tr>
                <.sort_th col="title" label="Title" sort_by={@sort_by} sort_dir={@sort_dir} />
                <.sort_th col="creator" label="Creator" sort_by={@sort_by} sort_dir={@sort_dir} />
                <.sort_th col="rating" label="Rating" sort_by={@sort_by} sort_dir={@sort_dir} />
                <.sort_th col="date" label="Date" sort_by={@sort_by} sort_dir={@sort_dir} />
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for media_log <- @media_logs do %>
                <tr class="hover">
                  <td>
                    <div class="flex items-center gap-3">
                      <%= if media_log.thumbnail_url do %>
                        <div class="avatar">
                          <div class="mask mask-squircle w-12 h-12">
                            <img src={media_log.thumbnail_url} alt={media_log.title} />
                          </div>
                        </div>
                      <% end %>
                      <div>
                        <div class="font-bold">{media_log.title}</div>
                        <%= if media_log.favourite do %>
                          <span class="text-warning">★</span>
                        <% end %>
                        <%= if media_log.tags && media_log.tags != [] do %>
                          <div class="text-sm opacity-50 flex gap-1 mt-1">
                            <%= for tag <- Enum.take(media_log.tags, 3) do %>
                              <span class="badge badge-xs">{tag.name}</span>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </td>
                  <td>
                    {media_log.creator || raw("<span class='text-base-content/50'>—</span>")}
                  </td>
                  <td>
                    <%= if media_log.rating do %>
                      <div class="text-warning">{String.duplicate("★", media_log.rating)}</div>
                    <% else %>
                      <span class="text-base-content/50">—</span>
                    <% end %>
                  </td>
                  <td>
                    <div class="text-sm">
                      <%= cond do %>
                        <% media_log.date_finished -> %>
                          {Calendar.strftime(media_log.date_finished, "%b %d, %Y")}
                        <% media_log.date_consumed -> %>
                          {Calendar.strftime(media_log.date_consumed, "%b %d, %Y")}
                        <% media_log.date_started -> %>
                          Started {Calendar.strftime(media_log.date_started, "%b %d")}
                        <% true -> %>
                          <span class="text-base-content/50">—</span>
                      <% end %>
                    </div>
                  </td>
                  <td>
                    <div class="flex gap-2">
                      <.link
                        navigate={~p"/admin/media-logs/#{media_log.id}/edit"}
                        class="btn btn-ghost btn-xs"
                        title="Edit"
                      >
                        <.icon name="hero-pencil" class="w-4 h-4" />
                      </.link>
                      <button
                        phx-click="delete"
                        phx-value-id={media_log.id}
                        phx-confirm="Delete this media log?"
                        class="btn btn-ghost btn-xs text-error"
                        title="Delete"
                      >
                        <.icon name="hero-trash" class="w-4 h-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%= if @total_pages > 1 do %>
          <div class="flex justify-center mt-6">
            <div class="join">
              <button
                class="join-item btn btn-sm"
                phx-click="page"
                phx-value-page={@page - 1}
                disabled={@page <= 1}
              >
                «
              </button>
              <%= for p <- page_range(@page, @total_pages) do %>
                <%= if p == :gap do %>
                  <button class="join-item btn btn-sm btn-disabled">…</button>
                <% else %>
                  <button
                    class={"join-item btn btn-sm #{if p == @page, do: "btn-active"}"}
                    phx-click="page"
                    phx-value-page={p}
                  >
                    {p}
                  </button>
                <% end %>
              <% end %>
              <button
                class="join-item btn btn-sm"
                phx-click="page"
                phx-value-page={@page + 1}
                disabled={@page >= @total_pages}
              >
                »
              </button>
            </div>
          </div>
          <p class="text-center text-sm text-base-content/50 mt-2">
            Page {@page} of {@total_pages} · {@total_count} total
          </p>
        <% end %>
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
      {@label}
      <%= if @sort_by == @col do %>
        <span class="text-primary ml-1">{if @sort_dir == "asc", do: "↑", else: "↓"}</span>
      <% end %>
    </th>
    """
  end

  defp load_media_logs(socket) do
    media_type_filter = socket.assigns.media_type_filter
    status_filter = socket.assigns.status_filter
    search = socket.assigns[:search] || ""
    sort_by = socket.assigns[:sort_by] || "date"
    sort_dir = socket.assigns[:sort_dir] || "desc"
    page = socket.assigns[:page] || 1

    sort_order = if sort_dir == "desc", do: :desc, else: :asc

    sort =
      case sort_by do
        "title" -> [title: sort_order]
        "creator" -> [creator: sort_order]
        "rating" -> [rating: sort_order]
        "date" -> [sort_date: sort_order]
        _ -> [updated_at: sort_order]
      end

    query =
      Weakty.MediaLogs.MediaLog
      |> Ash.Query.for_read(:list_admin)
      |> filter_media_type(media_type_filter)
      |> filter_status(status_filter)
      |> filter_search(search)
      |> Ash.Query.sort(sort)
      |> Ash.Query.load(:tags)

    result =
      Ash.read!(query,
        authorize?: false,
        page: [limit: @per_page, offset: (page - 1) * @per_page, count: true]
      )

    total_count = result.count || 0
    total_pages = max(1, ceil(total_count / @per_page))

    socket
    |> assign(:media_logs, result.results)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
  end

  defp filter_media_type(query, "all"), do: query

  defp filter_media_type(query, type_str) do
    type_atom = String.to_existing_atom(type_str)
    Ash.Query.filter(query, media_type == ^type_atom)
  end

  defp filter_status(query, "all"), do: query

  defp filter_status(query, status_str) do
    status_atom = String.to_existing_atom(status_str)
    Ash.Query.filter(query, status == ^status_atom)
  end

  defp filter_search(query, ""), do: query

  defp filter_search(query, search_str) do
    lower = String.downcase(search_str)

    Ash.Query.filter(
      query,
      contains(string_downcase(title), ^lower) or contains(string_downcase(creator), ^lower)
    )
  end

  defp build_path(socket, overrides) do
    params = %{
      "type" => socket.assigns.media_type_filter,
      "status" => socket.assigns.status_filter,
      "q" => socket.assigns.search,
      "sort" => socket.assigns.sort_by,
      "dir" => socket.assigns.sort_dir,
      "page" => socket.assigns.page
    }

    merged =
      params
      |> Map.merge(Map.new(overrides, fn {k, v} -> {to_string(k), to_string(v)} end))
      |> Enum.reject(fn
        {"type", "all"} -> true
        {"status", "all"} -> true
        {"q", ""} -> true
        {"sort", "date"} -> true
        {"dir", "desc"} -> true
        {"page", "1"} -> true
        _ -> false
      end)
      |> Map.new()

    ~p"/admin/media-logs?#{merged}"
  end

  defp parse_page(nil), do: 1
  defp parse_page(p) when is_integer(p), do: max(1, p)

  defp parse_page(p) when is_binary(p) do
    case Integer.parse(p) do
      {n, _} -> max(1, n)
      :error -> 1
    end
  end

  defp page_range(_current, total) when total <= 7 do
    1..total
  end

  defp page_range(current, total) do
    cond do
      current <= 4 -> Enum.to_list(1..5) ++ [:gap, total]
      current >= total - 3 -> [1, :gap] ++ Enum.to_list((total - 4)..total)
      true -> [1, :gap] ++ Enum.to_list((current - 1)..(current + 1)) ++ [:gap, total]
    end
  end
end
