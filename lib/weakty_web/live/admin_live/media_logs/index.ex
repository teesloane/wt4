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
     |> load_media_logs(), layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    media_type_filter = Map.get(params, "type", "all")
    status_filter = Map.get(params, "status", "all")

    {:noreply,
     socket
     |> assign(:media_type_filter, media_type_filter)
     |> assign(:status_filter, status_filter)
     |> load_media_logs()}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    media_log = Ash.get!(Weakty.MediaLogs.MediaLog, id)

    case Weakty.MediaLogs.MediaLog.delete_media_log(media_log) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Media log deleted successfully")
         |> load_media_logs()}

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

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_header title="Media Logs" subtitle={"#{length(@media_logs)} media log#{if length(@media_logs) != 1, do: "s"}"}>
      <:actions>
        <.link navigate="/admin/media-logs/new" class="btn btn-primary">
          <.icon name="hero-plus" class="w-4 h-4" />
          New Media Log
        </.link>
      </:actions>
    </.admin_header>

    <div class="p-8">
    <form>
      <!-- Filters -->
      <div class="mb-6 flex gap-3">
        <select
          phx-change="filter_media_type"
          name="media_type"
          class="select select-bordered select-sm w-48"
        >
          <option value="all" selected={@media_type_filter == "all"}>All Media Types</option>
          <option value="book" selected={@media_type_filter == "book"}>Books</option>
          <option value="comic" selected={@media_type_filter == "comic"}>Comics</option>
          <option value="movie" selected={@media_type_filter == "movie"}>Movies</option>
          <option value="music" selected={@media_type_filter == "music"}>Music</option>
          <option value="video_game" selected={@media_type_filter == "video_game"}>Games</option>
        </select>

        <select
          phx-change="filter_status"
          name="status"
          class="select select-bordered select-sm w-48"
        >
          <option value="all" selected={@status_filter == "all"}>All Status</option>
          <option value="consuming" selected={@status_filter == "consuming"}>Currently Consuming</option>
          <option value="consumed" selected={@status_filter == "consumed"}>Consumed</option>
          <option value="want_to_consume" selected={@status_filter == "want_to_consume"}>Want to Consume</option>
        </select>
      </div>
      </form>

      <%= if @media_logs == [] do %>
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body items-center text-center">
            <.icon name="hero-book-open" class="w-16 h-16 text-base-content/30" />
            <h2 class="card-title">No media logs yet</h2>
            <p class="text-base-content/70">Track your books, movies, music, and more</p>
            <.link navigate="/admin/media-logs/new" class="btn btn-primary mt-4">
              <.icon name="hero-plus" class="w-4 h-4" />
              Create Media Log
            </.link>
          </div>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Title</th>
                <th>Creator</th>
                <th>Type</th>
                <th>Status</th>
                <th>Rating</th>
                <th>Date</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for media_log <- @media_logs do %>
                <tr class="hover cursor-pointer" phx-click={JS.navigate(~p"/admin/media-logs/#{media_log.id}/edit")}>
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
                    <%= if media_log.creator do %>
                      <div class="text-sm"><%= media_log.creator %></div>
                    <% else %>
                      <span class="text-base-content/50">-</span>
                    <% end %>
                  </td>
                  <td>
                    <.media_type_badge media_type={media_log.media_type} />
                  </td>
                  <td>
                    <.media_status_badge status={media_log.status} />
                  </td>
                  <td>
                    <%= if media_log.rating do %>
                      <div class="text-warning">
                        <%= String.duplicate("★", media_log.rating) %>
                      </div>
                    <% else %>
                      <span class="text-base-content/50">-</span>
                    <% end %>
                  </td>
                  <td>
                    <%= cond do %>
                      <% media_log.date_finished -> %>
                        <div class="text-sm">
                          <%= Calendar.strftime(media_log.date_finished, "%b %d, %Y") %>
                        </div>
                      <% media_log.date_consumed -> %>
                        <div class="text-sm">
                          <%= Calendar.strftime(media_log.date_consumed, "%b %d, %Y") %>
                        </div>
                      <% media_log.date_started -> %>
                        <div class="text-sm">
                          Started <%= Calendar.strftime(media_log.date_started, "%b %d") %>
                        </div>
                      <% true -> %>
                        <span class="text-base-content/50">-</span>
                    <% end %>
                  </td>
                  <td onclick="event.stopPropagation()">
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
                        data-confirm="Are you sure you want to delete this media log?"
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

  defp load_media_logs(socket) do
    media_logs =
      case {socket.assigns.media_type_filter, socket.assigns.status_filter} do
        {"all", "all"} ->
          Weakty.MediaLogs.MediaLog.list_media_logs!()

        {"all", status} ->
          status_atom = String.to_existing_atom(status)
          Weakty.MediaLogs.MediaLog.list_by_status!(status_atom)

        {media_type, "all"} ->
          media_type_atom = String.to_existing_atom(media_type)
          Weakty.MediaLogs.MediaLog.list_by_media_type!(media_type_atom)

        {media_type, status} ->
          media_type_atom = String.to_existing_atom(media_type)
          status_atom = String.to_existing_atom(status)

          Weakty.MediaLogs.MediaLog.list_media_logs!()
          |> Enum.filter(fn ml ->
            ml.media_type == media_type_atom && ml.status == status_atom
          end)
      end

    # Load tags relationship
    media_logs = Ash.load!(media_logs, :tags)

    assign(socket, :media_logs, media_logs)
  end

  # Badge components
  defp media_type_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-sm",
      media_type_color(@media_type)
    ]}>
      <%= format_media_type(@media_type) %>
    </span>
    """
  end

  defp media_status_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-sm",
      status_color(@status)
    ]}>
      <%= format_status(@status) %>
    </span>
    """
  end

  defp media_type_color(media_type) do
    case media_type do
      :book -> "badge-info"
      :comic -> "badge-accent"
      :movie -> "badge-secondary"
      :music -> "badge-primary"
      :video_game -> "badge-success"
      _ -> "badge-ghost"
    end
  end

  defp status_color(status) do
    case status do
      :consuming -> "badge-warning"
      :consumed -> "badge-success"
      :want_to_consume -> "badge-info"
      :on_hold -> "badge-ghost"
      :abandoned -> "badge-error"
      _ -> "badge-ghost"
    end
  end

  defp format_media_type(media_type) do
    case media_type do
      :book -> "Book"
      :comic -> "Comic"
      :movie -> "Movie"
      :music -> "Music"
      :video_game -> "Game"
      _ -> to_string(media_type)
    end
  end

  defp format_status(status) do
    case status do
      :want_to_consume -> "Want"
      :consuming -> "In Progress"
      :consumed -> "Done"
      :on_hold -> "On Hold"
      :abandoned -> "Abandoned"
      _ -> to_string(status)
    end
  end
end
