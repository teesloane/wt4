defmodule WeaktyWeb.FocusTimerLive do
  use WeaktyWeb, :live_view

  # Always rendered via live_render in root.html.heex.
  # Owns the server-side tick loop and session transitions.
  # FocusLive.Index only handles user interactions and display.

  @impl true
  def mount(_params, session, socket) do
    socket = AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)
    user = socket.assigns[:current_user]

    active_session =
      if user do
        get_active_session(user.id) |> maybe_auto_advance(user.id)
      else
        nil
      end

    if connected?(socket) && user do
      Phoenix.PubSub.subscribe(Weakty.PubSub, "focus:#{user.id}")
    end

    if connected?(socket) && active_session && active_session.status in [:active, :on_break] do
      schedule_tick()
    end

    {:ok,
     socket
     |> assign(:active_session, active_session)
     |> assign(:remaining_seconds, compute_remaining(active_session)),
     layout: false}
  end

  @impl true
  def handle_info(:tick, socket) do
    session = socket.assigns.active_session

    case session do
      %{status: status} when status in [:active, :on_break] ->
        remaining = compute_remaining(session)

        if remaining <= 0 do
          handle_timer_complete(socket, session)
        else
          schedule_tick()
          {:noreply, assign(socket, :remaining_seconds, remaining)}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_info(:session_changed, socket) do
    user = socket.assigns[:current_user]

    if user do
      active_session = get_active_session(user.id)

      if active_session && active_session.status in [:active, :on_break] do
        schedule_tick()
      end

      {:noreply,
       socket
       |> assign(:active_session, active_session)
       |> assign(:remaining_seconds, compute_remaining(active_session))}
    else
      {:noreply, socket}
    end
  end

  defp handle_timer_complete(socket, session) do
    # Re-fetch to guard against race with FocusLive.Index user actions
    case Ash.get(Weakty.FocusSessions.FocusSession, session.id, authorize?: false) do
      {:ok, fresh} ->
        case fresh.status do
          :active ->
            case fresh
                 |> Ash.Changeset.for_update(:start_break, %{})
                 |> Ash.update(authorize?: false) do
              {:ok, updated} ->
                broadcast_focus_change(fresh.user_id)
                schedule_tick()

                {:noreply,
                 socket
                 |> assign(:active_session, updated)
                 |> assign(:remaining_seconds, updated.break_duration_minutes * 60)
                 |> push_event("focus:complete", %{type: "pomodoro", title: fresh.title})}

              {:error, _} ->
                {:noreply, socket}
            end

          :on_break ->
            case fresh
                 |> Ash.Changeset.for_update(:complete_break, %{})
                 |> Ash.update(authorize?: false) do
              {:ok, _} ->
                broadcast_focus_change(fresh.user_id)

                {:noreply,
                 socket
                 |> assign(:active_session, nil)
                 |> assign(:remaining_seconds, 0)
                 |> push_event("focus:complete", %{type: "break"})}

              {:error, _} ->
                {:noreply, socket}
            end

          _ ->
            # Already transitioned by user action
            {:noreply, socket |> assign(:active_session, nil) |> assign(:remaining_seconds, 0)}
        end

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="focus-timer-widget" phx-hook="FocusNotify">
      <%= if @active_session && @active_session.status in [:active, :on_break] do %>
        <.link navigate="/focus">
          <div class={[
            "fixed bottom-4 left-4 z-50 rounded-2xl shadow-lg border px-4 py-3 text-sm backdrop-blur-sm cursor-pointer hover:shadow-xl transition-shadow",
            if(@active_session.status == :active,
              do: "bg-base-100/95 border-success/40",
              else: "bg-base-100/95 border-info/40"
            )
          ]}>
            <div class="flex items-center gap-2 mb-1">
              <span class={[
                "w-2 h-2 rounded-full animate-pulse",
                if(@active_session.status == :active, do: "bg-success", else: "bg-info")
              ]}>
              </span>
              <span class={[
                "text-xs font-semibold uppercase tracking-wider",
                if(@active_session.status == :active, do: "text-success", else: "text-info")
              ]}>
                {if @active_session.status == :active, do: "Focusing", else: "Break"}
              </span>
            </div>

            <div class="font-mono text-xl font-bold tabular-nums">
              {format_time(@remaining_seconds)}
            </div>

            <div class="text-xs text-base-content/60 mt-0.5 max-w-[140px] truncate">
              {@active_session.title}
            </div>

            <%= if @active_session.category do %>
              <div class="text-xs text-base-content/40 truncate">{@active_session.category}</div>
            <% end %>
          </div>
        </.link>
      <% end %>
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
    |> Ash.read!(authorize?: false)
    |> List.first()
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
          updated
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
