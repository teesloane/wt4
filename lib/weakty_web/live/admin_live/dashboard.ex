defmodule WeaktyWeb.AdminLive.Dashboard do
  use WeaktyWeb, :live_view

  import WeaktyWeb.AdminComponents

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Weakty.PubSub, "focus:#{user.id}")
    end

    active_session = get_focus_session(user.id)

    if connected?(socket) && active_session && active_session.status in [:active, :on_break] do
      schedule_focus_tick()
    end

    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign(:current_path, "/admin")
     |> assign(:quick_search_query, "")
     |> assign(:quick_search_results, [])
     |> assign(:quick_added, [])
     |> assign(:focus_session, active_session)
     |> assign(:focus_remaining, compute_focus_remaining(active_session))
     |> assign(:focus_title, "")
     |> assign(:focus_category, "")
     |> assign(:focus_project_id, "")
     |> assign(:focus_projects, Ash.read!(Weakty.Projects.Project, authorize?: false))
     |> assign(:focus_categories, get_focus_categories(user.id))
     |> load_stats(), layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_header title="Dashboard" subtitle="Overview of your content">
      <:actions>
        <div class="flex gap-2">
          <.link navigate="/admin/posts/new" class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="w-4 h-4" /> New Post
          </.link>
          <.link navigate="/admin/til/new" class="btn btn-sm">
            <.icon name="hero-plus" class="w-4 h-4" /> New TIL
          </.link>
          <.link navigate="/admin/quotes/new" class="btn btn-sm">
            <.icon name="hero-plus" class="w-4 h-4" /> New Quote
          </.link>
        </div>
      </:actions>
    </.admin_header>

    <div class="p-8 space-y-8">
      <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <.stat_card label="Total Posts" value={@stats.total_posts} />
        <.stat_card label="Published" value={@stats.published_posts} />
        <.stat_card label="Drafts" value={@stats.draft_posts} />
        <.stat_card label="Links" value={@stats.total_links} />
        <.stat_card label="TILs" value={@stats.total_tils} />
        <.stat_card label="Quotes" value={@stats.total_quotes} />
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
      <!-- Quick Focus Timer -->
      <div class="card bg-base-200">
        <div class="card-body p-6">
          <h2 class="card-title text-base mb-4">
            <.icon name="hero-clock" class="w-4 h-4" /> Focus Timer
          </h2>

          <%= if @focus_session && @focus_session.status in [:active, :on_break] do %>
            <div class="flex items-center justify-between">
              <div>
                <div class="flex items-center gap-2 mb-1">
                  <span class={[
                    "w-2 h-2 rounded-full animate-pulse",
                    if(@focus_session.status == :active, do: "bg-success", else: "bg-info")
                  ]}>
                  </span>
                  <span class={[
                    "text-xs font-semibold uppercase tracking-wider",
                    if(@focus_session.status == :active, do: "text-success", else: "text-info")
                  ]}>
                    {if @focus_session.status == :active, do: "Focusing", else: "Break"}
                  </span>
                </div>
                <div class="font-semibold text-sm truncate max-w-[180px]">
                  {@focus_session.title}
                </div>
                <%= if @focus_session.category do %>
                  <div class="text-xs text-base-content/50">{@focus_session.category}</div>
                <% end %>
              </div>

              <div class="text-right">
                <div class="font-mono text-2xl font-bold tabular-nums">
                  {format_focus_time(@focus_remaining)}
                </div>
                <div class="flex gap-1 mt-2 justify-end">
                  <.link navigate="/focus" class="btn btn-xs btn-ghost">
                    Open
                  </.link>
                </div>
              </div>
            </div>
          <% else %>
            <form phx-submit="focus_start" class="space-y-3">
              <input
                type="text"
                name="title"
                value={@focus_title}
                placeholder="What are you working on?"
                class="input input-bordered input-sm w-full"
                required
              />

              <div class="flex gap-2">
                <input
                  type="text"
                  name="category"
                  value={@focus_category}
                  placeholder="Category (e.g. Admin)"
                  class="input input-bordered input-sm flex-1"
                  list="focus-category-suggestions"
                  autocomplete="off"
                />
                <datalist id="focus-category-suggestions">
                  <%= for cat <- @focus_categories do %>
                    <option value={cat} />
                  <% end %>
                </datalist>

                <select name="project_id" class="select select-bordered select-sm w-40">
                  <option value="">No project</option>
                  <%= for project <- @focus_projects do %>
                    <option value={project.id}>{project.title}</option>
                  <% end %>
                </select>
              </div>

              <button type="submit" class="btn btn-sm btn-primary w-full">
                <.icon name="hero-play" class="w-3 h-3" /> Start 25 min session
              </button>
            </form>
          <% end %>
        </div>
      </div>

      <!-- Quick Add Album -->
      <div class="card bg-base-200">
        <div class="card-body p-6">
          <h2 class="card-title text-base mb-4">Quick Add Album</h2>

          <form phx-submit="quick_search" phx-change="quick_search_change" class="join w-full max-w-md">
            <input
              type="text"
              name="q"
              value={@quick_search_query}
              placeholder="Search for an album..."
              class="input input-bordered input-sm join-item flex-1"
              autocomplete="off"
            />
            <button type="submit" class="btn btn-sm btn-secondary join-item">Search</button>
          </form>

          <%= if @quick_search_results != [] do %>
            <div class="space-y-1 mt-4 max-h-72 overflow-y-auto">
              <%= for result <- @quick_search_results do %>
                <div class="flex items-center gap-3 p-2 rounded hover:bg-base-300">
                  <%= if result.cover_url do %>
                    <img
                      src={result.cover_url}
                      alt={result.title}
                      class="w-10 h-10 object-cover rounded shrink-0"
                    />
                  <% else %>
                    <div class="w-10 h-10 bg-base-300 rounded shrink-0" />
                  <% end %>
                  <div class="flex-1 min-w-0">
                    <div class="font-medium text-xs truncate">{result.title}</div>
                    <div class="text-xs text-base-content/60 truncate">
                      {Enum.join(result.creators, ", ")}
                    </div>
                  </div>
                  <button
                    type="button"
                    phx-click={JS.push("quick_add_album", value: %{id: result.external_id})}
                    class="btn btn-xs btn-primary shrink-0"
                  >
                    Add
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>

          <%= if @quick_added != [] do %>
            <div class="mt-4 space-y-1">
              <%= for item <- @quick_added do %>
                <div class="flex items-center gap-2 text-sm text-success">
                  <.icon name="hero-check-circle" class="w-4 h-4 shrink-0" />
                  <span class="font-medium">{item.title}</span>
                  <%= if item.creator != "" do %>
                    <span class="opacity-60">— {item.creator}</span>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_info({:quick_cover_downloaded, {id, local_path}}, socket) do
    case Ash.get(Weakty.MediaLogs.MediaLog, id, authorize?: false) do
      {:ok, media_log} ->
        media_log
        |> Ash.Changeset.for_update(:update, %{thumbnail_url: local_path})
        |> Ash.update(authorize?: false)

      _ ->
        :ok
    end

    {:noreply, socket}
  end

  def handle_info(:focus_tick, socket) do
    session = socket.assigns.focus_session

    case session do
      %{status: status} when status in [:active, :on_break] ->
        schedule_focus_tick()
        {:noreply, assign(socket, :focus_remaining, compute_focus_remaining(session))}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_info(:session_changed, socket) do
    user = socket.assigns.current_user
    active_session = get_focus_session(user.id)

    if active_session && active_session.status in [:active, :on_break] do
      schedule_focus_tick()
    end

    {:noreply,
     socket
     |> assign(:focus_session, active_session)
     |> assign(:focus_remaining, compute_focus_remaining(active_session))}
  end

  def handle_event("focus_start", params, socket) do
    user = socket.assigns.current_user
    project_id = if params["project_id"] != "", do: params["project_id"], else: nil
    category = if params["category"] != "", do: params["category"], else: nil

    attrs = %{
      title: params["title"],
      category: category,
      project_id: project_id,
      duration_minutes: 25,
      break_duration_minutes: 5,
      status: :active,
      started_at: DateTime.utc_now(),
      user_id: user.id
    }

    case Weakty.FocusSessions.FocusSession
         |> Ash.Changeset.for_create(:create, attrs)
         |> Ash.create(authorize?: false) do
      {:ok, session} ->
        Phoenix.PubSub.broadcast(Weakty.PubSub, "focus:#{user.id}", :session_changed)
        schedule_focus_tick()

        {:noreply,
         socket
         |> assign(:focus_session, session)
         |> assign(:focus_remaining, session.duration_minutes * 60)
         |> assign(:focus_categories, get_focus_categories(user.id))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to start session")}
    end
  end

  @impl true
  def handle_event("quick_search_change", %{"q" => q}, socket) do
    {:noreply, assign(socket, :quick_search_query, q)}
  end

  def handle_event("quick_search", _params, socket) do
    case Weakty.Media.search(:music, socket.assigns.quick_search_query) do
      {:ok, results} -> {:noreply, assign(socket, :quick_search_results, results)}
      {:error, _} -> {:noreply, assign(socket, :quick_search_results, [])}
    end
  end

  def handle_event("quick_add_album", %{"id" => external_id}, socket) do
    result = Enum.find(socket.assigns.quick_search_results, &(&1.external_id == external_id))

    if result do
      creator = result.creators |> Enum.take(3) |> Enum.join(", ")

      attrs =
        %{
          title: result.title,
          creator: creator,
          media_type: :music,
          status: :consumed,
          date_consumed: Date.utc_today(),
          thumbnail_url: result.cover_url,
          public: true,
          user_id: socket.assigns.current_user.id
        }
        |> maybe_put_date_published(result.year)

      case Weakty.MediaLogs.MediaLog
           |> Ash.Changeset.for_create(:create, attrs)
           |> Ash.create(authorize?: false) do
        {:ok, media_log} ->
          if result.cover_url do
            lv = self()

            Task.start(fn ->
              case Weakty.ImageDownloader.download(result.cover_url, "media") do
                {:ok, local_path} -> send(lv, {:quick_cover_downloaded, {media_log.id, local_path}})
                _ -> :ok
              end
            end)
          end

          added = [%{title: result.title, creator: creator} | socket.assigns.quick_added] |> Enum.take(5)
          {:noreply, assign(socket, quick_search_results: [], quick_search_query: "", quick_added: added)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to add album")}
      end
    else
      {:noreply, socket}
    end
  end

  defp load_stats(socket) do
    require Ash.Query

    all_posts = Weakty.Posts.Post.list_posts!()
    posts = Enum.filter(all_posts, &(&1.post_type in [:post, :update, :page]))
    published_posts = Enum.filter(posts, &(&1.status == :published))
    draft_posts = Enum.filter(posts, &(&1.status == :draft))
    tils = Enum.filter(all_posts, &(&1.post_type == :til))
    quotes = Enum.filter(all_posts, &(&1.post_type == :quote))
    links = Ash.read!(Weakty.Links.Link)

    socket
    |> assign(:stats, %{
      total_posts: length(posts),
      published_posts: length(published_posts),
      draft_posts: length(draft_posts),
      total_links: length(links),
      total_tils: length(tils),
      total_quotes: length(quotes)
    })
  end

  defp maybe_put_date_published(attrs, year) when is_binary(year) do
    date =
      cond do
        String.match?(year, ~r/^\d{4}-\d{2}-\d{2}$/) -> Date.from_iso8601!(year)
        String.match?(year, ~r/^\d{4}-\d{2}$/) -> Date.from_iso8601!("#{year}-01")
        String.match?(year, ~r/^\d{4}$/) -> Date.from_iso8601!("#{year}-01-01")
        true -> nil
      end

    if date, do: Map.put(attrs, :date_published, date), else: attrs
  end

  defp maybe_put_date_published(attrs, _), do: attrs

  defp get_focus_session(user_id) do
    require Ash.Query

    Weakty.FocusSessions.FocusSession
    |> Ash.Query.filter(user_id == ^user_id and (status == :active or status == :on_break))
    |> Ash.Query.sort(started_at: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> List.first()
  end

  defp get_focus_categories(user_id) do
    require Ash.Query

    Weakty.FocusSessions.FocusSession
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.Query.select([:category])
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.category)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp compute_focus_remaining(nil), do: 0

  defp compute_focus_remaining(%{
         status: :active,
         started_at: started_at,
         duration_minutes: duration_minutes
       })
       when not is_nil(started_at) do
    end_time = DateTime.add(started_at, duration_minutes * 60, :second)
    max(0, DateTime.diff(end_time, DateTime.utc_now(), :second))
  end

  defp compute_focus_remaining(%{
         status: :on_break,
         break_started_at: break_started_at,
         break_duration_minutes: break_duration_minutes
       })
       when not is_nil(break_started_at) do
    end_time = DateTime.add(break_started_at, break_duration_minutes * 60, :second)
    max(0, DateTime.diff(end_time, DateTime.utc_now(), :second))
  end

  defp compute_focus_remaining(_), do: 0

  defp format_focus_time(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    :io_lib.format("~2..0B:~2..0B", [minutes, secs]) |> IO.iodata_to_binary()
  end

  defp schedule_focus_tick, do: Process.send_after(self(), :focus_tick, 1000)
end
