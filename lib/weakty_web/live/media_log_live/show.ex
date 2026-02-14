defmodule WeaktyWeb.MediaLogLive.Show do
  use WeaktyWeb, :live_view

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    media_log =
      Weakty.MediaLogs.MediaLog
      |> Ash.Query.for_read(:get_by_slug, %{slug: slug})
      |> Ash.read_one!()
      |> Ash.load!([:user, :tags])

    {:ok,
     socket
     |> assign(media_log: media_log)
     |> assign(og_content: media_log)
     |> assign(page_title: media_log.title)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <article class="mx-auto max-w-3xl px-4 py-12">
      <div class="grid grid-cols-1 md:grid-cols-3 gap-8 mb-8">
        <!-- Thumbnail Column -->
        <div class="md:col-span-1">
          <%= if @media_log.thumbnail_url do %>
            <img
              src={@media_log.thumbnail_url}
              alt={@media_log.title}
              class="w-full rounded-lg shadow-lg"
            />
          <% else %>
            <div class="bg-base-300 rounded-lg aspect-[2/3] flex items-center justify-center text-8xl">
              <%= media_type_emoji(@media_log.media_type) %>
            </div>
          <% end %>

          <%= if @media_log.favourite do %>
            <div class="mt-4 badge badge-warning badge-lg w-full">
              ★ Favourite
            </div>
          <% end %>
        </div>

        <!-- Info Column -->
        <div class="md:col-span-2">
          <div class="flex flex-wrap gap-2 mb-4">
            <span class={["badge", media_type_color(@media_log.media_type)]}>
              <%= format_media_type(@media_log.media_type) %>
            </span>
            <span class={["badge", status_color(@media_log.status)]}>
              <%= format_status(@media_log.status) %>
            </span>
          </div>

          <h1 class="text-4xl font-bold mb-2"><%= @media_log.title %></h1>

          <%= if @media_log.creator do %>
            <p class="text-xl text-base-content/70 mb-4">
              by <%= @media_log.creator %>
            </p>
          <% end %>

          <%= if @media_log.rating do %>
            <div class="flex items-center gap-2 mb-4">
              <div class="text-warning text-2xl">
                <%= String.duplicate("★", @media_log.rating) %><%= String.duplicate("☆", 5 - @media_log.rating) %>
              </div>
              <span class="text-base-content/60"><%= @media_log.rating %>/5</span>
            </div>
          <% end %>

          <!-- Metadata Grid -->
          <div class="grid grid-cols-2 gap-4 mb-6">
            <%= if @media_log.date_published do %>
              <div>
                <div class="text-sm text-base-content/60">Published</div>
                <div class="font-medium"><%= format_date(@media_log.date_published) %></div>
              </div>
            <% end %>

            <%= cond do %>
              <% @media_log.date_finished -> %>
                <div>
                  <div class="text-sm text-base-content/60">Finished</div>
                  <div class="font-medium"><%= format_date(@media_log.date_finished) %></div>
                </div>
              <% @media_log.date_consumed -> %>
                <div>
                  <div class="text-sm text-base-content/60"><%= date_consumed_label(@media_log.media_type) %></div>
                  <div class="font-medium"><%= format_date(@media_log.date_consumed) %></div>
                </div>
              <% @media_log.date_started -> %>
                <div>
                  <div class="text-sm text-base-content/60">Started</div>
                  <div class="font-medium"><%= format_date(@media_log.date_started) %></div>
                </div>
              <% true -> %>
            <% end %>
          </div>

          <%= if @media_log.external_url do %>
            <div class="mb-4">
              <a
                href={@media_log.external_url}
                target="_blank"
                rel="noopener noreferrer"
                class="btn btn-outline btn-sm"
              >
                <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" />
                View External Link
              </a>
            </div>
          <% end %>

          <%= if @media_log.tags && @media_log.tags != [] do %>
            <div class="flex flex-wrap gap-2 mb-4">
              <%= for tag <- @media_log.tags do %>
                <span class="badge badge-outline"><%= tag.name %></span>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <%= if @media_log.notes do %>
        <div class="divider"></div>
        <div class="prose max-w-none">
          <h2>Notes</h2>
          <p class="whitespace-pre-wrap"><%= @media_log.notes %></p>
        </div>
      <% end %>

      <div class="divider"></div>

      <div class="text-sm text-base-content/60">
        Logged on <%= format_datetime(@media_log.inserted_at) %>
      </div>

      <%= if @current_user && @current_user.id == @media_log.user_id do %>
        <div class="divider my-8"></div>
        <div class="flex gap-2">
          <.link navigate={~p"/admin/media-logs/#{@media_log.id}/edit"} class="btn btn-primary">
            Edit Media Log
          </.link>
          <%= if @media_log.public do %>
            <button
              phx-click="unpublish"
              class="btn btn-warning"
            >
              Make Private
            </button>
          <% else %>
            <button
              phx-click="publish"
              class="btn btn-success"
            >
              Make Public
            </button>
          <% end %>
          <button
            phx-click="delete"
            data-confirm="Are you sure you want to delete this media log?"
            class="btn btn-error"
          >
            Delete
          </button>
        </div>
      <% end %>
    </article>
    """
  end

  @impl true
  def handle_event("publish", _params, socket) do
    Weakty.MediaLogs.MediaLog.publish_media_log(socket.assigns.media_log)

    media_log =
      Weakty.MediaLogs.MediaLog
      |> Ash.Query.for_read(:get_by_slug, %{slug: socket.assigns.media_log.slug})
      |> Ash.read_one!()
      |> Ash.load!([:user, :tags])

    {:noreply, assign(socket, media_log: media_log)}
  end

  def handle_event("unpublish", _params, socket) do
    Weakty.MediaLogs.MediaLog.unpublish_media_log(socket.assigns.media_log)

    media_log =
      Weakty.MediaLogs.MediaLog
      |> Ash.Query.for_read(:get_by_slug, %{slug: socket.assigns.media_log.slug})
      |> Ash.read_one!()
      |> Ash.load!([:user, :tags])

    {:noreply, assign(socket, media_log: media_log)}
  end

  def handle_event("delete", _params, socket) do
    Ash.destroy!(socket.assigns.media_log)
    {:noreply, push_navigate(socket, to: ~p"/media-logs")}
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
      :want_to_consume -> "Want to Consume"
      :consuming -> "Currently Consuming"
      :consumed -> "Consumed"
      :on_hold -> "On Hold"
      :abandoned -> "Abandoned"
      _ -> to_string(status)
    end
  end

  defp date_consumed_label(media_type) do
    case media_type do
      :movie -> "Watched"
      :music -> "Listened"
      :video_game -> "Played"
      _ -> "Consumed"
    end
  end

  defp format_date(date) do
    Calendar.strftime(date, "%B %d, %Y")
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end
end
