defmodule WeaktyWeb.AdminLive.Projects.Index do
  use WeaktyWeb, :live_view

  import WeaktyWeb.AdminComponents

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Projects")
     |> assign(:current_path, "/admin/projects")
     |> assign(:filter, "all")
     |> load_projects(), layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    filter = Map.get(params, "filter", "all")

    {:noreply,
     socket
     |> assign(:filter, filter)
     |> load_projects()}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    project = Ash.get!(Weakty.Projects.Project, id)

    case Weakty.Projects.Project.delete_project(project) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project deleted successfully")
         |> load_projects()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete project")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_header title="Projects" subtitle={"#{length(@projects)} project#{if length(@projects) != 1, do: "s"}"}>
      <:actions>
        <.link navigate="/admin/projects/new" class="btn btn-primary">
          <.icon name="hero-plus" class="w-4 h-4" />
          New Project
        </.link>
      </:actions>
    </.admin_header>

    <div class="p-8">
      <div class="mb-4 flex gap-2">
        <.link
          patch={~p"/admin/projects?filter=all"}
          class={["btn btn-sm", if(@filter == "all", do: "btn-active", else: "btn-ghost")]}
        >
          All Projects
        </.link>
        <.link
          patch={~p"/admin/projects?filter=published"}
          class={["btn btn-sm", if(@filter == "published", do: "btn-active", else: "btn-ghost")]}
        >
          Published
        </.link>
        <.link
          patch={~p"/admin/projects?filter=drafts"}
          class={["btn btn-sm", if(@filter == "drafts", do: "btn-active", else: "btn-ghost")]}
        >
          Drafts
        </.link>
        <.link
          patch={~p"/admin/projects?filter=ongoing"}
          class={["btn btn-sm", if(@filter == "ongoing", do: "btn-active", else: "btn-ghost")]}
        >
          Ongoing
        </.link>
        <.link
          patch={~p"/admin/projects?filter=completed"}
          class={["btn btn-sm", if(@filter == "completed", do: "btn-active", else: "btn-ghost")]}
        >
          Completed
        </.link>
      </div>

      <%= if @projects == [] do %>
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body items-center text-center">
            <.icon name="hero-briefcase" class="w-16 h-16 text-base-content/30" />
            <h2 class="card-title">No projects yet</h2>
            <p class="text-base-content/70">Create your first project to get started</p>
            <.link navigate="/admin/projects/new" class="btn btn-primary mt-4">
              <.icon name="hero-plus" class="w-4 h-4" />
              Create Project
            </.link>
          </div>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Title</th>
                <th>Excerpt</th>
                <th>Status</th>
                <th>Project Status</th>
                <th>Published</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for project <- @projects do %>
                <tr class="hover cursor-pointer" phx-click={JS.navigate(~p"/admin/projects/#{project.slug}/edit")}>
                  <td>
                    <div class="flex items-center gap-3">
                      <%= if project.featured_image do %>
                        <div class="avatar">
                          <div class="mask mask-squircle w-12 h-12">
                            <img src={project.featured_image} alt={project.title} />
                          </div>
                        </div>
                      <% end %>
                      <div>
                        <div class="font-bold"><%= project.title %></div>
                        <%= if project.tags && project.tags != [] do %>
                          <div class="text-sm opacity-50 flex gap-1 mt-1">
                            <%= for tag <- Enum.take(project.tags, 3) do %>
                              <span class="badge badge-xs"><%= tag.name %></span>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </td>
                  <td>
                    <div class="text-sm text-base-content/70 max-w-md truncate">
                      <%= project.excerpt %>
                    </div>
                  </td>
                  <td>
                    <.status_badge status={project.status} />
                  </td>
                  <td>
                    <.project_status_badge status={project.project_status} />
                  </td>
                  <td>
                    <%= if project.published_at do %>
                      <div class="text-sm">
                        <%= Calendar.strftime(project.published_at, "%b %d, %Y") %>
                      </div>
                    <% else %>
                      <span class="text-base-content/50">-</span>
                    <% end %>
                  </td>
                  <td onclick="event.stopPropagation()">
                    <div class="flex gap-2">
                      <.link
                        navigate={~p"/admin/projects/#{project.slug}/edit"}
                        class="btn btn-ghost btn-xs"
                        title="Edit"
                      >
                        <.icon name="hero-pencil" class="w-4 h-4" />
                      </.link>
                      <.link
                        navigate={~p"/projects/#{project.slug}"}
                        class="btn btn-ghost btn-xs"
                        title="View"
                      >
                        <.icon name="hero-eye" class="w-4 h-4" />
                      </.link>
                      <button
                        phx-click="delete"
                        phx-value-id={project.id}
                        data-confirm="Are you sure you want to delete this project?"
                        class="btn btn-ghost btn-xs text-error"
                        title="Delete"
                      >
                        <.icon name="hero-trash" class="w-4 h-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  defp load_projects(socket) do
    projects =
      case socket.assigns.filter do
        "published" -> Weakty.Projects.Project.list_published_projects!()
        "drafts" -> Weakty.Projects.Project.list_drafts!()
        "ongoing" -> Weakty.Projects.Project.list_ongoing!()
        "completed" -> Weakty.Projects.Project.list_completed!()
        _ -> Weakty.Projects.Project.list_projects!()
      end

    # Load tags relationship
    projects = Ash.load!(projects, :tags)

    assign(socket, :projects, projects)
  end

  defp project_status_badge(assigns) do
    color = case assigns.status do
      :ongoing -> "badge-info"
      :hiatus -> "badge-warning"
      :completed -> "badge-success"
      _ -> "badge-ghost"
    end

    assigns = assign(assigns, :color, color)

    ~H"""
    <span class={"badge #{@color} badge-sm"}>
      <%= String.capitalize(to_string(@status)) %>
    </span>
    """
  end
end
