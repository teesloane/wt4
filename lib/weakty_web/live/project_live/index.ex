defmodule WeaktyWeb.ProjectLive.Index do
  use WeaktyWeb, :live_view
  require Ash.Query

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_projects(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl px-4 py-8">
      <div class="mb-8">
        <div class="flex justify-between items-center">
          <h1 class="text-3xl font-bold">Projects</h1>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <%= if Enum.empty?(@projects) do %>
          <div class="col-span-full card bg-base-200">
            <div class="card-body text-center">
              <p class="text-base-content/60">No projects found</p>
            </div>
          </div>
        <% else %>
          <%= for project <- @projects do %>
            <.link navigate={~p"/projects/#{project.slug}"}>
              <div class="bg-base-100 shadow-none hover:shadow-sm transition-shadow">
                <%= if project.featured_image do %>
                  <figure>
                    <img
                      src={project.featured_image}
                      alt={project.title}
                      class="w-full h-48 object-cover"
                    />
                  </figure>
                <% end %>
                <div class="border border-base-300 p-4">
                  <h2 class="card-title text-xl mb-0">
                    {project.title}
                  </h2>
                  <%= if project.excerpt do %>
                    <p class="text-base-content/70">{project.excerpt}</p>
                  <% end %>

                  <div :if={project.featured} class="flex flex-wrap gap-2 mt-2">
                    <%= if project.featured do %>
                      <span class="badge badge-sm badge-primary">Featured</span>
                    <% end %>
                  </div>

                  <div class="text-sm text-base-content/60">
                    <%= if project.start_date do %>
                      {format_date_range(project.start_date, project.end_date)}
                    <% end %>
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

  defp load_projects(socket) do
    assign(socket, projects: Weakty.Projects.Project.list_published_projects!())
  end

  defp format_date_range(start_date, nil) do
    "#{format_date(start_date)} - Present"
  end

  defp format_date_range(start_date, end_date) do
    "#{format_date(start_date)} - #{format_date(end_date)}"
  end

  defp format_date(date) do
    Calendar.strftime(date, "%B %Y")
  end
end
