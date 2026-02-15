defmodule WeaktyWeb.AdminLive.MediaLogs.Index do
  use WeaktyWeb, :live_view

  import WeaktyWeb.AdminComponents

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Media Logs")
     |> assign(:current_path, "/admin/media-logs")
     |> assign(:media_type_filter, "all")
     |> assign(:status_filter, "all")
     |> assign(:search, "")
     |> assign(:sort_by, "updated_at")
     |> assign(:sort_dir, "desc")
     |> load_media_logs(), layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply,
     socket
     |> assign(:media_type_filter, Map.get(params, "type", "all"))
     |> assign(:status_filter, Map.get(params, "status", "all"))
     |> load_media_logs()}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    media_log = Ash.get!(Weakty.MediaLogs.MediaLog, id)

    case Weakty.MediaLogs.MediaLog.delete_media_log(media_log) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Deleted.") |> load_media_logs()}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete media log")}
    end
  end

  def handle_event("filter_media_type", %{"media_type" => media_type}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/admin/media-logs?type=#{media_type}&status=#{socket.assigns.status_filter}"
     )}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/admin/media-logs?type=#{socket.assigns.media_type_filter}&status=#{status}"
     )}
  end

  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, socket |> assign(:search, q) |> load_media_logs()}
  end

  def handle_event("sort", %{"col" => col}, socket) do
    {sort_by, sort_dir} =
      if socket.assigns.sort_by == col do
        {col, if(socket.assigns.sort_dir == "asc", do: "desc", else: "asc")}
      else
        {col, "asc"}
      end

    {:noreply, socket |> assign(:sort_by, sort_by) |> assign(:sort_dir, sort_dir) |> load_media_logs()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_header
      title="Media Logs"
      subtitle={"#{length(@media_logs)} media log#{if length(@media_logs) != 1, do: "s"}"}
    >
      <:actions>
        <.link navigate="/admin/media-logs/new" class="btn btn-primary">
          <.icon name="hero-plus" class="w-4 h-4" />
          New Media Log
        </.link>
      </:actions>
    </.admin_header>

    <div class="p-8">
      <div class="mb-6 flex flex-wrap gap-3 items-end">
        <form phx-change="search" class="flex-1 min-w-48 max-w-sm">
          <input
            type="text"
            value={@search}
            placeholder="Search title or creator..."
            phx-debounce="200"
            class="input input-bordered input-sm w-full"
          />
        </form>

        <form class="flex gap-3">
          <select phx-change="filter_media_type" name="media_type" class="select select-bordered select-sm w-44">
            <option value="all" selected={@media_type_filter == "all"}>All Types</option>
            <option value="book" selected={@media_type_filter == "book"}>Books</option>
            <option value="comic" selected={@media_type_filter == "comic"}>Comics</option>
            <option value="movie" selected={@media_type_filter == "movie"}>Movies</option>
            <option value="music" selected={@media_type_filter == "music"}>Music</option>
            <option value="video_game" selected={@media_type_filter == "video_game"}>Games</option>
          </select>

          <select phx-change="filter_status" name="status" class="select select-bordered select-sm w-44">
            <option value="all" selected={@status_filter == "all"}>All Status</option>
            <option value="consuming" selected={@status_filter == "consuming"}>In Progress</option>
            <option value="consumed" selected={@status_filter == "consumed"}>Done</option>
            <option value="want_to_consume" selected={@status_filter == "want_to_consume"}>Want to</option>
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
                <.sort_th col="media_type" label="Type" sort_by={@sort_by} sort_dir={@sort_dir} />
                <.sort_th col="status" label="Status" sort_by={@sort_by} sort_dir={@sort_dir} />
                <.sort_th col="rating" label="Rating" sort_by={@sort_by} sort_dir={@sort_dir} />
                <.sort_th col="date" label="Date" sort_by={@sort_by} sort_dir={@sort_dir} />
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for media_log <- @media_logs do %>
                <tr
                  class="hover cursor-pointer"
                  phx-click={JS.navigate(~p"/admin/media-logs/#{media_log.id}/edit")}
                >
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
                        <div class="font-bold"><%= media_log.title %></div>
                        <%= if media_log.favourite do %>
                          <span class="text-warning">★</span>
                        <% end %>
                        <%= if media_log.tags && media_log.tags != [] do %>
                          <div class="text-sm opacity-50 flex gap-1 mt-1">
                            <%= for tag <- Enum.take(media_log.tags, 3) do %>
                              <span class="badge badge-xs"><%= tag.name %></span>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </td>
                  <td>
                    <%= media_log.creator || raw("<span class='text-base-content/50'>—</span>") %>
                  </td>
                  <td><.media_type_badge media_type={media_log.media_type} /></td>
                  <td><.media_status_badge status={media_log.status} /></td>
                  <td>
                    <%= if media_log.rating do %>
                      <div class="text-warning"><%= String.duplicate("★", media_log.rating) %></div>
                    <% else %>
                      <span class="text-base-content/50">—</span>
                    <% end %>
                  </td>
                  <td>
                    <div class="text-sm">
                      <%= cond do %>
                        <% media_log.date_finished -> %>
                          <%= Calendar.strftime(media_log.date_finished, "%b %d, %Y") %>
                        <% media_log.date_consumed -> %>
                          <%= Calendar.strftime(media_log.date_consumed, "%b %d, %Y") %>
                        <% media_log.date_started -> %>
                          Started <%= Calendar.strftime(media_log.date_started, "%b %d") %>
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
                      <.link
                        navigate={~p"/media-logs/#{media_log.slug}"}
                        class="btn btn-ghost btn-xs"
                        title="View"
                      >
                        <.icon name="hero-eye" class="w-4 h-4" />
                      </.link>
                      <button
                        phx-click="delete"
                        phx-value-id={media_log.id}
                        data-confirm="Delete this media log?"
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

  defp load_media_logs(socket) do
    media_type_filter = socket.assigns.media_type_filter
    status_filter = socket.assigns.status_filter
    search = socket.assigns[:search] || ""
    sort_by = socket.assigns[:sort_by] || "updated_at"
    sort_dir = socket.assigns[:sort_dir] || "desc"

    media_logs =
      case {media_type_filter, status_filter} do
        {"all", "all"} ->
          Weakty.MediaLogs.MediaLog.list_media_logs!()
        {"all", status} ->
          Weakty.MediaLogs.MediaLog.list_by_status!(String.to_existing_atom(status))
        {media_type, "all"} ->
          Weakty.MediaLogs.MediaLog.list_by_media_type!(String.to_existing_atom(media_type))
        {media_type, status} ->
          Weakty.MediaLogs.MediaLog.list_media_logs!()
          |> Enum.filter(fn ml ->
            ml.media_type == String.to_existing_atom(media_type) &&
              ml.status == String.to_existing_atom(status)
          end)
      end
      |> Ash.load!(:tags)
      |> filter_by_search(search)
      |> sort_results(sort_by, sort_dir)

    assign(socket, :media_logs, media_logs)
  end

  defp filter_by_search(list, ""), do: list
  defp filter_by_search(list, q) do
    q = String.downcase(q)
    Enum.filter(list, fn ml ->
      String.contains?(String.downcase(ml.title || ""), q) ||
        String.contains?(String.downcase(ml.creator || ""), q)
    end)
  end

  defp sort_results(list, sort_by, sort_dir) do
    sorted =
      Enum.sort_by(list, fn ml ->
        case sort_by do
          "title"      -> String.downcase(ml.title || "")
          "creator"    -> String.downcase(ml.creator || "")
          "media_type" -> to_string(ml.media_type)
          "status"     -> to_string(ml.status)
          "rating"     -> ml.rating || 0
          "date"       -> ml.date_finished || ml.date_consumed || ml.date_started || ~D[0001-01-01]
          _            -> ml.updated_at
        end
      end)

    if sort_dir == "desc", do: Enum.reverse(sorted), else: sorted
  end

  defp media_type_badge(assigns) do
    ~H"""
    <span class={"badge badge-sm #{media_type_color(@media_type)}"}>
      <%= format_media_type(@media_type) %>
    </span>
    """
  end

  defp media_status_badge(assigns) do
    ~H"""
    <span class={"badge badge-sm #{status_color(@status)}"}>
      <%= format_status(@status) %>
    </span>
    """
  end

  defp media_type_color(t) do
    case t do
      :book -> "badge-info"; :comic -> "badge-accent"; :movie -> "badge-secondary"
      :music -> "badge-primary"; :video_game -> "badge-success"; _ -> "badge-ghost"
    end
  end

  defp status_color(s) do
    case s do
      :consuming -> "badge-warning"; :consumed -> "badge-success"
      :want_to_consume -> "badge-info"; :on_hold -> "badge-ghost"
      :abandoned -> "badge-error"; _ -> "badge-ghost"
    end
  end

  defp format_media_type(t) do
    case t do
      :book -> "Book"; :comic -> "Comic"; :movie -> "Movie"
      :music -> "Music"; :video_game -> "Game"; _ -> to_string(t)
    end
  end

  defp format_status(s) do
    case s do
      :want_to_consume -> "Want"; :consuming -> "In Progress"; :consumed -> "Done"
      :on_hold -> "On Hold"; :abandoned -> "Abandoned"; _ -> to_string(s)
    end
  end
end
