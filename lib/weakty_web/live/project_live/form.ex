defmodule WeaktyWeb.ProjectLive.Form do
  use WeaktyWeb, :live_view
  alias AshPhoenix.Form

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(params, _session, socket) do
    project =
      case params["id"] do
        nil -> nil
        id ->
          Weakty.Projects.Project
          |> Ash.get!(id)
          |> Ash.load!(:tags)
      end

    # Extract existing data if editing
    existing_tags = if project, do: Enum.map(project.tags || [], & &1.name), else: []
    existing_links = if project, do: project.links || [], else: []
    existing_images = if project, do: project.images || [], else: []

    form =
      if project do
        Form.for_update(project, :update, domain: Weakty.Projects, forms: [auto?: false])
      else
        Form.for_create(Weakty.Projects.Project, :create,
          domain: Weakty.Projects,
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

    socket =
      socket
      |> assign(
        form: form,
        project: project,
        preview: false,
        tags: existing_tags,
        tag_input: "",
        links: existing_links,
        link_name: "",
        link_url: "",
        images: existing_images,
        image_url: ""
      )
      |> assign(:current_path, "/admin/projects")
      |> allow_upload(:featured_image,
        accept: ~w(.jpg .jpeg .png .gif .webp),
        max_entries: 1,
        max_file_size: 5_000_000
      )
      |> allow_upload(:content_images,
        accept: ~w(.jpg .jpeg .png .gif .webp),
        max_entries: 10,
        max_file_size: 5_000_000
      )

    {:ok, socket, layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen">
      <!-- Main Content Area -->
      <div class="flex-1 max-w-4xl mx-auto px-8 py-8">
        <div class="flex items-center gap-4 mb-8">
          <.link navigate={~p"/admin/projects"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="w-4 h-4" />
            Projects
          </.link>
          <div class="text-sm text-base-content/70">
            <%= if @project, do: "Draft - Saved", else: "New Project" %>
          </div>
          <div class="flex-1"></div>
          <button
            phx-click="toggle_preview"
            class="btn btn-ghost btn-sm"
          >
            Preview
          </button>
          <button type="submit" form="project-form" class="btn btn-primary btn-sm">
            <%= if @project, do: "Update", else: "Publish" %>
          </button>
        </div>

        <%= if @preview do %>
          <div class="prose max-w-none">
            <h1><%= @form[:title].value %></h1>
            <%= if @form[:featured_image].value do %>
              <img src={@form[:featured_image].value} alt={@form[:title].value} class="w-full rounded-lg" />
            <% end %>
            <%= if @form[:excerpt].value do %>
              <p class="lead"><%= @form[:excerpt].value %></p>
            <% end %>
            <div>
              <%= raw(render_markdown(@form[:markdown].value || "")) %>
            </div>
          </div>
        <% else %>
          <.form
            id="project-form"
            for={@form}
            phx-submit="save"
            phx-change="validate"
            class="space-y-6"
          >
            <!-- Title -->
            <div class="form-control">
              <input
                type="text"
                name={@form[:title].name}
                value={@form[:title].value}
                class="input input-ghost w-full text-4xl font-bold px-0 focus:outline-none"
                placeholder="Project title"
                required
              />
            </div>

            <!-- Content -->
            <div class="form-control">
              <textarea
                name={@form[:markdown].name}
                class="textarea textarea-ghost w-full min-h-[600px] text-lg leading-relaxed px-0 focus:outline-none"
                style="font-family: 'IBM Plex Serif', serif;"
                placeholder="Describe your project..."
                required
              ><%= @form[:markdown].value %></textarea>
            </div>
          </.form>
        <% end %>
      </div>

      <!-- Sidebar -->
      <div class="w-96 border-l border-base-300 bg-base-100 p-6 overflow-y-auto max-h-[calc(100vh-2rem)] sticky top-4" style="font-family: 'IBM Plex Sans', sans-serif;">
        <h2 class="text-xl font-bold mb-6">Project settings</h2>

        <div class="space-y-6">
          <!-- Post URL (Slug) -->
          <div class="form-control mb-4">
            <label class="label mb-2">
              <span class="label-text text-sm font-semibold">Project URL</span>
            </label>
            <div class="flex items-center gap-2">
              <.icon name="hero-link" class="w-4 h-4 text-base-content/50" />
              <input
                type="text"
                form="project-form"
                name={@form[:slug].name}
                value={@form[:slug].value}
                class="input input-bordered input-sm flex-1 text-sm"
                placeholder="url-friendly-slug"
              />
            </div>
            <div class="text-xs text-base-content/60 mt-1">
              weakty.com/projects/<%= @form[:slug].value || "project-slug" %>/
            </div>
          </div>

          <!-- Published At -->
          <div class="form-control mb-4">
            <label class="label mb-2">
              <span class="label-text text-sm font-semibold">Publish date</span>
            </label>
            <input
              type="datetime-local"
              form="project-form"
              name={@form[:published_at].name}
              value={format_datetime_for_input(@form[:published_at].value)}
              class="input input-bordered input-sm w-full text-sm"
            />
            <div class="text-xs text-base-content/60 mt-1">
              Leave empty to auto-set when publishing
            </div>
          </div>

          <!-- Project Dates -->
          <div class="grid grid-cols-2 gap-3 mb-4">
            <div class="form-control">
              <label class="label mb-2">
                <span class="label-text text-sm font-semibold">Start Date</span>
              </label>
              <input
                type="date"
                form="project-form"
                name={@form[:start_date].name}
                value={@form[:start_date].value}
                class="input input-bordered input-sm w-full text-sm"
              />
            </div>

            <div class="form-control">
              <label class="label mb-2">
                <span class="label-text text-sm font-semibold">End Date</span>
              </label>
              <input
                type="date"
                form="project-form"
                name={@form[:end_date].name}
                value={@form[:end_date].value}
                class="input input-bordered input-sm w-full text-sm"
              />
            </div>
          </div>
          <div class="text-xs text-base-content/60 -mt-2 mb-4">
            Leave end date empty for ongoing projects
          </div>

          <div class="divider"></div>

          <!-- Links -->
          <div class="form-control mb-4">
            <label class="label mb-2">
              <span class="label-text text-sm font-semibold">Project Links</span>
            </label>

            <%= if length(@links) > 0 do %>
              <div class="space-y-2 mb-3">
                <%= for {link, idx} <- Enum.with_index(@links) do %>
                  <div class="flex items-center gap-2 p-2 bg-base-200 rounded">
                    <div class="flex-1">
                      <div class="text-sm font-medium"><%= link["name"] %></div>
                      <div class="text-xs text-base-content/70 truncate"><%= link["link"] %></div>
                    </div>
                    <button
                      type="button"
                      phx-click="remove_link"
                      phx-value-index={idx}
                      class="btn btn-xs btn-circle btn-ghost"
                    >
                      ✕
                    </button>
                  </div>
                <% end %>
              </div>
            <% end %>

            <div class="space-y-2">
              <input
                type="text"
                value={@link_name}
                phx-keyup="update_link_name"
                name="link_name"
                placeholder="Link name (e.g., Demo, GitHub)"
                class="input input-bordered input-sm w-full text-sm"
              />
              <input
                type="url"
                value={@link_url}
                phx-keyup="update_link_url"
                name="link_url"
                placeholder="https://..."
                class="input input-bordered input-sm w-full text-sm"
              />
              <button
                type="button"
                phx-click="add_link"
                class="btn btn-sm btn-ghost w-full"
              >
                Add Link
              </button>
            </div>
          </div>

          <div class="divider"></div>

          <!-- Images -->
          <div class="form-control mb-4">
            <label class="label mb-2">
              <span class="label-text text-sm font-semibold">Project Images</span>
            </label>

            <%= if length(@images) > 0 do %>
              <div class="grid grid-cols-2 gap-2 mb-2">
                <%= for {image_url, index} <- Enum.with_index(@images) do %>
                  <div class="relative group">
                    <img src={image_url} alt="Content" class="w-full h-24 object-cover rounded-lg" />
                    <div class="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity rounded-lg flex items-center justify-center gap-2">
                      <button
                        type="button"
                        phx-click="copy_image_markdown"
                        phx-value-url={image_url}
                        class="btn btn-xs btn-ghost"
                        title="Copy markdown"
                      >
                        <.icon name="hero-clipboard" class="w-4 h-4" />
                      </button>
                      <button
                        type="button"
                        phx-click="remove_image"
                        phx-value-index={index}
                        class="btn btn-xs btn-error"
                      >
                        <.icon name="hero-trash" class="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>

            <label for={@uploads.content_images.ref} class="btn btn-sm btn-ghost w-full cursor-pointer">
              <.icon name="hero-photo" class="w-4 h-4 mr-2" />
              Upload Images
            </label>
            <.live_file_input upload={@uploads.content_images} class="hidden" />

            <%= for entry <- @uploads.content_images.entries do %>
              <div class="text-xs text-base-content/60 mt-1">
                <%= entry.client_name %> (<%= Float.round(entry.progress, 0) %>%)
              </div>
            <% end %>

            <div class="text-xs text-base-content/60 mt-1">
              Click image thumbnails to copy markdown syntax
            </div>
          </div>

          <div class="divider"></div>

          <!-- Tags -->
          <div class="form-control mb-4">
            <label class="label mb-2">
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
                placeholder="Add a tag"
                class="input input-bordered input-sm join-item flex-1 text-sm"
                phx-keydown="add_tag"
                phx-key="Enter"
              />
              <button
                type="button"
                phx-click="add_tag"
                class="btn btn-sm btn-ghost join-item"
              >
                Add
              </button>
            </div>
          </div>

          <div class="divider"></div>

          <!-- Featured Image -->
          <div class="form-control mb-4">
            <label class="label mb-2">
              <span class="label-text text-sm font-semibold">Featured Image</span>
            </label>
            <%= if @form[:featured_image].value do %>
              <div class="mb-2 relative group">
                <img src={@form[:featured_image].value} alt="Featured" class="w-full rounded-lg" />
                <button
                  type="button"
                  phx-click="remove_featured_image"
                  class="absolute top-2 right-2 btn btn-error btn-xs btn-circle opacity-0 group-hover:opacity-100 transition-opacity"
                >
                  ✕
                </button>
              </div>
            <% end %>

            <div class="space-y-2">
              <label for={@uploads.featured_image.ref} class="btn btn-sm btn-ghost w-full cursor-pointer">
                <.icon name="hero-photo" class="w-4 h-4 mr-2" />
                <%= if @form[:featured_image].value, do: "Change Image", else: "Upload Image" %>
              </label>
              <.live_file_input upload={@uploads.featured_image} class="hidden" />

              <%= for entry <- @uploads.featured_image.entries do %>
                <div class="text-xs text-base-content/60">
                  Uploading: <%= entry.client_name %> (<%= Float.round(entry.progress, 0) %>%)
                </div>
              <% end %>
            </div>

            <!-- Hidden input to preserve existing value -->
            <input type="hidden" form="project-form" name={@form[:featured_image].name} value={@form[:featured_image].value} />
          </div>

          <!-- Excerpt -->
          <div class="form-control mb-4">
            <label class="label mb-2">
              <span class="label-text text-sm font-semibold">Excerpt</span>
            </label>
            <textarea
              form="project-form"
              name={@form[:excerpt].name}
              class="textarea textarea-bordered textarea-sm w-full h-20 text-sm"
              placeholder="Short summary of your project..."
            ><%= @form[:excerpt].value %></textarea>
          </div>

          <div class="divider"></div>

          <!-- Status -->
          <div class="grid grid-cols-2 gap-3 mb-4">
            <div class="form-control">
              <label class="label mb-2">
                <span class="label-text text-sm font-semibold">Page Status</span>
              </label>
              <select
                form="project-form"
                name={@form[:status].name}
                class="select select-bordered select-sm w-full text-sm"
              >
                <option value="draft" selected={@form[:status].value == :draft || @form[:status].value == "draft"}>
                  Draft
                </option>
                <option value="published" selected={@form[:status].value == :published || @form[:status].value == "published"}>
                  Published
                </option>
              </select>
            </div>

            <div class="form-control">
              <label class="label mb-2">
                <span class="label-text text-sm font-semibold">Project Status</span>
              </label>
              <select
                form="project-form"
                name={@form[:project_status].name}
                class="select select-bordered select-sm w-full text-sm"
              >
                <option value="ongoing" selected={@form[:project_status].value == :ongoing || @form[:project_status].value == "ongoing"}>
                  Ongoing
                </option>
                <option value="hiatus" selected={@form[:project_status].value == :hiatus || @form[:project_status].value == "hiatus"}>
                  Hiatus
                </option>
                <option value="completed" selected={@form[:project_status].value == :completed || @form[:project_status].value == "completed"}>
                  Completed
                </option>
              </select>
            </div>
          </div>

          <!-- Access and Featured -->
          <div class="grid grid-cols-2 gap-3 mb-4">
            <label class="label cursor-pointer justify-start gap-2 border border-base-300 rounded-lg px-3 py-2">
              <input
                type="checkbox"
                form="project-form"
                name={@form[:public].name}
                checked={@form[:public].value}
                class="toggle toggle-sm"
              />
              <span class="label-text text-sm"><%= if @form[:public].value, do: "Public", else: "Private" %></span>
            </label>

            <label class="label cursor-pointer justify-start gap-2 border border-base-300 rounded-lg px-3 py-2">
              <input
                type="checkbox"
                form="project-form"
                name={@form[:featured].name}
                checked={@form[:featured].value}
                class="toggle toggle-sm"
              />
              <span class="label-text text-sm">Featured</span>
            </label>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = Form.validate(socket.assigns.form, params, errors: true)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("toggle_preview", _params, socket) do
    {:noreply, assign(socket, preview: !socket.assigns.preview)}
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

  def handle_event("update_link_name", %{"value" => value}, socket) do
    {:noreply, assign(socket, link_name: value)}
  end

  def handle_event("update_link_url", %{"value" => value}, socket) do
    {:noreply, assign(socket, link_url: value)}
  end

  def handle_event("add_link", _params, socket) do
    name = String.trim(socket.assigns.link_name)
    url = String.trim(socket.assigns.link_url)

    if name != "" and url != "" do
      new_link = %{"name" => name, "link" => url}
      {:noreply, assign(socket, links: socket.assigns.links ++ [new_link], link_name: "", link_url: "")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_link", %{"index" => index}, socket) do
    index = String.to_integer(index)
    {:noreply, assign(socket, links: List.delete_at(socket.assigns.links, index))}
  end

  def handle_event("update_image_url", %{"value" => value}, socket) do
    {:noreply, assign(socket, image_url: value)}
  end

  def handle_event("add_image", _params, socket) do
    url = String.trim(socket.assigns.image_url)

    if url != "" do
      {:noreply, assign(socket, images: socket.assigns.images ++ [url], image_url: "")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_image", %{"index" => index}, socket) do
    index = String.to_integer(index)
    {:noreply, assign(socket, images: List.delete_at(socket.assigns.images, index))}
  end

  def handle_event("remove_featured_image", _params, socket) do
    form = Form.validate(socket.assigns.form, %{"featured_image" => nil})
    {:noreply, assign(socket, form: to_form(form))}
  end

  def handle_event("copy_image_markdown", %{"url" => url}, socket) do
    {:noreply, push_event(socket, "copy-to-clipboard", %{text: "![](#{url})"})}
  end

  @impl true
  def handle_progress(:featured_image, entry, socket) when entry.done? do
    uploaded_files =
      consume_uploaded_entries(socket, :featured_image, fn %{path: path}, entry ->
        dest = Path.join(["priv", "static", "uploads", "#{entry.uuid}.#{ext(entry)}"])
        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)
        "/uploads/#{entry.uuid}.#{ext(entry)}"
      end)

    case uploaded_files do
      [url | _] ->
        form = Form.validate(socket.assigns.form, %{"featured_image" => url})
        {:noreply, assign(socket, form: to_form(form))}

      [] ->
        {:noreply, socket}
    end
  end

  def handle_progress(:content_images, entry, socket) when entry.done? do
    uploaded_files =
      consume_uploaded_entries(socket, :content_images, fn %{path: path}, entry ->
        dest = Path.join(["priv", "static", "uploads", "#{entry.uuid}.#{ext(entry)}"])
        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)
        "/uploads/#{entry.uuid}.#{ext(entry)}"
      end)

    images = socket.assigns.images ++ uploaded_files
    {:noreply, assign(socket, images: images)}
  end

  def handle_progress(_name, _entry, socket), do: {:noreply, socket}

  def handle_event("save", %{"form" => params}, socket) do
    # Add links and images to params
    params = params
      |> Map.put("links", socket.assigns.links)
      |> Map.put("images", socket.assigns.images)

    result = Form.submit(socket.assigns.form, params: params)

    case result do
      {:ok, project} ->
        handle_tag_update(project, socket.assigns.tags)
        {:noreply, push_navigate(socket, to: ~p"/admin/projects")}

      {:error, form} ->
        project_from_error =
          case form.source do
            %{resource: %Weakty.Projects.Project{} = project} -> project
            %{data: %Weakty.Projects.Project{} = project} -> project
            %Ash.Changeset{data: %Weakty.Projects.Project{} = project} -> project
            _ -> nil
          end

        cond do
          project_from_error && project_from_error.id ->
            handle_tag_update(project_from_error, socket.assigns.tags)
            {:noreply, push_navigate(socket, to: ~p"/admin/projects")}

          socket.assigns.project ->
            project = Ash.get!(Weakty.Projects.Project, socket.assigns.project.id)
            handle_tag_update(project, socket.assigns.tags)
            {:noreply, push_navigate(socket, to: ~p"/admin/projects")}

          true ->
            {:noreply, assign(socket, form: to_form(form))}
        end
    end
  end

  defp handle_tag_update(project, tags) do
    if length(tags) > 0 do
      tags_param = Enum.map(tags, &%{name: &1})

      project
      |> Ash.Changeset.for_update(:update, %{}, domain: Weakty.Projects)
      |> Ash.Changeset.set_argument(:tags, tags_param)
      |> Ash.update(domain: Weakty.Projects)
    end
  end

  defp render_markdown(nil), do: ""
  defp render_markdown(""), do: ""

  defp render_markdown(markdown) do
    case MDEx.to_html(markdown) do
      {:ok, html} -> html
      {:error, _} -> "<p>Error rendering markdown</p>"
    end
  end

  defp format_datetime_for_input(nil), do: ""

  defp format_datetime_for_input(%DateTime{} = datetime) do
    datetime
    |> DateTime.shift_zone!("Etc/UTC")
    |> Calendar.strftime("%Y-%m-%dT%H:%M")
  end

  defp format_datetime_for_input(_), do: ""

  defp ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    ext
  end
end
