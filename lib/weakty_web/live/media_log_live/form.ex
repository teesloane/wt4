defmodule WeaktyWeb.MediaLogLive.Form do
  use WeaktyWeb, :live_view
  alias AshPhoenix.Form

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

    # Extract existing tag names if editing
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

    # Get media_type from form to determine which date fields to show
    media_type = if media_log, do: media_log.media_type, else: :book

    {:ok,
     socket
     |> assign(
       form: form,
       media_log: media_log,
       tags: existing_tags,
       tag_input: "",
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
    <div class="mx-auto max-w-4xl px-4 py-8">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold">
          <%= if @media_log, do: "Edit Media Log", else: "New Media Log" %>
        </h1>
      </div>

      <%= if is_nil(@media_log) && search_available?(@media_type) do %>
        <div class="card bg-base-200 mb-8">
          <div class="card-body p-4 gap-3">
            <h3 class="font-semibold text-sm">Search to auto-fill</h3>
            <div class="join w-full">
            <.form class="flex w-full">
              <input
                type="text"
                value={@search_query}
                phx-change="update_search_query"
                phx-keydown="search_media"
                phx-key="Enter"
                name="search_query"
                placeholder={"Search for a #{media_type_label(@media_type)}..."}
                class="input input-bordered join-item w-full"
              />
              <button
                type="button"
                phx-click="search_media"
                class="btn btn-secondary join-item"
              >
                Search
              </button>
              </.form>
            </div>

            <%= if length(@search_results) > 0 do %>
              <div class="space-y-1 max-h-80 overflow-y-auto">
                <%= for result <- @search_results do %>
                  <div class="flex items-center gap-3 p-2 rounded hover:bg-base-300">
                    <%= if result.cover_url do %>
                      <img
                        src={result.cover_url}
                        alt={result.title}
                        class="w-10 h-14 object-cover rounded flex-shrink-0"
                      />
                    <% else %>
                      <div class="w-10 h-14 bg-base-300 rounded flex-shrink-0 flex items-center justify-center text-base-content/30 text-xs">
                        ?
                      </div>
                    <% end %>
                    <div class="flex-1 min-w-0">
                      <div class="font-medium text-sm truncate"><%= result.title %></div>
                      <div class="text-xs text-base-content/70 truncate">
                        <%= Enum.join(result.creators, ", ") %>
                      </div>
                      <div class="text-xs text-base-content/50">
                        <%= result.year %><%= if result.year && result.media_type, do: " · " %><%= media_type_label(result.media_type) %>
                      </div>
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
        </div>
      <% end %>

      <.form
        for={@form}
        phx-submit="save"
        phx-change="validate"
        class="space-y-6"
      >
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div class="form-control">
            <label class="label">
              <span class="label-text text-sm font-semibold">Title *</span>
            </label>
            <input
              type="text"
              name={@form[:title].name}
              value={@form[:title].value}
              class="input input-bordered w-full text-xl"
              placeholder="Enter title..."
              required
            />
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text text-sm font-semibold">Slug</span>
              <span class="label-text-alt">Auto-generated if empty</span>
            </label>
            <input
              type="text"
              name={@form[:slug].name}
              value={@form[:slug].value}
              class="input input-bordered w-full"
              placeholder="url-friendly-slug"
            />
          </div>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div class="form-control">
            <label class="label">
              <span class="label-text text-sm font-semibold">Media Type *</span>
            </label>
            <select
              name={@form[:media_type].name}
              class="select select-bordered w-full"
              phx-change="media_type_changed"
              required
            >
              <option value="book" selected={@media_type == :book || @media_type == "book"}>
                Book
              </option>
              <option value="comic" selected={@media_type == :comic || @media_type == "comic"}>
                Comic
              </option>
              <option value="movie" selected={@media_type == :movie || @media_type == "movie"}>
                Movie
              </option>
              <option value="music" selected={@media_type == :music || @media_type == "music"}>
                Music
              </option>
              <option value="video_game" selected={@media_type == :video_game || @media_type == "video_game"}>
                Video Game
              </option>
            </select>
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text text-sm font-semibold"><%= creator_label(@media_type) %></span>
            </label>
            <input
              type="text"
              name={@form[:creator].name}
              value={@form[:creator].value}
              class="input input-bordered w-full"
              placeholder={creator_placeholder(@media_type)}
            />
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text text-sm font-semibold">Status *</span>
            </label>
            <select
              name={@form[:status].name}
              class="select select-bordered w-full"
              required
            >
              <option value="want_to_consume" selected={@form[:status].value == :want_to_consume || @form[:status].value == "want_to_consume"}>
                Want to <%= consume_verb(@media_type) %>
              </option>
              <option value="consuming" selected={@form[:status].value == :consuming || @form[:status].value == "consuming"}>
                Currently <%= consume_verb(@media_type, :ing) %>
              </option>
              <option value="consumed" selected={@form[:status].value == :consumed || @form[:status].value == "consumed"}>
                <%= consume_verb(@media_type, :past) %>
              </option>
              <option value="on_hold" selected={@form[:status].value == :on_hold || @form[:status].value == "on_hold"}>
                On Hold
              </option>
              <option value="abandoned" selected={@form[:status].value == :abandoned || @form[:status].value == "abandoned"}>
                Abandoned
              </option>
            </select>
          </div>
        </div>

        <!-- Conditional Date Fields -->
        <%= if @media_type in [:book, :comic, "book", "comic"] do %>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div class="form-control">
              <label class="label">
                <span class="label-text text-sm font-semibold">Date Started</span>
              </label>
              <input
                type="date"
                name={@form[:date_started].name}
                value={@form[:date_started].value}
                class="input input-bordered w-full"
              />
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text text-sm font-semibold">Date Finished</span>
              </label>
              <input
                type="date"
                name={@form[:date_finished].name}
                value={@form[:date_finished].value}
                class="input input-bordered w-full"
              />
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text text-sm font-semibold">Date Published</span>
              </label>
              <input
                type="date"
                name={@form[:date_published].name}
                value={@form[:date_published].value}
                class="input input-bordered w-full"
              />
            </div>
          </div>
        <% else %>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div class="form-control">
              <label class="label">
                <span class="label-text text-sm font-semibold"><%= date_consumed_label(@media_type) %></span>
              </label>
              <input
                type="date"
                name={@form[:date_consumed].name}
                value={@form[:date_consumed].value}
                class="input input-bordered w-full"
              />
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text text-sm font-semibold">Date Published</span>
              </label>
              <input
                type="date"
                name={@form[:date_published].name}
                value={@form[:date_published].value}
                class="input input-bordered w-full"
              />
            </div>
          </div>
        <% end %>

        <div class="form-control">
          <label class="label">
            <span class="label-text text-sm font-semibold">Rating</span>
            <span class="label-text-alt">1-5 stars</span>
          </label>
          <select
            name={@form[:rating].name}
            class="select select-bordered w-full"
          >
            <option value="">No rating</option>
            <option value="1" selected={@form[:rating].value == 1}>★</option>
            <option value="2" selected={@form[:rating].value == 2}>★★</option>
            <option value="3" selected={@form[:rating].value == 3}>★★★</option>
            <option value="4" selected={@form[:rating].value == 4}>★★★★</option>
            <option value="5" selected={@form[:rating].value == 5}>★★★★★</option>
          </select>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div class="form-control">
            <label class="label">
              <span class="label-text text-sm font-semibold">Thumbnail URL</span>
              <span class="label-text-alt">Cover art, poster, or album art</span>
            </label>
            <input
              type="url"
              name={@form[:thumbnail_url].name}
              value={@form[:thumbnail_url].value}
              class="input input-bordered w-full"
              placeholder="https://example.com/image.jpg"
            />
            <%= if @form[:thumbnail_url].value do %>
              <div class="mt-2">
                <img src={@form[:thumbnail_url].value} alt="Preview" class="w-32 h-auto rounded" />
              </div>
            <% end %>
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text text-sm font-semibold">External URL</span>
              <span class="label-text-alt">Link to Goodreads, IMDB, etc.</span>
            </label>
            <input
              type="url"
              name={@form[:external_url].name}
              value={@form[:external_url].value}
              class="input input-bordered w-full"
              placeholder="https://www.goodreads.com/..."
            />
          </div>
        </div>

        <div class="form-control">
          <label class="label">
            <span class="label-text text-sm font-semibold">Notes</span>
            <span class="label-text-alt">Your thoughts and commentary</span>
          </label>
          <textarea
            name={@form[:notes].name}
            class="textarea textarea-bordered w-full h-32"
            placeholder="Share your thoughts..."
          ><%= @form[:notes].value %></textarea>
        </div>

        <div class="form-control">
          <label class="label">
            <span class="label-text text-sm font-semibold">Tags</span>
          </label>

          <%= if length(@tags) > 0 do %>
            <div class="flex flex-wrap gap-2 mb-2">
              <%= for tag <- @tags do %>
                <div class="badge badge-lg gap-2">
                  <%= tag %>
                  <button
                    type="button"
                    phx-click="remove_tag"
                    phx-value-tag={tag}
                    class="btn btn-xs btn-circle btn-ghost"
                  >
                    ✕
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>

          <div class="join w-full">
            <input
              type="text"
              value={@tag_input}
              phx-change="update_tag_input"
              name="tag_input"
              placeholder="Add a tag (press Enter)"
              class="input input-bordered join-item w-full"
              phx-keydown="add_tag"
              phx-key="Enter"
            />
            <button
              type="button"
              phx-click="add_tag"
              class="btn btn-primary join-item"
            >
              Add
            </button>
          </div>
        </div>

        <div class="divider"></div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="form-control">
            <label class="label cursor-pointer">
              <span class="label-text text-sm">Favourite</span>
              <input
                type="checkbox"
                name={@form[:favourite].name}
                checked={@form[:favourite].value}
                class="checkbox"
              />
            </label>
          </div>

          <div class="form-control">
            <label class="label cursor-pointer">
              <span class="label-text text-sm">Public</span>
              <input
                type="checkbox"
                name={@form[:public].name}
                checked={@form[:public].value}
                class="checkbox"
              />
            </label>
          </div>
        </div>

        <div class="divider"></div>

        <div class="flex gap-2">
          <button type="submit" class="btn btn-primary">
            <%= if @media_log, do: "Update Media Log", else: "Create Media Log" %>
          </button>
          <.link navigate={~p"/admin/media-logs"} class="btn btn-ghost">
            Cancel
          </.link>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = Form.validate(socket.assigns.form, params, errors: true)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("media_type_changed", %{"form" => %{"media_type" => media_type}}, socket) do
    media_type_atom = String.to_existing_atom(media_type)
    {:noreply, assign(socket, media_type: media_type_atom)}
  end

  def handle_event("update_tag_input", %{"tag_input" => value}, socket) do
    {:noreply, assign(socket, tag_input: value)}
  end

  def handle_event("add_tag", _params, socket) do
    tag = String.trim(socket.assigns.tag_input)

    if tag != "" and tag not in socket.assigns.tags do
      {:noreply, assign(socket, tags: socket.assigns.tags ++ [tag], tag_input: "")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_tag", %{"tag" => tag}, socket) do
    {:noreply, assign(socket, tags: List.delete(socket.assigns.tags, tag))}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, media_log} ->
        handle_tag_update(media_log, socket.assigns.tags)
        {:noreply, push_navigate(socket, to: ~p"/admin/media-logs")}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  def handle_event("update_search_query", %{"search_query" => value}, socket) do
    IO.inspect("update_seaerch_query call #{value}")
    {:noreply, assign(socket, search_query: value)}
  end

  def handle_event("search_media", _params, socket) do
    query = socket.assigns.search_query

    dbg(query)
    case Weakty.Media.search(socket.assigns.media_type, query) do
      {:ok, results} ->
        # dbg()
        {:noreply, assign(socket, search_results: results)}

      {:error, _reason} ->
        # dbg()
        {:noreply, assign(socket, search_results: [])}
    end
  end

  def handle_event("select_result", %{"id" => external_id}, socket) do
    result = Enum.find(socket.assigns.search_results, &(&1.external_id == external_id))

    if result do
      creators_str = result.creators |> Enum.take(3) |> Enum.join(", ")

      params =
        %{
          "title" => result.title || "",
          "creator" => creators_str,
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

  defp handle_tag_update(media_log, tags) do
    Weakty.Tags.TagManager.apply_tags(
      media_log, :media_log, tags,
      Weakty.MediaLogs.MediaLogTag, :media_log_id
    )
  end

  # Helper functions for dynamic labels
  defp creator_label(media_type) do
    case media_type do
      :book -> "Author"
      "book" -> "Author"
      :music -> "Artist"
      "music" -> "Artist"
      :movie -> "Director"
      "movie" -> "Director"
      :video_game -> "Developer"
      "video_game" -> "Developer"
      :comic -> "Author"
      "comic" -> "Author"
      _ -> "Creator"
    end
  end

  defp creator_placeholder(media_type) do
    case media_type do
      :book -> "e.g., Frank Herbert"
      "book" -> "e.g., Frank Herbert"
      :music -> "e.g., Radiohead"
      "music" -> "e.g., Radiohead"
      :movie -> "e.g., Denis Villeneuve"
      "movie" -> "e.g., Denis Villeneuve"
      :video_game -> "e.g., FromSoftware"
      "video_game" -> "e.g., FromSoftware"
      :comic -> "e.g., Alan Moore"
      "comic" -> "e.g., Alan Moore"
      _ -> "Enter creator name"
    end
  end

  defp consume_verb(media_type, tense \\ :base) do
    case {media_type, tense} do
      # Book
      {:book, :base} -> "Read"
      {"book", :base} -> "Read"
      {:book, :ing} -> "Reading"
      {"book", :ing} -> "Reading"
      {:book, :past} -> "Read"
      {"book", :past} -> "Read"
      # Comic
      {:comic, :base} -> "Read"
      {"comic", :base} -> "Read"
      {:comic, :ing} -> "Reading"
      {"comic", :ing} -> "Reading"
      {:comic, :past} -> "Read"
      {"comic", :past} -> "Read"
      # Movie
      {:movie, :base} -> "Watch"
      {"movie", :base} -> "Watch"
      {:movie, :ing} -> "Watching"
      {"movie", :ing} -> "Watching"
      {:movie, :past} -> "Watched"
      {"movie", :past} -> "Watched"
      # Music
      {:music, :base} -> "Listen"
      {"music", :base} -> "Listen"
      {:music, :ing} -> "Listening"
      {"music", :ing} -> "Listening"
      {:music, :past} -> "Listened"
      {"music", :past} -> "Listened"
      # Video Game
      {:video_game, :base} -> "Play"
      {"video_game", :base} -> "Play"
      {:video_game, :ing} -> "Playing"
      {"video_game", :ing} -> "Playing"
      {:video_game, :past} -> "Played"
      {"video_game", :past} -> "Played"
      # Default
      {_, :base} -> "Consume"
      {_, :ing} -> "Consuming"
      {_, :past} -> "Consumed"
    end
  end

  defp date_consumed_label(media_type) do
    case media_type do
      :movie -> "Date Watched"
      "movie" -> "Date Watched"
      :music -> "Date Listened"
      "music" -> "Date Listened"
      :video_game -> "Date Played"
      "video_game" -> "Date Played"
      _ -> "Date Consumed"
    end
  end

  defp search_available?(media_type) do
    media_type in [:book, :music, :movie, "book", "music", "movie"]
  end

  defp media_type_label(media_type) do
    case media_type do
      :book -> "book"
      "book" -> "book"
      :music -> "album"
      "music" -> "album"
      :movie -> "movie"
      "movie" -> "movie"
      :tv -> "TV show"
      :comic -> "comic"
      "comic" -> "comic"
      :video_game -> "game"
      "video_game" -> "game"
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
