defmodule WeaktyWeb.ProjectLive.Show do
  use WeaktyWeb, :live_view

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    project = Weakty.Projects.Project
      |> Ash.Query.for_read(:get_by_slug, %{slug: slug})
      |> Ash.read_one!()
      |> Ash.load!([:user, :tags])

    {:ok, assign(socket, project: project)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <article class="mx-auto max-w-4xl px-4 py-8">
      <div class="mb-8">
        <h1 class="text-4xl mt-8 font-bold mb-4"><%= @project.title %></h1>

        <div class="flex flex-wrap items-center gap-3 mb-6">
          <span class={"badge " <> project_status_color(@project.project_status)}>
            <%= String.capitalize(to_string(@project.project_status)) %>
          </span>
          <%= if @project.featured do %>
            <span class="badge badge-primary">Featured</span>
          <% end %>
          <%= if @project.start_date do %>
            <span class="text-base-content/60">
              <%= format_date_range(@project.start_date, @project.end_date) %>
            </span>
          <% end %>
        </div>

        <%= if @project.tags && length(@project.tags) > 0 do %>
          <div class="flex flex-wrap gap-2 mb-6">
            <%= for tag <- @project.tags do %>
              <span class="badge badge-outline"><%= tag.name %></span>
            <% end %>
          </div>
        <% end %>

        <%= if @project.links && length(@project.links) > 0 do %>
          <div class="flex flex-wrap gap-2 mb-6">
            <%= for link <- @project.links do %>
              <a href={link["link"]} target="_blank" rel="noopener noreferrer" class="btn btn-sm btn-outline">
                <%= link["name"] %>
                <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4 ml-1" />
              </a>
            <% end %>
          </div>
        <% end %>

        <%= if @project.featured_image do %>
          <img
            src={@project.featured_image}
            alt={@project.title}
            class="w-full rounded-lg shadow-lg mb-8"
          />
        <% end %>

        <%= if @project.excerpt do %>
          <p class="text-xl text-base-content/80 mb-8 italic"><%= @project.excerpt %></p>
        <% end %>
      </div>

      <div class="prose max-w-none">
        <%= raw(@project.html) %>
      </div>

      <%= if @project.images && length(@project.images) > 0 do %>
        <div class="divider my-8"></div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <%= for image <- @project.images do %>
            <img src={image} alt="Project screenshot" class="w-full rounded-lg shadow" />
          <% end %>
        </div>
      <% end %>

      <%= if @current_user && @current_user.id == @project.user_id do %>
        <div class="divider my-8"></div>
        <div class="flex gap-2">
          <.link navigate={~p"/admin/projects/#{@project.slug}/edit"} class="btn btn-primary">
            Edit Project
          </.link>
          <%= if @project.status == :draft do %>
            <button
              phx-click="publish"
              class="btn btn-success"
            >
              Publish
            </button>
          <% else %>
            <button
              phx-click="unpublish"
              class="btn btn-warning"
            >
              Unpublish
            </button>
          <% end %>
          <button
            phx-click="delete"
            data-confirm="Are you sure you want to delete this project?"
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
    Weakty.Projects.Project.publish_project(socket.assigns.project)
    project = Weakty.Projects.Project
      |> Ash.Query.for_read(:get_by_slug, %{slug: socket.assigns.project.slug})
      |> Ash.read_one!()
      |> Ash.load!([:user, :tags])
    {:noreply, assign(socket, project: project)}
  end

  def handle_event("unpublish", _params, socket) do
    Weakty.Projects.Project.unpublish_project(socket.assigns.project)
    project = Weakty.Projects.Project
      |> Ash.Query.for_read(:get_by_slug, %{slug: socket.assigns.project.slug})
      |> Ash.read_one!()
      |> Ash.load!([:user, :tags])
    {:noreply, assign(socket, project: project)}
  end

  def handle_event("delete", _params, socket) do
    Ash.destroy!(socket.assigns.project)
    {:noreply, push_navigate(socket, to: ~p"/projects")}
  end

  defp project_status_color(status) do
    case status do
      :ongoing -> "badge-info"
      :hiatus -> "badge-warning"
      :completed -> "badge-success"
      _ -> "badge-ghost"
    end
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
