defmodule WeaktyWeb.ProjectLive.Show do
  use WeaktyWeb, :live_view

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    project =
      Weakty.Projects.Project
      |> Ash.Query.for_read(:get_by_slug, %{slug: slug})
      |> Ash.read_one!()
      |> Ash.load!([:user, :tags])

    if connected?(socket) do
      lv = self()

      for %{"link" => url} <- project.links || [] do
        Task.start(fn ->
          image = fetch_og_image(url)
          send(lv, {:og_image, url, image})
        end)
      end
    end

    {:ok,
     socket
     |> assign(project: project)
     |> assign(page_title: project.title)
     |> assign(link_previews: %{})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container title={@project.title} size="4xl">
      <:header>
        <dl class="flex flex-wrap justify-center gap-8 mb-8 text-xs tracking-widest">
          <div class="flex flex-col items-center gap-1">
            <dt class="uppercase opacity-30">Status</dt>
            <dd class="capitalize opacity-60">
              {@project.project_status |> to_string() |> String.replace("_", " ")}
            </dd>
          </div>
          <%= if @project.start_date do %>
            <div class="flex flex-col items-center gap-1">
              <dt class="uppercase opacity-30">Timeline</dt>
              <dd class="opacity-60">
                {format_date(@project.start_date)}{if @project.end_date,
                  do: " – #{format_date(@project.end_date)}",
                  else: " – Present"}
              </dd>
            </div>
          <% end %>
        </dl>
      </:header>
      <article class="flex flex-col lg:flex-row gap-12">
        <!-- Main content -->
        <div class="flex-1 min-w-0">
          <%= if @project.featured_image do %>
            <% srcset = Weakty.ImageProcessor.srcset_for(@project.featured_image) %>
            <img
              src={@project.featured_image}
              srcset={srcset}
              sizes={srcset && "(max-width: 400px) 400px, (max-width: 800px) 800px, 1200px"}
              alt={@project.title}
              class="w-full mb-12 rounded-none"
            />
          <% end %>

          <%= if @project.excerpt do %>
            <p class="text-xl text-base-content/80 mb-8 italic">{@project.excerpt}</p>
          <% end %>

          <div class="prose prose-p:mb-0 prose-p:mt-0 mx-auto prose-p:indent-6 pb-12">
            {raw(@project.html)}
          </div>

          <%= if @project.images && length(@project.images) > 0 do %>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-8">
              <%= for image <- @project.images do %>
                <% srcset = Weakty.ImageProcessor.srcset_for(image) %>
                <img
                  src={image}
                  srcset={srcset}
                  sizes={srcset && "(max-width: 400px) 400px, (max-width: 800px) 800px, 1200px"}
                  alt="Project screenshot"
                  class="w-full rounded-none shadow"
                />
              <% end %>
            </div>
          <% end %>

          <div class="border-t border-base-200 mb-12" />

          <h3 class="uppercase averia text-center">Project Links</h3>
          <!-- Links grid -->
          <%= if @project.links && length(@project.links) > 0 do %>
            <div class="mt-12 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <%= for link <- @project.links do %>
                <% preview_image = Map.get(@link_previews, link["link"]) %>
                <a
                  href={link["link"]}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="group border border-base-300 overflow-hidden hover:border-base-content/30 transition-colors"
                >
                  <%= if preview_image do %>
                    <img src={preview_image} alt={link["name"]} class="w-full h-36 object-cover" />
                  <% else %>
                    <div class="w-full h-36 bg-base-200 flex items-center justify-center">
                      <.icon name="hero-link" class="w-6 h-6 text-base-content/20" />
                    </div>
                  <% end %>
                  <div class="px-3 py-2 flex items-center justify-between text-[12px]">
                    <span class="font-medium">{link["name"]}</span>
                    <.icon
                      name="hero-arrow-top-right-on-square"
                      class="w-3.5 h-3.5 text-base-content/40 group-hover:text-base-content/70 transition-colors"
                    />
                  </div>
                </a>
              <% end %>
            </div>
          <% end %>

          <%= if @current_user && @current_user.id == @project.user_id do %>
            <div class="border-t border-base-300 mt-16 pt-8">
              <div class="flex-col flex md:flex-row gap-3">
                <.link
                  navigate={~p"/admin/projects/#{@project.id}/edit"}
                  class="btn btn-primary btn-sm"
                >
                  Edit Project
                </.link>
                <%= if @project.status == :draft do %>
                  <button phx-click="publish" class="btn btn-success btn-sm">Publish</button>
                <% else %>
                  <button phx-click="unpublish" class="btn btn-warning btn-sm">Unpublish</button>
                <% end %>
                <button
                  phx-click="delete"
                  data-confirm="Are you sure you want to delete this project?"
                  class="btn btn-error btn-sm"
                >
                  Delete
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </article>
    </.page_container>
    """
  end

  @impl true
  def handle_info({:og_image, url, image}, socket) do
    previews = Map.put(socket.assigns.link_previews, url, image)
    {:noreply, assign(socket, link_previews: previews)}
  end

  @impl true
  def handle_event("publish", _params, socket) do
    Weakty.Projects.Project.publish_project(socket.assigns.project)

    project =
      Weakty.Projects.Project
      |> Ash.Query.for_read(:get_by_slug, %{slug: socket.assigns.project.slug})
      |> Ash.read_one!()
      |> Ash.load!([:user, :tags])

    {:noreply, assign(socket, project: project)}
  end

  def handle_event("unpublish", _params, socket) do
    Weakty.Projects.Project.unpublish_project(socket.assigns.project)

    project =
      Weakty.Projects.Project
      |> Ash.Query.for_read(:get_by_slug, %{slug: socket.assigns.project.slug})
      |> Ash.read_one!()
      |> Ash.load!([:user, :tags])

    {:noreply, assign(socket, project: project)}
  end

  def handle_event("delete", _params, socket) do
    Ash.destroy!(socket.assigns.project)
    {:noreply, push_navigate(socket, to: ~p"/projects")}
  end

  defp fetch_og_image(url) do
    case Req.get(url, headers: [{"user-agent", "Mozilla/5.0"}], receive_timeout: 5_000) do
      {:ok, %{body: body}} when is_binary(body) -> parse_og_image(body)
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp parse_og_image(html) do
    # Match either attribute order: property=... content=... or content=... property=...
    patterns = [
      ~r/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i,
      ~r/<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i
    ]

    Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, html) do
        [_, image_url] -> image_url
        _ -> nil
      end
    end)
  end

  defp format_date(date) do
    Calendar.strftime(date, "%B %Y")
  end
end
