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
     |> assign(:year_filter, "all")
     |> assign(:view, "table")
     |> load_media_logs()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    media_type_filter = Map.get(params, "type", "all")
    status_filter = Map.get(params, "status", "all")
    year_filter = Map.get(params, "year", "all")

    {:noreply,
     socket
     |> assign(:media_type_filter, media_type_filter)
     |> assign(:status_filter, status_filter)
     |> assign(:year_filter, year_filter)
     |> load_media_logs()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container title="Media Log" size="4xl">
      <div class="mb-8">
        
    <!-- Filters Row -->
        <div class="flex gap-2 mb-4 items-center">
          <!-- Year Filter -->
          <div class="dropdown">
            <label tabindex="0" class="btn btn-sm ">
              {if @year_filter == "all", do: "All Years", else: @year_filter}
            </label>
            <ul
              tabindex="0"
              class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-40"
            >
              <li>
                <.link
                  patch={~p"/media-logs?type=#{@media_type_filter}&status=#{@status_filter}&year=all"}
                  class={if @year_filter == "all", do: "active"}
                  onclick="document.activeElement.blur()"
                >
                  All Years
                </.link>
              </li>
              <%= for year <- @available_years do %>
                <li>
                  <.link
                    patch={
                      ~p"/media-logs?type=#{@media_type_filter}&status=#{@status_filter}&year=#{year}"
                    }
                    class={if @year_filter == to_string(year), do: "active"}
                    onclick="document.activeElement.blur()"
                  >
                    {year}
                  </.link>
                </li>
              <% end %>
            </ul>
          </div>
          
    <!-- Media Type Filter -->
          <div class="dropdown">
            <label tabindex="0" class="btn btn-sm">
              {media_type_filter_label(@media_type_filter)}
            </label>
            <ul
              tabindex="0"
              class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-48"
            >
              <%= for filter <- media_type_filters() do %>
                <li>
                  <.link
                    patch={
                      ~p"/media-logs?type=#{filter.type}&status=#{@status_filter}&year=#{@year_filter}"
                    }
                    class={if @media_type_filter == filter.type, do: "active"}
                    onclick="document.activeElement.blur()"
                  >
                    {filter.label}
                    <span class="badge badge-sm ml-auto">
                      {filter_count(@media_logs, filter.type, @year_filter)}
                    </span>
                  </.link>
                </li>
              <% end %>
            </ul>
          </div>
          
    <!-- View Toggle -->
          <div class="join ml-auto flex-shrink-0">
            <button
              class={[
                "join-item btn btn-sm",
                if(@view == "table", do: "btn-outline", else: "btn-ghost")
              ]}
              phx-click="set_view"
              phx-value-view="table"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="w-4 h-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M4 6h16M4 10h16M4 14h16M4 18h16"
                />
              </svg>
            </button>
            <button
              class={[
                "join-item btn btn-sm",
                if(@view == "grid", do: "btn-outline", else: "btn-ghost")
              ]}
              phx-click="set_view"
              phx-value-view="grid"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="w-4 h-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"
                />
              </svg>
            </button>
          </div>
        </div>
      </div>

      <%= if Enum.empty?(@filtered_media_logs) do %>
        <div class="card bg-base-200">
          <div class="card-body text-center">
            <p class="text-base-content/60">No media logs found</p>
          </div>
        </div>
      <% else %>
        <%= if @view == "table" do %>
          <div class="overflow-x-auto">
            <table class="table table-zebra w-full">
              <thead>
                <tr class="text-base-content/60">
                  <th>Title</th>
                  <th class="hidden sm:table-cell">Creator</th>
                  <th class="hidden lg:table-cell">Finished</th>
                </tr>
              </thead>
              <tbody>
                <%= for media_log <- @filtered_media_logs do %>
                  <tr class="relative">
                    <td>
                      <div class="relative font-medium pl-5">
                        <%= if media_log.favourite do %>
                          <.icon
                            name="hero-star-solid"
                            class="absolute -left-1 top-1.5 w-3.5 h-3.5 text-warning"
                          />
                        <% end %>
                        {media_log.title}
                      </div>
                    </td>
                    <td class="hidden sm:table-cell text-base-content/70">{media_log.creator}</td>
                    <td class="hidden lg:table-cell text-base-content/70 min-w-[148px]">
                      {if media_log.date_consumed,
                        do: Calendar.strftime(media_log.date_consumed, "%b %-d, %Y")}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% else %>
          <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-8">
            <%= for media_log <- @filtered_media_logs do %>
              <div class="card bg-base-100">
                <figure class="relative">
                  <%= if media_log.thumbnail_url do %>
                    <img
                      src={media_log.thumbnail_url}
                      alt={media_log.title}
                      class="h-54 w-full object-cover"
                    />
                  <% else %>
                    <div class="bg-base-300 rounded-lg h-48 w-full flex items-center justify-center text-6xl">
                      {media_type_emoji(media_log.media_type)}
                    </div>
                  <% end %>
                  <%= if media_log.favourite do %>
                    <span class="absolute bottom-0 left-0 bg-primary p-1 w-8 h-8 flex items-center justify-center">
                      <.icon name="hero-star-solid" class="w-3 h-3 text-primary-content shadow" />
                    </span>
                  <% end %>
                </figure>
                <div class="py-2">
                  <h2 class="text-sm">{media_log.title}</h2>
                  <%= if media_log.creator do %>
                    <p class="text-sm text-base-content/60">{media_log.creator}</p>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </.page_container>
    """
  end

  @impl true
  def handle_event("set_view", %{"view" => view}, socket) when view in ["table", "grid"] do
    {:noreply, assign(socket, :view, view)}
  end

  defp load_media_logs(socket) do
    # Only load consumed media logs (stuff that's been finished), sorted by most recently consumed
    all_media_logs =
      Weakty.MediaLogs.MediaLog
      |> Ash.Query.filter(status == :consumed)
      |> Ash.Query.filter(public == true)
      |> Ash.Query.sort(date_consumed: :desc)
      |> Ash.read!()
      |> Ash.load!(:tags)

    # Apply filters
    filtered_media_logs =
      all_media_logs
      |> filter_by_media_type(socket.assigns.media_type_filter)
      |> filter_by_status(socket.assigns.status_filter)
      |> filter_by_year(socket.assigns.year_filter)

    # Get available years for the filter
    available_years = get_available_years(all_media_logs)

    socket
    |> assign(:media_logs, all_media_logs)
    |> assign(:filtered_media_logs, filtered_media_logs)
    |> assign(:available_years, available_years)
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

  defp filter_by_year(media_logs, "all"), do: media_logs

  defp filter_by_year(media_logs, year) when is_binary(year) do
    year_int = String.to_integer(year)

    Enum.filter(media_logs, fn ml ->
      ml.date_consumed && ml.date_consumed.year == year_int
    end)
  end

  defp get_available_years(media_logs) do
    media_logs
    |> Enum.filter(& &1.date_consumed)
    |> Enum.map(& &1.date_consumed.year)
    |> Enum.uniq()
    |> Enum.sort(:desc)
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

  defp media_type_filter_label("all"), do: "All Types"

  defp media_type_filter_label(type) do
    Enum.find_value(media_type_filters(), "All Types", fn f ->
      if f.type == type, do: f.label
    end)
  end

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

  defp filter_count(media_logs, "all", year_filter) do
    media_logs
    |> filter_by_year(year_filter)
    |> length()
  end

  defp filter_count(media_logs, type, year_filter) when is_binary(type) do
    type_atom = String.to_existing_atom(type)

    media_logs
    |> filter_by_year(year_filter)
    |> Enum.count(fn ml -> ml.media_type == type_atom end)
  end
end
