defmodule WeaktyWeb.MediaLogLive.Form do
  use WeaktyWeb, :live_view
  alias AshPhoenix.Form
  require Logger

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(params, _session, socket) do
    media_log =
      case params["id"] do
        nil -> nil
        id ->
          Weakty.MediaLogs.MediaLog
          |> Ash.get!(id)
          |> Ash.load!(:tags)
      end

    existing_tags = if media_log, do: Enum.map(media_log.tags || [], & &1.name), else: []

    form =
      if media_log do
        Form.for_update(media_log, :update, domain: Weakty.MediaLogs, forms: [auto?: false])
      else
        Form.for_create(Weakty.MediaLogs.MediaLog, :create,
          domain: Weakty.MediaLogs,
          forms: [auto?: false],
          prepare_source: fn changeset ->
            changeset
            |> Ash.Changeset.set_context(%{user_id: socket.assigns.current_user.id})
            |> Ash.Changeset.force_change_attribute(:user_id, socket.assigns.current_user.id)
          end
        )
      end
      |> Form.validate(%{})
      |> to_form()

    media_type = if media_log, do: media_log.media_type, else: :book

    {:ok,
     socket
     |> assign(
       form: form,
       media_log: media_log,
       tags: existing_tags,
       media_type: media_type,
       search_query: "",
       search_results: []
     )
     |> assign(:current_path, "/admin/media-logs"),
     layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen">
      <!-- Main content area -->
      <div class="flex-1 max-w-4xl mx-auto px-8 py-8">
        <div class="flex items-center gap-4 mb-8">
          <.link navigate={~p"/admin/media-logs"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="w-4 h-4" />
            Media Logs
          </.link>
          <div class="text-sm text-base-content/70">
            <%= if @media_log, do: "Editing", else: "New entry" %>
          </div>
          <div class="flex-1" />
          <button type="submit" form="media-log-form" class="btn btn-primary btn-sm">
            <%= if @media_log, do: "Update", else: "Create" %>
          </button>
        </div>

        <.form
          id="media-log-form"
          for={@form}
          phx-submit="save"
          phx-change="validate"
          class="space-y-6 items-center"
        >
          <input
            type="text"
            name={@form[:title].name}
            value={@form[:title].value}
            class="input input-ghost w-full text-2xl py-4 font-bold px-0 focus:outline-none"
            placeholder="Title"
            required
          />
          <textarea
            name={@form[:notes].name}
            class="textarea textarea-ghost w-full min-h-[500px] text-lg leading-relaxed px-0 focus:outline-none"
            placeholder="Your notes and thoughts..."
          ><%= @form[:notes].value %></textarea>
        </.form>
      </div>

      <!-- Sidebar -->
      <div
        class="w-96 border-l border-base-300 bg-base-100 p-6 overflow-y-auto max-h-screen sticky top-0"
        style="font-family: 'IBM Plex Sans', sans-serif;"
      >
        <h2 class="text-xl font-bold mb-6">Details</h2>

        <div class="space-y-4">
          <!-- Search (new entries only) -->
          <%= if is_nil(@media_log) && search_available?(@media_type) do %>
            <div class="form-control mb-4">
              <label class="label mb-1">
                <span class="label-text text-sm font-semibold">Search to auto-fill</span>
              </label>
              <form phx-submit="search_media" phx-change="update_search_query" class="join w-full">
                <input
                  type="text"
                  name="search_query"
                  value={@search_query}
                  placeholder={"Search for a #{media_type_label(@media_type)}..."}
                  class="input input-bordered input-sm join-item flex-1"
                />
                <button type="submit" class="btn btn-sm btn-secondary join-item">
                  Search
                </button>
              </form>
              <%= if length(@search_results) > 0 do %>
                <div class="space-y-1 max-h-60 overflow-y-auto mt-2">
                  <%= for result <- @search_results do %>
                    <div class="flex items-center gap-3 p-2 rounded hover:bg-base-300">
                      <%= if result.cover_url do %>
                        <img src={result.cover_url} alt={result.title} class="w-8 h-12 object-cover rounded flex-shrink-0" />
                      <% else %>
                        <div class="w-8 h-12 bg-base-300 rounded flex-shrink-0" />
                      <% end %>
                      <div class="flex-1 min-w-0">
                        <div class="font-medium text-xs truncate"><%= result.title %></div>
                        <div class="text-xs text-base-content/60 truncate"><%= Enum.join(result.creators, ", ") %></div>
                      </div>
                      <button
                        type="button"
                        phx-click="select_result"
                        phx-value-id={result.external_id}
                        class="btn btn-xs btn-primary flex-shrink-0"
                      >
                        Use
                      </button>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
            <div class="divider"></div>
          <% end %>

          <!-- Slug -->
          <div class="form-control mb-4">
            <label class="label mb-1">
              <span class="label-text text-sm font-semibold">Slug</span>
            </label>
            <input
              type="text"
              form="media-log-form"
              name={@form[:slug].name}
              value={@form[:slug].value}
              class="input input-bordered input-sm w-full text-sm"
              placeholder="url-friendly-slug"
            />
          </div>

          <!-- Media Type -->
          <div class="form-control mb-4">
            <label class="label mb-1">
              <span class="label-text text-sm font-semibold">Media Type</span>
            </label>
            <select
              form="media-log-form"
              name={@form[:media_type].name}
              class="select select-bordered select-sm w-full text-sm"
            >
              <option value="book" selected={@media_type in [:book, "book"]}>Book</option>
              <option value="comic" selected={@media_type in [:comic, "comic"]}>Comic</option>
              <option value="movie" selected={@media_type in [:movie, "movie"]}>Movie</option>
              <option value="music" selected={@media_type in [:music, "music"]}>Music</option>
              <option value="video_game" selected={@media_type in [:video_game, "video_game"]}>Video Game</option>
            </select>
          </div>

          <!-- Creator -->
          <div class="form-control mb-4">
            <label class="label mb-1">
              <span class="label-text text-sm font-semibold"><%= creator_label(@media_type) %></span>
            </label>
            <input
              type="text"
              form="media-log-form"
              name={@form[:creator].name}
              value={@form[:creator].value}
              class="input input-bordered input-sm w-full text-sm"
              placeholder={creator_placeholder(@media_type)}
            />
          </div>

          <!-- Status -->
          <div class="form-control mb-4">
            <label class="label mb-1">
              <span class="label-text text-sm font-semibold">Status</span>
            </label>
            <select
              form="media-log-form"
              name={@form[:status].name}
              class="select select-bordered select-sm w-full text-sm"
            >
              <option value="want_to_consume" selected={@form[:status].value in [:want_to_consume, "want_to_consume"]}>
                Want to <%= consume_verb(@media_type) %>
              </option>
              <option value="consuming" selected={@form[:status].value in [:consuming, "consuming"]}>
                Currently <%= consume_verb(@media_type, :ing) %>
              </option>
              <option value="consumed" selected={@form[:status].value in [:consumed, "consumed"]}>
                <%= consume_verb(@media_type, :past) %>
              </option>
              <option value="on_hold" selected={@form[:status].value in [:on_hold, "on_hold"]}>On Hold</option>
              <option value="abandoned" selected={@form[:status].value in [:abandoned, "abandoned"]}>Abandoned</option>
            </select>
          </div>

          <!-- Date fields -->
          <%= if @media_type in [:book, :comic, "book", "comic"] do %>
            <div class="grid grid-cols-2 gap-3 mb-4">
              <div class="form-control">
                <label class="label mb-1">
                  <span class="label-text text-sm font-semibold">Started</span>
                </label>
                <input type="date" form="media-log-form" name={@form[:date_started].name} value={@form[:date_started].value} class="input input-bordered input-sm w-full text-sm" />
              </div>
              <div class="form-control">
                <label class="label mb-1">
                  <span class="label-text text-sm font-semibold">Finished</span>
                </label>
                <input type="date" form="media-log-form" name={@form[:date_finished].name} value={@form[:date_finished].value} class="input input-bordered input-sm w-full text-sm" />
              </div>
            </div>
          <% else %>
            <div class="form-control mb-4">
              <label class="label mb-1">
                <span class="label-text text-sm font-semibold"><%= date_consumed_label(@media_type) %></span>
              </label>
              <input type="date" form="media-log-form" name={@form[:date_consumed].name} value={@form[:date_consumed].value} class="input input-bordered input-sm w-full text-sm" />
            </div>
          <% end %>

          <div class="form-control mb-4">
            <label class="label mb-1">
              <span class="label-text text-sm font-semibold">Date Published</span>
            </label>
            <input type="date" form="media-log-form" name={@form[:date_published].name} value={@form[:date_published].value} class="input input-bordered input-sm w-full text-sm" />
          </div>

          <!-- Rating -->
          <div class="form-control mb-4">
            <label class="label mb-1">
              <span class="label-text text-sm font-semibold">Rating</span>
            </label>
            <select form="media-log-form" name={@form[:rating].name} class="select select-bordered select-sm w-full text-sm">
              <option value="">No rating</option>
              <option value="1" selected={@form[:rating].value == 1}>★</option>
              <option value="2" selected={@form[:rating].value == 2}>★★</option>
              <option value="3" selected={@form[:rating].value == 3}>★★★</option>
              <option value="4" selected={@form[:rating].value == 4}>★★★★</option>
              <option value="5" selected={@form[:rating].value == 5}>★★★★★</option>
            </select>
          </div>

          <!-- Thumbnail -->
          <div class="form-control mb-4">
            <label class="label mb-1">
              <span class="label-text text-sm font-semibold">Thumbnail URL</span>
            </label>
            <input form="media-log-form" name={@form[:thumbnail_url].name} value={@form[:thumbnail_url].value} class="input input-bordered input-sm w-full text-sm" placeholder="https://..." />
            <%= if @form[:thumbnail_url].value do %>
              <img src={@form[:thumbnail_url].value} alt="Preview" class="mt-2 w-20 h-auto rounded" />
            <% end %>
          </div>

          <!-- External URL -->
          <div class="form-control mb-4">
            <label class="label mb-1">
              <span class="label-text text-sm font-semibold">External URL</span>
            </label>
            <input type="url" form="media-log-form" name={@form[:external_url].name} value={@form[:external_url].value} class="input input-bordered input-sm w-full text-sm" placeholder="https://www.goodreads.com/..." />
          </div>

          <!-- Tags -->
          <div class="form-control mb-4">
            <label class="label mb-1">
              <span class="label-text text-sm font-semibold">Tags</span>
            </label>
            <.live_component module={WeaktyWeb.TagAdder} id="tag-adder" tags={@tags} />
          </div>

          <div class="divider"></div>

          <!-- Favourite + Public -->
          <div class="grid grid-cols-2 gap-3 mb-4">
            <.input field={@form[:favourite]} type="checkbox" label="Favourite" form="media-log-form" />
            <.input field={@form[:public]} type="checkbox" label="Public" form="media-log-form" />
          </div>

          <%= if @media_log do %>
            <div class="divider"></div>
            <button
              type="button"
              phx-click="delete_media_log"
              data-confirm="Are you sure you want to delete this entry?"
              class="btn btn-error btn-sm w-full"
            >
              Delete entry
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = Form.validate(socket.assigns.form, params, errors: true)

    media_type =
      case params["media_type"] do
        mt when is_binary(mt) and mt != "" -> String.to_existing_atom(mt)
        _ -> socket.assigns.media_type
      end

    {:noreply, assign(socket, form: form, media_type: media_type)}
  end

  def handle_event("save", %{"form" => params}, socket) do
    params = maybe_download_thumbnail(params)

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, media_log} ->
        handle_tag_update(media_log, socket.assigns.tags)
        {:noreply,
         socket
         |> put_flash(:info, "Saved successfully.")
         |> push_navigate(to: ~p"/admin/media-logs")}

      {:error, form} ->
        Logger.error("MediaLog save failed: #{inspect(form.source.errors)}")
        {:noreply,
         socket
         |> put_flash(:error, "Could not save. Please check the fields below.")
         |> assign(form: to_form(form))}
    end
  end

  @impl true
  def handle_info({:tag_changed, tags}, socket) do
    {:noreply, assign(socket, :tags, tags)}
  end

  def handle_event("delete_media_log", _params, socket) do
    case Weakty.MediaLogs.MediaLog.delete_media_log(socket.assigns.media_log) do
      :ok ->
        {:noreply, push_navigate(socket, to: ~p"/admin/media-logs")}

      {:ok, _} ->
        {:noreply, push_navigate(socket, to: ~p"/admin/media-logs")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete entry")}
    end
  end

  def handle_event("update_search_query", %{"search_query" => value}, socket) do
    {:noreply, assign(socket, search_query: value)}
  end

  def handle_event("search_media", _params, socket) do
    case Weakty.Media.search(socket.assigns.media_type, socket.assigns.search_query) do
      {:ok, results} -> {:noreply, assign(socket, search_results: results)}
      {:error, _} -> {:noreply, assign(socket, search_results: [])}
    end
  end

  def handle_event("select_result", %{"id" => external_id}, socket) do
    result = Enum.find(socket.assigns.search_results, &(&1.external_id == external_id))

    if result do
      params =
        %{
          "title" => result.title || "",
          "creator" => result.creators |> Enum.take(3) |> Enum.join(", "),
          "thumbnail_url" => result.cover_url || "",
          "media_type" => to_string(socket.assigns.media_type)
        }
        |> maybe_put_date("date_published", result.year)

      form = socket.assigns.form |> Form.validate(params, errors: false) |> to_form()
      {:noreply, assign(socket, form: form, search_results: [])}
    else
      {:noreply, socket}
    end
  end

  defp maybe_download_thumbnail(params) do
    case params["thumbnail_url"] do
      url when is_binary(url) and url != "" ->
        Map.put(params, "thumbnail_url", Weakty.ImageDownloader.maybe_download(url, "media"))

      _ ->
        params
    end
  end

  defp handle_tag_update(media_log, tags) do
    Weakty.Tags.TagManager.apply_tags(media_log, :media_log, tags, Weakty.MediaLogs.MediaLogTag, :media_log_id)
  end

  defp creator_label(media_type) do
    case media_type do
      t when t in [:book, "book", :comic, "comic"] -> "Author"
      t when t in [:music, "music"] -> "Artist"
      t when t in [:movie, "movie"] -> "Director"
      t when t in [:video_game, "video_game"] -> "Developer"
      _ -> "Creator"
    end
  end

  defp creator_placeholder(media_type) do
    case media_type do
      t when t in [:book, "book"] -> "e.g., Frank Herbert"
      t when t in [:music, "music"] -> "e.g., Radiohead"
      t when t in [:movie, "movie"] -> "e.g., Denis Villeneuve"
      t when t in [:video_game, "video_game"] -> "e.g., FromSoftware"
      t when t in [:comic, "comic"] -> "e.g., Alan Moore"
      _ -> "Enter creator name"
    end
  end

  defp consume_verb(media_type, tense \\ :base) do
    case {media_type, tense} do
      {t, :base} when t in [:book, "book", :comic, "comic"] -> "Read"
      {t, :ing} when t in [:book, "book", :comic, "comic"] -> "Reading"
      {t, :past} when t in [:book, "book", :comic, "comic"] -> "Read"
      {t, :base} when t in [:movie, "movie"] -> "Watch"
      {t, :ing} when t in [:movie, "movie"] -> "Watching"
      {t, :past} when t in [:movie, "movie"] -> "Watched"
      {t, :base} when t in [:music, "music"] -> "Listen"
      {t, :ing} when t in [:music, "music"] -> "Listening"
      {t, :past} when t in [:music, "music"] -> "Listened"
      {t, :base} when t in [:video_game, "video_game"] -> "Play"
      {t, :ing} when t in [:video_game, "video_game"] -> "Playing"
      {t, :past} when t in [:video_game, "video_game"] -> "Played"
      {_, :base} -> "Consume"
      {_, :ing} -> "Consuming"
      {_, :past} -> "Consumed"
    end
  end

  defp date_consumed_label(media_type) do
    case media_type do
      t when t in [:movie, "movie"] -> "Date Watched"
      t when t in [:music, "music"] -> "Date Listened"
      t when t in [:video_game, "video_game"] -> "Date Played"
      _ -> "Date Consumed"
    end
  end

  defp search_available?(media_type) do
    media_type in [:book, :music, :movie, "book", "music", "movie"]
  end

  defp media_type_label(media_type) do
    case media_type do
      t when t in [:book, "book"] -> "book"
      t when t in [:music, "music"] -> "album"
      t when t in [:movie, "movie"] -> "movie"
      t when t in [:comic, "comic"] -> "comic"
      t when t in [:video_game, "video_game"] -> "game"
      _ -> "title"
    end
  end

  defp maybe_put_date(params, key, year) when is_binary(year) do
    date =
      cond do
        String.match?(year, ~r/^\d{4}-\d{2}-\d{2}$/) -> year
        String.match?(year, ~r/^\d{4}-\d{2}$/) -> "#{year}-01"
        String.match?(year, ~r/^\d{4}$/) -> "#{year}-01-01"
        true -> nil
      end

    if date, do: Map.put(params, key, date), else: params
  end

  defp maybe_put_date(params, _key, _year), do: params
end
