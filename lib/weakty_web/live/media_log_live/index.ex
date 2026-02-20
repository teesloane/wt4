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
        <h1 class="text-lg font-bold mb-4">Media Logs</h1>

        <!-- Media Type Filter - Mobile Dropdown -->
        <div class="dropdown lg:hidden mb-4">
          <label tabindex="0" class="btn btn-sm btn-outline">
            Media Types ▼
          </label>
          <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-52">
            <%= for filter <- media_type_filters() do %>
              <li>
                <.link
                  patch={~p"/media-logs?type=#{filter.type}&status=#{@status_filter}"}
                  class={if @media_type_filter == filter.type, do: "active"}
                >
                  <%= filter.label %> (<%= filter_count(@media_logs, filter.type) %>)
                </.link>
              </li>
            <% end %>
          </ul>
        </div>

        <!-- Media Type Filter - Desktop Buttons -->
        <div class="hidden lg:flex gap-2 mb-4 flex-wrap">
          <%= for filter <- media_type_filters() do %>
            <.link
              patch={~p"/media-logs?type=#{filter.type}&status=#{@status_filter}"}
              class={["btn btn-sm", if(@media_type_filter == filter.type, do: "btn-primary", else: "btn-ghost")]}
            >
              <%= filter.label %> <span class="badge badge-sm ml-1"><%= filter_count(@media_logs, filter.type) %></span>
            </.link>
          <% end %>
        </div>
      </div>

      <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
        <%= if Enum.empty?(@filtered_media_logs) do %>
          <div class="col-span-full card bg-base-200">
            <div class="card-body text-center">
              <p class="text-base-content/60">No media logs found</p>
            </div>
          </div>
        <% else %>
          <%= for media_log <- @filtered_media_logs do %>
            <.link navigate={~p"/media-logs/#{media_log.slug}"} class="card bg-base-100 p-2 hover:shadow-md transition-shadow cursor-pointer">
              <figure class="">
                <%= if media_log.thumbnail_url do %>
                  <img src={media_log.thumbnail_url} alt={media_log.title} class="rounded-sm h-48 w-full object-cover" />
                <% else %>
                  <div class="bg-base-300 rounded-lg h-48 w-full flex items-center justify-center text-6xl">
                    <%= media_type_emoji(media_log.media_type) %>
                  </div>
                <% end %>
              </figure>
              <div class="py-2">
                <h2 class="text-sm gap-2 flex items-start">
                  <%= media_log.title %>
                  <%= if media_log.favourite do %>
                    <span class="text-warning">★</span>
                  <% end %>
                </h2>
                <%= if media_log.creator do %>
                  <p class="text-sm text-base-content/60"><%= media_log.creator %></p>
                <% end %>
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
    all_media_logs =
      Weakty.MediaLogs.MediaLog
      # |> Ash.Query.for_read(:published)
      |> Ash.Query.sort(date_consumed: :desc)
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

  defp media_type_filters do
    [
      %{type: "all", label: "All"},
      %{type: "book", label: "📚 Books"},
      %{type: "comic", label: "📖 Comics"},
      %{type: "movie", label: "🎬 Movies"},
      %{type: "music", label: "🎵 Music"},
      %{type: "video_game", label: "🎮 Games"}
    ]
  end

  defp filter_count(media_logs, "all"), do: length(media_logs)
  defp filter_count(media_logs, type) when is_binary(type) do
    type_atom = String.to_existing_atom(type)
    Enum.count(media_logs, fn ml -> ml.media_type == type_atom end)
  end
end
