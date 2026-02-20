defmodule WeaktyWeb.MediaLogLive.Index do
  use WeaktyWeb, :live_view
  require Ash.Query

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:media_type_filter, "all")
     |> assign(:status_filter, "all")
     |> load_media_logs()}
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
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl px-4 py-8">
      <div class="mb-8">
        <div class="flex justify-between items-center mb-4">
          <h1 class="text-3xl font-bold">Media Logs</h1>
        </div>

        <!-- Stats Header -->
        <div class="stats stats-horizontal shadow mb-6">
          <div class="stat">
            <div class="stat-title">Books Read</div>
            <div class="stat-value text-lg"><%= count_by_type(@media_logs, :book, :consumed) %></div>
          </div>
          <div class="stat">
            <div class="stat-title">Movies Watched</div>
            <div class="stat-value text-lg"><%= count_by_type(@media_logs, :movie, :consumed) %></div>
          </div>
          <div class="stat">
            <div class="stat-title">Games Played</div>
            <div class="stat-value text-lg"><%= count_by_type(@media_logs, :video_game, :consumed) %></div>
          </div>
        </div>

        <!-- Media Type Filter -->
        <div class="flex flex-wrap gap-2 mb-4">
          <.link
            patch={~p"/media-logs?type=all&status=#{@status_filter}"}
            class={["btn btn-sm", if(@media_type_filter == "all", do: "btn-primary", else: "btn-ghost")]}
          >
            All
          </.link>
          <.link
            patch={~p"/media-logs?type=book&status=#{@status_filter}"}
            class={["btn btn-sm", if(@media_type_filter == "book", do: "btn-primary", else: "btn-ghost")]}
          >
            📚 Books
          </.link>
          <.link
            patch={~p"/media-logs?type=comic&status=#{@status_filter}"}
            class={["btn btn-sm", if(@media_type_filter == "comic", do: "btn-primary", else: "btn-ghost")]}
          >
            📖 Comics
          </.link>
          <.link
            patch={~p"/media-logs?type=movie&status=#{@status_filter}"}
            class={["btn btn-sm", if(@media_type_filter == "movie", do: "btn-primary", else: "btn-ghost")]}
          >
            🎬 Movies
          </.link>
          <.link
            patch={~p"/media-logs?type=music&status=#{@status_filter}"}
            class={["btn btn-sm", if(@media_type_filter == "music", do: "btn-primary", else: "btn-ghost")]}
          >
            🎵 Music
          </.link>
          <.link
            patch={~p"/media-logs?type=video_game&status=#{@status_filter}"}
            class={["btn btn-sm", if(@media_type_filter == "video_game", do: "btn-primary", else: "btn-ghost")]}
          >
            🎮 Games
          </.link>
        </div>

        <!-- Status Filter -->
        <div class="dropdown">
          <label tabindex="0" class="btn btn-sm btn-outline m-1">
            <%= format_status_filter(@status_filter) %> ▼
          </label>
          <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-52">
            <li>
              <.link patch={~p"/media-logs?type=#{@media_type_filter}&status=all"}>
                All Status
              </.link>
            </li>
            <li>
              <.link patch={~p"/media-logs?type=#{@media_type_filter}&status=consumed"}>
                Consumed
              </.link>
            </li>
            <li>
              <.link patch={~p"/media-logs?type=#{@media_type_filter}&status=consuming"}>
                Currently Consuming
              </.link>
            </li>
          </ul>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
        <%= if Enum.empty?(@filtered_media_logs) do %>
          <div class="col-span-full card bg-base-200">
            <div class="card-body text-center">
              <p class="text-base-content/60">No media logs found</p>
            </div>
          </div>
        <% else %>
          <%= for media_log <- @filtered_media_logs do %>
            <.link navigate={~p"/media-logs/#{media_log.slug}"} class="card bg-base-100 shadow-sm hover:shadow-md transition-shadow cursor-pointer">
              <figure class="px-4 pt-4">
                <%= if media_log.thumbnail_url do %>
                  <img src={media_log.thumbnail_url} alt={media_log.title} class="rounded-lg h-48 w-full object-cover" />
                <% else %>
                  <div class="bg-base-300 rounded-lg h-48 w-full flex items-center justify-center text-6xl">
                    <%= media_type_emoji(media_log.media_type) %>
                  </div>
                <% end %>
              </figure>
              <div class="card-body">
                <h2 class="card-title text-lg">
                  <%= media_log.title %>
                  <%= if media_log.favourite do %>
                    <span class="text-warning">★</span>
                  <% end %>
                </h2>
                <%= if media_log.creator do %>
                  <p class="text-sm text-base-content/60"><%= media_log.creator %></p>
                <% end %>
                <%= if media_log.rating do %>
                  <div class="text-warning text-sm">
                    <%= String.duplicate("★", media_log.rating) %><%= String.duplicate("☆", 5 - media_log.rating) %>
                  </div>
                <% end %>
                <%= if media_log.notes do %>
                  <p class="text-sm text-base-content/70 line-clamp-2">
                    <%= String.slice(media_log.notes, 0, 100) %><%= if String.length(media_log.notes) > 100, do: "..." %>
                  </p>
                <% end %>
                <div class="card-actions justify-between items-center mt-2">
                  <div class="flex gap-1">
                    <span class={["badge badge-sm", media_type_color(media_log.media_type)]}>
                      <%= format_media_type(media_log.media_type) %>
                    </span>
                    <span class={["badge badge-sm", status_color(media_log.status)]}>
                      <%= format_status(media_log.status) %>
                    </span>
                  </div>
                </div>
              </div>
            </.link>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp load_media_logs(socket) do
    # Only load public media logs for public view, sorted by most recently consumed
    # Falls back to date_finished, then updated_at for items without date_consumed
    all_media_logs =
      Weakty.MediaLogs.MediaLog
      |> Ash.Query.for_read(:published)
      |> Ash.Query.sort([date_consumed: :desc_nils_last, date_finished: :desc_nils_last, updated_at: :desc])
      |> Ash.read!()
      |> Ash.load!(:tags)

    # Apply filters
    filtered_media_logs =
      all_media_logs
      |> filter_by_media_type(socket.assigns.media_type_filter)
      |> filter_by_status(socket.assigns.status_filter)

    socket
    |> assign(:media_logs, all_media_logs)
    |> assign(:filtered_media_logs, filtered_media_logs)
  end

  defp filter_by_media_type(media_logs, "all"), do: media_logs

  defp filter_by_media_type(media_logs, media_type) do
    media_type_atom = String.to_existing_atom(media_type)
    Enum.filter(media_logs, fn ml -> ml.media_type == media_type_atom end)
  end

  defp filter_by_status(media_logs, "all"), do: media_logs

  defp filter_by_status(media_logs, status) do
    status_atom = String.to_existing_atom(status)
    Enum.filter(media_logs, fn ml -> ml.status == status_atom end)
  end

  defp count_by_type(media_logs, media_type, status) do
    Enum.count(media_logs, fn ml ->
      ml.media_type == media_type && ml.status == status
    end)
  end

  defp media_type_emoji(media_type) do
    case media_type do
      :book -> "📚"
      :comic -> "📖"
      :movie -> "🎬"
      :music -> "🎵"
      :video_game -> "🎮"
      _ -> "📦"
    end
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

  defp format_status_filter("all"), do: "All Status"
  defp format_status_filter("consumed"), do: "Consumed"
  defp format_status_filter("consuming"), do: "Currently Consuming"
  defp format_status_filter(_), do: "Status"
end
