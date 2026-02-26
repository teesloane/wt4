defmodule WeaktyWeb.AdminLive.Jobs.Index do
  use WeaktyWeb, :live_view
  import Ecto.Query
  import WeaktyWeb.AdminComponents

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @states ~w(all available scheduled executing retryable completed discarded cancelled)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_path, "/admin/jobs")
     |> assign(:state_filter, "all")
     |> assign(:states, @states)
     |> assign(:workers, load_workers())
     |> load_jobs(),
     layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    state_filter = params |> Map.get("state", "all") |> then(&if(&1 in @states, do: &1, else: "all"))
    {:noreply, socket |> assign(:state_filter, state_filter) |> load_jobs()}
  end

  @impl true
  def handle_event("run_worker", %{"worker" => worker}, socket) do
    module = Module.concat([worker])
    {:ok, _} = %{} |> module.new() |> Weakty.ObanJob.insert()
    {:noreply, socket |> put_flash(:info, "#{short_worker(worker)} enqueued.") |> load_jobs()}
  end

  def handle_event("run_again", %{"id" => id}, socket) do
    job = Weakty.Repo.get!(Weakty.ObanJob, id)
    module = Module.concat([job.worker])
    {:ok, _} = job.args |> module.new() |> Weakty.ObanJob.insert()
    {:noreply, socket |> put_flash(:info, "Job enqueued.") |> load_jobs()}
  end

  def handle_event("cancel", %{"id" => id}, socket) do
    Weakty.ObanJob.cancel(String.to_integer(id))
    {:noreply, socket |> put_flash(:info, "Job cancelled.") |> load_jobs()}
  end

  def handle_event("refresh", _params, socket) do
    {:noreply, load_jobs(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_header title="Jobs" subtitle={"#{length(@jobs)} in history"}>
      <:actions>
        <button phx-click="refresh" class="btn btn-ghost btn-sm">
          <.icon name="hero-arrow-path" class="w-4 h-4" />
          Refresh
        </button>
      </:actions>
    </.admin_header>

    <div class="p-8 space-y-8">
      <div>
        <h2 class="text-sm font-semibold text-base-content/50 uppercase tracking-wide mb-3">Workers</h2>
        <div class="flex flex-col gap-2">

          <%= for {schedule, worker} <- @workers do %>
            <div class="flex items-center justify-between bg-base-200 rounded-lg px-4 py-3">
              <div>
                <span class="font-mono text-sm font-medium"><%= short_worker(worker) %></span>
                <span class="text-xs text-base-content/50 ml-3">cron: <%= schedule %></span>
              </div>
              <button
                phx-click="run_worker"
                phx-value-worker={worker}
                class="btn btn-sm btn-ghost"
              >
                <.icon name="hero-play" class="w-4 h-4" />
                Run now
              </button>
            </div>
          <% end %>
        </div>
      </div>

      <div>
        <h2 class="text-sm font-semibold text-base-content/50 uppercase tracking-wide mb-3">History</h2>

        <div class="mb-4 flex gap-2 flex-wrap">
          <%= for state <- @states do %>
            <.link
              patch={~p"/admin/jobs?state=#{state}"}
              class={["btn btn-sm", if(@state_filter == state, do: "btn-active", else: "btn-ghost")]}
            >
              <%= String.capitalize(state) %>
            </.link>
          <% end %>
        </div>

        <%= if @jobs == [] do %>
          <p class="text-sm text-base-content/50">No job runs yet.</p>
        <% else %>
          <div class="overflow-x-auto">
            <table class="table table-sm font-sans">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Worker</th>
                  <th>State</th>
                  <th>Attempts</th>
                  <th>Ran at</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <%= for job <- @jobs do %>
                  <tr class="align-top">
                    <td class="text-base-content/40 text-xs pt-3"><%= job.id %></td>
                    <td class="pt-3">
                      <span class="font-mono text-xs"><%= short_worker(job.worker) %></span>
                    </td>
                    <td class="pt-3">
                      <span class={"badge badge-sm #{state_color(job.state)}"}>
                        <%= job.state %>
                      </span>
                    </td>
                    <td class="text-xs text-base-content/60 pt-3">
                      <%= job.attempt %>/<%= job.max_attempts %>
                    </td>
                    <td class="text-xs text-base-content/60 pt-3">
                      <%= format_dt(job.scheduled_at) %>
                    </td>
                    <td class="pt-2">
                      <button
                        phx-click="run_again"
                        phx-value-id={job.id}
                        class="btn btn-xs btn-ghost"
                      >
                        <.icon name="hero-arrow-path" class="w-3 h-3" />
                        Run again
                      </button>
                      <%= if job.state in ["available", "scheduled", "retryable"] do %>
                        <button
                          phx-click="cancel"
                          phx-value-id={job.id}
                          class="btn btn-xs btn-ghost text-error"
                        >
                          Cancel
                        </button>
                      <% end %>
                      <%= if job.errors != [] do %>
                        <details class="mt-1">
                          <summary class="text-xs text-error cursor-pointer select-none">
                            <%= length(job.errors) %> error(s)
                          </summary>
                          <pre class="mt-1 text-xs bg-error/10 text-error rounded p-2 max-w-sm overflow-auto max-h-40 whitespace-pre-wrap"><%= List.last(job.errors)["error"] %></pre>
                        </details>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp load_workers do
    Application.get_env(:weakty, Oban, [])
    |> Keyword.get(:plugins, [])
    |> Enum.find_value([], fn
      {Oban.Plugins.Cron, opts} -> Keyword.get(opts, :crontab, [])
      _ -> false
    end)
    |> Enum.map(fn {schedule, worker} ->
      worker_str = worker |> to_string() |> String.replace_prefix("Elixir.", "")
      {schedule, worker_str}
    end)
  end

  defp load_jobs(socket) do
    state = socket.assigns[:state_filter] || "all"

    query =
      from j in Weakty.ObanJob,
        order_by: [desc: j.id],
        limit: 200

    query =
      if state == "all", do: query, else: from(j in query, where: j.state == ^state)

    assign(socket, :jobs, Weakty.Repo.all(query))
  end

  defp short_worker(worker), do: worker |> String.split(".") |> List.last()

  defp format_dt(nil), do: "—"
  defp format_dt(%DateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y %H:%M")
  defp format_dt(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y %H:%M")

  defp state_color("completed"), do: "badge-success"
  defp state_color("executing"), do: "badge-warning"
  defp state_color("available"), do: "badge-info"
  defp state_color("scheduled"), do: "badge-ghost"
  defp state_color("retryable"), do: "badge-warning"
  defp state_color("discarded"), do: "badge-error"
  defp state_color("cancelled"), do: "badge-ghost"
  defp state_color(_), do: "badge-ghost"
end
