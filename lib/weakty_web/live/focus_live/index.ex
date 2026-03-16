defmodule WeaktyWeb.FocusLive.Index do
  use WeaktyWeb, :live_view

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  alias Weakty.FocusSessions.FocusSession

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Weakty.PubSub, "focus:#{user.id}")
    end

    active_session = get_active_session(user.id) |> maybe_auto_advance(user.id)
    recent_sessions = get_recent_sessions(user.id)
    projects = Ash.read!(Weakty.Projects.Project, authorize?: false)
    categories = get_categories(user.id)

    # /focus page ticks for display only — transitions are owned by FocusTimerLive
    if connected?(socket) && active_session && active_session.status in [:active, :on_break] do
      schedule_tick()
    end

    {:ok,
     socket
     |> assign(:page_title, "Focus")
     |> assign(:active_session, active_session)
     |> assign(:remaining_seconds, compute_remaining(active_session))
     |> assign(:recent_sessions, recent_sessions)
     |> assign(:projects, projects)
     |> assign(:categories, categories)
     |> assign(:form_duration, 25)
     |> assign(:show_notes, false)
     |> assign(:notes_session_id, nil)}
  end

  @impl true
  def handle_event("start_session", params, socket) do
    user = socket.assigns.current_user
    duration = String.to_integer(params["duration"] || "25")
    project_id = if params["project_id"] != "", do: params["project_id"], else: nil
    category = if params["category"] != "", do: params["category"], else: nil

    attrs = %{
      title: params["title"],
      category: category,
      project_id: project_id,
      duration_minutes: duration,
      break_duration_minutes: 5,
      status: :active,
      started_at: DateTime.utc_now(),
      user_id: user.id
    }

    case FocusSession
         |> Ash.Changeset.for_create(:create, attrs)
         |> Ash.create(authorize?: false) do
      {:ok, session} ->
        broadcast_focus_change(user.id)
        schedule_tick()

        {:noreply,
         socket
         |> assign(:active_session, session)
         |> assign(:remaining_seconds, session.duration_minutes * 60)
         |> assign(:categories, get_categories(user.id))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to start session")}
    end
  end

  def handle_event("abandon_session", _params, socket) do
    session = socket.assigns.active_session

    case session |> Ash.Changeset.for_update(:abandon, %{}) |> Ash.update(authorize?: false) do
      {:ok, _} ->
        broadcast_focus_change(session.user_id)

        {:noreply,
         socket
         |> assign(:active_session, nil)
         |> assign(:remaining_seconds, 0)
         |> assign(:show_notes, true)
         |> assign(:notes_session_id, session.id)
         |> load_recent()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to abandon session")}
    end
  end

  def handle_event("skip_break", _params, socket) do
    session = socket.assigns.active_session

    case session
         |> Ash.Changeset.for_update(:complete_break, %{})
         |> Ash.update(authorize?: false) do
      {:ok, _} ->
        broadcast_focus_change(session.user_id)

        {:noreply,
         socket
         |> assign(:active_session, nil)
         |> assign(:remaining_seconds, 0)
         |> load_recent()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to skip break")}
    end
  end

  def handle_event("save_notes", %{"notes" => notes}, socket) do
    case socket.assigns.notes_session_id do
      nil ->
        {:noreply, assign(socket, :show_notes, false)}

      session_id ->
        session = Ash.get!(FocusSession, session_id, authorize?: false)

        case session
             |> Ash.Changeset.for_update(:update_notes, %{notes: notes})
             |> Ash.update(authorize?: false) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:show_notes, false)
             |> assign(:notes_session_id, nil)
             |> load_recent()}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to save notes")}
        end
    end
  end

  def handle_event("dismiss_notes", _params, socket) do
    {:noreply, socket |> assign(:show_notes, false) |> assign(:notes_session_id, nil)}
  end

  def handle_event("delete_session", %{"id" => id}, socket) do
    session = Ash.get!(FocusSession, id, authorize?: false)

    case Ash.destroy(session, authorize?: false) do
      :ok -> {:noreply, load_recent(socket)}
      {:ok, _} -> {:noreply, load_recent(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to delete")}
    end
  end

  @impl true
  # Display-only tick — never transitions session state (FocusTimerLive owns that)
  def handle_info(:tick, socket) do
    session = socket.assigns.active_session

    case session do
      %{status: status} when status in [:active, :on_break] ->
        schedule_tick()
        {:noreply, assign(socket, :remaining_seconds, compute_remaining(session))}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_info(:session_changed, socket) do
    user = socket.assigns.current_user
    active_session = get_active_session(user.id)

    if connected?(socket) && active_session && active_session.status in [:active, :on_break] do
      schedule_tick()
    end

    {:noreply,
     socket
     |> assign(:active_session, active_session)
     |> assign(:remaining_seconds, compute_remaining(active_session))
     |> load_recent()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-12">
      <div class="mb-8">
        <h1 class="text-3xl font-bold averia">Focus</h1>
        <p class="text-base-content/60 mt-1">Pomodoro timer</p>
      </div>

      <%= cond do %>
        <% @active_session && @active_session.status == :active -> %>
          <.active_timer session={@active_session} remaining={@remaining_seconds} />
        <% @active_session && @active_session.status == :on_break -> %>
          <.break_timer session={@active_session} remaining={@remaining_seconds} />
        <% true -> %>
          <.new_session_form
            duration={@form_duration}
            projects={@projects}
            categories={@categories}
          />
      <% end %>

      <%= if @show_notes do %>
        <div class="mt-6 card bg-base-200">
          <div class="card-body p-5">
            <h3 class="font-semibold mb-2">Add notes for this session?</h3>
            <form phx-submit="save_notes">
              <textarea
                name="notes"
                rows="3"
                class="textarea textarea-bordered w-full text-sm"
                placeholder="What did you accomplish? Any reflections..."
              ></textarea>
              <div class="flex gap-2 mt-3">
                <button type="submit" class="btn btn-sm btn-primary">Save notes</button>
                <button type="button" phx-click="dismiss_notes" class="btn btn-sm btn-ghost">
                  Skip
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <%= if @recent_sessions != [] do %>
        <div class="mt-10">
          <h2 class="text-sm font-semibold uppercase tracking-wider text-base-content/50 mb-4">
            Recent Sessions
          </h2>
          <div class="space-y-2">
            <%= for session <- @recent_sessions do %>
              <.session_row session={session} />
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp new_session_form(assigns) do
    ~H"""
    <div class="card bg-base-200">
      <div class="card-body p-6">
        <h2 class="card-title text-lg mb-4">New Session</h2>
        <form phx-submit="start_session" class="space-y-4">
          <div class="form-control">
            <label class="label"><span class="label-text">What are you working on?</span></label>
            <input
              type="text"
              name="title"
              placeholder="Session title..."
              class="input input-bordered"
              required
              autofocus
            />
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div class="form-control">
              <label class="label"><span class="label-text">Category</span></label>
              <input
                type="text"
                name="category"
                placeholder="e.g. Admin, Writing..."
                class="input input-bordered input-sm"
                list="category-suggestions"
                autocomplete="off"
              />
              <datalist id="category-suggestions">
                <%= for cat <- @categories do %>
                  <option value={cat} />
                <% end %>
              </datalist>
            </div>

            <div class="form-control">
              <label class="label"><span class="label-text">Project (optional)</span></label>
              <select name="project_id" class="select select-bordered select-sm">
                <option value="">— no project —</option>
                <%= for project <- @projects do %>
                  <option value={project.id}>{project.title}</option>
                <% end %>
              </select>
            </div>
          </div>

          <div class="form-control">
            <label class="label"><span class="label-text">Duration</span></label>
            <div class="flex gap-2 flex-wrap">
              <%= for mins <- [15, 25, 30, 45, 60] do %>
                <label class="cursor-pointer">
                  <input
                    type="radio"
                    name="duration"
                    value={mins}
                    class="hidden peer"
                    checked={@duration == mins}
                  />
                  <span class="btn btn-sm peer-checked:btn-primary">{mins} min</span>
                </label>
              <% end %>
            </div>
          </div>

          <button type="submit" class="btn btn-primary w-full mt-2">
            <.icon name="hero-play" class="w-4 h-4" /> Start Session
          </button>
        </form>
      </div>
    </div>
    """
  end

  defp active_timer(assigns) do
    ~H"""
    <div class="card bg-base-200">
      <div class="card-body p-8 items-center text-center">
        <div class="flex items-center gap-2 mb-2">
          <span class="w-2 h-2 rounded-full bg-success animate-pulse"></span>
          <span class="text-xs font-semibold uppercase tracking-wider text-success">Focusing</span>
        </div>

        <h2 class="text-xl font-bold">{@session.title}</h2>

        <%= if @session.category || @session.project_id do %>
          <p class="text-base-content/60 text-sm mt-1">
            <%= if @session.category, do: @session.category %>
            <%= if @session.category && @session.project, do: " · " %>
            <%= if @session.project, do: @session.project.title %>
          </p>
        <% end %>

        <div class="my-8 font-mono text-7xl font-bold tabular-nums tracking-tight">
          {format_time(@remaining)}
        </div>

        <div class="flex gap-3">
          <button
            phx-click="abandon_session"
            phx-confirm="Abandon this session?"
            class="btn btn-ghost btn-sm text-error"
          >
            <.icon name="hero-x-mark" class="w-4 h-4" /> Abandon
          </button>
          <button phx-click="skip_break" class="btn btn-success btn-sm">
            <.icon name="hero-check" class="w-4 h-4" /> Done early
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp break_timer(assigns) do
    ~H"""
    <div class="card bg-base-200">
      <div class="card-body p-8 items-center text-center">
        <div class="text-3xl mb-2">☕</div>
        <h2 class="text-xl font-bold">Break Time</h2>
        <p class="text-base-content/60 text-sm">Great work on "{@session.title}"</p>

        <div class="my-8 font-mono text-7xl font-bold tabular-nums tracking-tight text-info">
          {format_time(@remaining)}
        </div>

        <button phx-click="skip_break" class="btn btn-ghost btn-sm">
          Skip break
        </button>
      </div>
    </div>
    """
  end

  defp session_row(assigns) do
    ~H"""
    <div class="flex items-center gap-3 p-3 rounded-lg bg-base-200 hover:bg-base-300 transition-colors group">
      <div class={[
        "w-2 h-2 rounded-full shrink-0",
        case @session.status do
          :completed -> "bg-success"
          :abandoned -> "bg-error"
          _ -> "bg-base-content/30"
        end
      ]}>
      </div>

      <div class="flex-1 min-w-0">
        <div class="font-medium text-sm truncate">{@session.title}</div>
        <div class="text-xs text-base-content/50 flex gap-2 mt-0.5 flex-wrap">
          <%= if @session.category do %>
            <span class="badge badge-xs badge-ghost">{@session.category}</span>
          <% end %>
          <%= if @session.project do %>
            <span class="badge badge-xs badge-ghost">{@session.project.title}</span>
          <% end %>
          <span>{@session.duration_minutes} min</span>
          <span>{Calendar.strftime(@session.inserted_at, "%b %d")}</span>
        </div>
        <%= if @session.notes do %>
          <div class="text-xs text-base-content/50 mt-1 truncate italic">{@session.notes}</div>
        <% end %>
      </div>

      <button
        phx-click="delete_session"
        phx-value-id={@session.id}
        phx-confirm="Delete this session?"
        class="btn btn-ghost btn-xs text-base-content/20 hover:text-error opacity-0 group-hover:opacity-100 transition-opacity"
      >
        <.icon name="hero-trash" class="w-3 h-3" />
      </button>
    </div>
    """
  end

  # Helpers

  defp get_active_session(user_id) do
    require Ash.Query

    Weakty.FocusSessions.FocusSession
    |> Ash.Query.filter(user_id == ^user_id and (status == :active or status == :on_break))
    |> Ash.Query.sort(started_at: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false, load: [:project])
    |> List.first()
  end

  defp get_recent_sessions(user_id) do
    require Ash.Query

    Weakty.FocusSessions.FocusSession
    |> Ash.Query.filter(user_id == ^user_id and (status == :completed or status == :abandoned))
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(20)
    |> Ash.read!(authorize?: false, load: [:project])
  end

  defp get_categories(user_id) do
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

  defp load_recent(socket) do
    assign(socket, :recent_sessions, get_recent_sessions(socket.assigns.current_user.id))
  end

  defp compute_remaining(nil), do: 0

  defp compute_remaining(%{
         status: :active,
         started_at: started_at,
         duration_minutes: duration_minutes
       })
       when not is_nil(started_at) do
    end_time = DateTime.add(started_at, duration_minutes * 60, :second)
    max(0, DateTime.diff(end_time, DateTime.utc_now(), :second))
  end

  defp compute_remaining(%{
         status: :on_break,
         break_started_at: break_started_at,
         break_duration_minutes: break_duration_minutes
       })
       when not is_nil(break_started_at) do
    end_time = DateTime.add(break_started_at, break_duration_minutes * 60, :second)
    max(0, DateTime.diff(end_time, DateTime.utc_now(), :second))
  end

  defp compute_remaining(_), do: 0

  defp format_time(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    :io_lib.format("~2..0B:~2..0B", [minutes, secs]) |> IO.iodata_to_binary()
  end

  defp schedule_tick, do: Process.send_after(self(), :tick, 1000)

  defp broadcast_focus_change(user_id) do
    Phoenix.PubSub.broadcast(Weakty.PubSub, "focus:#{user_id}", :session_changed)
  end

  defp maybe_auto_advance(nil, _user_id), do: nil

  defp maybe_auto_advance(session, user_id) do
    case session.status do
      :active when not is_nil(session.started_at) ->
        end_time = DateTime.add(session.started_at, session.duration_minutes * 60, :second)

        if DateTime.compare(DateTime.utc_now(), end_time) == :gt do
          {:ok, updated} =
            session
            |> Ash.Changeset.for_update(:start_break, %{})
            |> Ash.update(authorize?: false)

          broadcast_focus_change(user_id)
          Ash.load!(updated, [:project], authorize?: false)
        else
          session
        end

      :on_break when not is_nil(session.break_started_at) ->
        end_time =
          DateTime.add(session.break_started_at, session.break_duration_minutes * 60, :second)

        if DateTime.compare(DateTime.utc_now(), end_time) == :gt do
          {:ok, _} =
            session
            |> Ash.Changeset.for_update(:complete_break, %{})
            |> Ash.update(authorize?: false)

          broadcast_focus_change(user_id)
          nil
        else
          session
        end

      _ ->
        session
    end
  end
end
