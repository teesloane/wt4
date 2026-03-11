defmodule WeaktyWeb.AdminLive.Projects.Form do
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

    existing_tags = if project, do: Enum.map(project.tags || [], & &1.name), else: []
    existing_links = if project, do: project.links || [], else: []

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
        tags: existing_tags,
        links: existing_links,
        link_name: "",
        link_url: "",
        auto_slug: ""
      )
      |> assign(:current_path, "/admin/projects")
      |> assign(:uploaded_featured_image, project && project.featured_image)
      |> assign(:content_images, (project && project.images) || [])
      |> allow_upload(:featured_image,
        accept: ~w(.jpg .jpeg .png .gif .webp),
        max_entries: 1,
        max_file_size: 5_000_000,
        auto_upload: true,
        progress: &handle_progress/3
      )
      |> allow_upload(:content_images,
        accept: ~w(.jpg .jpeg .png .gif .webp),
        max_entries: 10,
        max_file_size: 5_000_000,
        auto_upload: true,
        progress: &handle_progress/3
      )

    {:ok, socket, layout: {WeaktyWeb.Layouts, :admin}}
  end

  defp error_to_string(:too_large), do: "File too large (max 5MB)"
  defp error_to_string(:too_many_files), do: "Too many files selected"
  defp error_to_string(:not_accepted), do: "Invalid file type (only .jpg, .jpeg, .png, .gif, .webp)"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen">
    <.form id="project-form" for={@form} phx-submit="save" phx-change="validate" class="w-full">
      <!-- Main Content Area -->
      <div class="flex-1 max-w-4xl w-full mx-auto px-8 py-8">
        <div class="flex items-center gap-4 mb-8">
          <.link navigate={~p"/admin/projects"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="w-4 h-4" />
            Projects
          </.link>
          <div class="text-sm text-base-content/70">
            <%= if @project, do: "Editing", else: "New Project" %>
          </div>
          <div class="flex-1"></div>
          <%= if @project do %>
            <.link navigate={"/projects/#{@project.slug}"} class="btn btn-ghost btn-sm">
              <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" />
              View
            </.link>
          <% end %>
          <button type="submit" form="project-form" class="btn btn-primary btn-sm">
            <%= if @project, do: "Update", else: "Publish" %>
          </button>
        </div>

        <div class="space-y-6">
          <div class="form-control">
            <input
              type="text"
              name={@form[:title].name}
              value={@form[:title].value}
              class="input input-ghost w-full text-2xl py-4 font-bold px-0 focus:outline-none"
              placeholder="Project title"
              required
            />
          </div>
          <div class="form-control">
            <textarea
              name={@form[:markdown].name}
              class="textarea textarea-ghost w-full min-h-[600px] text-lg leading-relaxed px-0 focus:outline-none"
              style="font-family: 'IBM Plex Serif', serif;"
              placeholder="Describe your project..."
              required
            ><%= @form[:markdown].value %></textarea>
          </div>
        </div>
      </div>
    </.form>

      <!-- Sidebar -->
      <div class="w-128 border-l border-base-300 bg-base-100 p-6 overflow-y-auto max-h-[calc(100vh-2rem)] sticky top-4" style="font-family: 'IBM Plex Sans', sans-serif;">
        <h2 class="text-xl font-bold mb-6">Project settings</h2>

        <div class="space-y-6">
          <!-- Slug -->
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
          </div>

          <!-- Publish Date -->
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
          </div>

          <!-- Project Dates -->
          <div class="grid grid-cols-2 gap-3 mb-4">
            <div class="form-control">
              <label class="label mb-2">
                <span class="label-text text-sm font-semibold">Start Date</span>
              </label>
              <input type="date" form="project-form" name={@form[:start_date].name} value={@form[:start_date].value} class="input input-bordered input-sm w-full text-sm" />
            </div>
            <div class="form-control">
              <label class="label mb-2">
                <span class="label-text text-sm font-semibold">End Date</span>
              </label>
              <input type="date" form="project-form" name={@form[:end_date].name} value={@form[:end_date].value} class="input input-bordered input-sm w-full text-sm" />
            </div>
          </div>

          <div class="divider"></div>

          <!-- Featured Image -->
          <div class="form-control mb-4">
            <label class="label mb-2">
              <span class="label-text text-sm font-semibold">Featured Image</span>
            </label>
            <section
              phx-drop-target={@uploads.featured_image.ref}
              class="border-2 border-dashed border-base-300 rounded-lg p-4 text-center [&.phx-drop-target-active]:border-primary [&.phx-drop-target-active]:bg-primary/5 transition-colors"
            >
              <.live_file_input form="project-form" upload={@uploads.featured_image} class="hidden" />

              <%= if @uploaded_featured_image && Enum.empty?(@uploads.featured_image.entries) do %>
                <div class="relative group mb-3">
                  <img src={@uploaded_featured_image} alt="Featured" class="w-full rounded-lg" />
                  <button
                    type="button"
                    phx-click="remove_featured_image"
                    class="absolute top-2 right-2 btn btn-error btn-xs btn-circle opacity-0 group-hover:opacity-100 transition-opacity"
                  >
                    ✕
                  </button>
                </div>
              <% end %>

              <%= for entry <- @uploads.featured_image.entries do %>
                <article class="mb-3">
                  <.live_img_preview entry={entry} class="w-full rounded-lg mb-2" />
                  <progress value={entry.progress} max="100" class="progress progress-primary w-full"></progress>
                  <div class="flex justify-between text-xs text-base-content/60 mt-1">
                    <span><%= entry.client_name %></span>
                    <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} class="text-error hover:underline">
                      Cancel
                    </button>
                  </div>
                </article>
              <% end %>

              <%= if Enum.empty?(@uploads.featured_image.entries) do %>
                <label for={@uploads.featured_image.ref} class="cursor-pointer block">
                  <.icon name="hero-photo" class="w-8 h-8 mx-auto text-base-content/30 mb-1" />
                  <span class="text-sm text-base-content/60">
                    <%= if @uploaded_featured_image, do: "Drop or click to replace", else: "Drop image here or click to upload" %>
                  </span>
                </label>
              <% end %>

              <%= for err <- upload_errors(@uploads.featured_image) do %>
                <p class="text-error text-xs mt-1"><%= error_to_string(err) %></p>
              <% end %>
            </section>
          </div>

          <!-- Content Images -->
          <div class="form-control mb-4">
            <label class="label mb-2">
              <span class="label-text text-sm font-semibold">Project Images</span>
            </label>

            <%= if length(@content_images) > 0 do %>
              <div class="grid grid-cols-2 gap-2 mb-2">
                <%= for {image_url, index} <- Enum.with_index(@content_images) do %>
                  <div class="relative group">
                    <img src={image_url} alt="Content" class="w-full h-24 object-cover rounded-lg" />
                    <div class="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity rounded-lg flex items-center justify-center gap-2">
                      <button type="button" phx-click="copy_image_markdown" phx-value-url={image_url} class="btn btn-xs btn-ghost" title="Copy markdown">
                        <.icon name="hero-clipboard" class="w-4 h-4" />
                      </button>
                      <button type="button" phx-click="remove_content_image" phx-value-index={index} class="btn btn-xs btn-error">
                        <.icon name="hero-trash" class="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>

            <section
              phx-drop-target={@uploads.content_images.ref}
              class="border-2 border-dashed border-base-300 rounded-lg p-4 text-center [&.phx-drop-target-active]:border-primary [&.phx-drop-target-active]:bg-primary/5 transition-colors"
            >
              <.live_file_input form="project-form" upload={@uploads.content_images} class="hidden" />

              <%= for entry <- @uploads.content_images.entries do %>
                <article class="mb-2 text-left">
                  <.live_img_preview entry={entry} class="w-full h-24 object-cover rounded-lg mb-1" />
                  <progress value={entry.progress} max="100" class="progress progress-primary w-full"></progress>
                  <div class="flex justify-between text-xs text-base-content/60 mt-1">
                    <span><%= entry.client_name %></span>
                    <button type="button" phx-click="cancel-content-upload" phx-value-ref={entry.ref} class="text-error hover:underline">
                      Cancel
                    </button>
                  </div>
                </article>
              <% end %>

              <%= if Enum.empty?(@uploads.content_images.entries) do %>
                <label for={@uploads.content_images.ref} class="cursor-pointer block">
                  <.icon name="hero-photo" class="w-8 h-8 mx-auto text-base-content/30 mb-1" />
                  <span class="text-sm text-base-content/60">Drop images here or click to upload</span>
                </label>
              <% end %>

              <%= for err <- upload_errors(@uploads.content_images) do %>
                <p class="text-error text-xs mt-1"><%= error_to_string(err) %></p>
              <% end %>
            </section>
            <div class="text-xs text-base-content/60 mt-1">Click thumbnails to copy markdown syntax</div>
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
                    <button type="button" phx-click="remove_link" phx-value-index={idx} class="btn btn-xs btn-circle btn-ghost">✕</button>
                  </div>
                <% end %>
              </div>
            <% end %>

            <form phx-change="update_link_fields" phx-submit="add_link" class="space-y-2">
              <input type="text" value={@link_name} name="link_name" placeholder="Link name (e.g., Demo, GitHub)" class="input input-bordered input-sm w-full text-sm" />
              <input type="url" value={@link_url} name="link_url" placeholder="https://..." class="input input-bordered input-sm w-full text-sm" />
              <button type="submit" class="btn btn-sm btn-ghost w-full">Add Link</button>
            </form>
          </div>

          <div class="divider"></div>

          <!-- Tags -->
          <div class="form-control mb-4">
            <label class="label mb-2">
              <span class="label-text text-sm font-semibold">Tags</span>
            </label>
            <.live_component module={WeaktyWeb.TagAdder} id="tag-adder" tags={@tags} />
          </div>

          <!-- Excerpt -->
          <div class="form-control mb-4">
            <label class="label mb-2">
              <span class="label-text text-sm font-semibold">Excerpt</span>
            </label>
            <textarea form="project-form" name={@form[:excerpt].name} class="textarea textarea-bordered textarea-sm w-full h-20 text-sm" placeholder="Short summary..."><%= @form[:excerpt].value %></textarea>
          </div>

          <div class="divider"></div>

          <!-- Status -->
          <div class="grid grid-cols-2 gap-3 mb-4">
            <div class="form-control">
              <label class="label mb-2">
                <span class="label-text text-sm font-semibold">Page Status</span>
              </label>
              <select form="project-form" name={@form[:status].name} class="select select-bordered select-sm w-full text-sm">
                <option value="draft" selected={@form[:status].value in [:draft, "draft"]}>Draft</option>
                <option value="published" selected={@form[:status].value in [:published, "published"]}>Published</option>
              </select>
            </div>
            <div class="form-control">
              <label class="label mb-2">
                <span class="label-text text-sm font-semibold">Project Status</span>
              </label>
              <select form="project-form" name={@form[:project_status].name} class="select select-bordered select-sm w-full text-sm">
                <option value="ongoing" selected={@form[:project_status].value in [:ongoing, "ongoing"]}>Ongoing</option>
                <option value="hiatus" selected={@form[:project_status].value in [:hiatus, "hiatus"]}>Hiatus</option>
                <option value="completed" selected={@form[:project_status].value in [:completed, "completed"]}>Completed</option>
              </select>
            </div>
          </div>

          <div class="grid grid-cols-2 gap-3 mb-4">
            <label class="label cursor-pointer justify-start gap-2 border border-base-300 rounded-lg px-3 py-2">
              <input type="hidden" form="project-form" name={@form[:public].name} value="false" />
              <input type="checkbox" form="project-form" name={@form[:public].name} value="true" checked={@form[:public].value} class="toggle toggle-sm" />
              <span class="label-text text-sm"><%= if @form[:public].value, do: "Public", else: "Private" %></span>
            </label>
            <label class="label cursor-pointer justify-start gap-2 border border-base-300 rounded-lg px-3 py-2">
              <input type="hidden" form="project-form" name={@form[:featured].name} value="false" />
              <input type="checkbox" form="project-form" name={@form[:featured].name} value="true" checked={@form[:featured].value} class="toggle toggle-sm" />
              <span class="label-text text-sm">Featured</span>
            </label>
          </div>

          <%= if @project do %>
            <div class="divider"></div>
            <button type="button" phx-click="delete_project" data-confirm="Delete this project?" class="btn btn-error btn-sm w-full">
              Delete project
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {params, auto_slug} =
      if is_nil(socket.assigns.project),
        do: maybe_auto_slug(params, socket.assigns.auto_slug),
        else: {params, socket.assigns.auto_slug}

    form = Form.validate(socket.assigns.form, params, errors: true)
    {:noreply, assign(socket, form: form, auto_slug: auto_slug)}
  end

  def handle_event("update_link_fields", %{"link_name" => name, "link_url" => url}, socket) do
    {:noreply, assign(socket, link_name: name, link_url: url)}
  end

  def handle_event("add_link", %{"link_name" => name, "link_url" => url}, socket) do
    name = String.trim(name)
    url = String.trim(url)
    if name != "" and url != "" do
      {:noreply, assign(socket, links: socket.assigns.links ++ [%{"name" => name, "link" => url}], link_name: "", link_url: "")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_link", %{"index" => index}, socket) do
    {:noreply, assign(socket, links: List.delete_at(socket.assigns.links, String.to_integer(index)))}
  end

  def handle_event("remove_featured_image", _params, socket) do
    {:noreply, assign(socket, :uploaded_featured_image, nil)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :featured_image, ref)}
  end

  def handle_event("cancel-content-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :content_images, ref)}
  end

  def handle_event("remove_content_image", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    {:noreply, assign(socket, content_images: List.delete_at(socket.assigns.content_images, index))}
  end

  def handle_event("copy_image_markdown", %{"url" => url}, socket) do
    {:noreply, push_event(socket, "copy-to-clipboard", %{text: "![](#{url})"})}
  end

  def handle_event("delete_project", _params, socket) do
    case Ash.destroy(socket.assigns.project) do
      :ok -> {:noreply, push_navigate(socket, to: ~p"/admin/projects")}
      {:ok, _} -> {:noreply, push_navigate(socket, to: ~p"/admin/projects")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to delete project")}
    end
  end

  def handle_event("save", %{"form" => params}, socket) do
    featured_image_urls =
      consume_uploaded_entries(socket, :featured_image, fn %{path: path}, entry ->
        {:ok, do_save_upload(path, entry.uuid, ext(entry))}
      end)

    featured_image = List.first(featured_image_urls) || socket.assigns.uploaded_featured_image

    new_content_image_urls =
      consume_uploaded_entries(socket, :content_images, fn %{path: path}, entry ->
        {:ok, do_save_upload(path, entry.uuid, ext(entry))}
      end)

    content_images = socket.assigns.content_images ++ new_content_image_urls

    params =
      params
      |> Map.put("featured_image", featured_image)
      |> Map.put("images", content_images)
      |> Map.put("links", socket.assigns.links)

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, project} ->
        handle_tag_update(project, socket.assigns.tags)
        {:noreply, socket |> put_flash(:info, "Saved.") |> push_navigate(to: ~p"/admin/projects")}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  def handle_progress(:featured_image, entry, socket) when entry.done? do
    {:noreply, assign(socket, :uploaded_featured_image, save_upload(socket, entry))}
  end

  def handle_progress(:content_images, entry, socket) when entry.done? do
    {:noreply, assign(socket, :content_images, socket.assigns.content_images ++ [save_upload(socket, entry)])}
  end

  def handle_progress(_name, _entry, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:tag_changed, tags}, socket) do
    {:noreply, assign(socket, :tags, tags)}
  end

  defp save_upload(socket, entry) do
    consume_uploaded_entry(socket, entry, fn %{path: path} ->
      {:ok, do_save_upload(path, entry.uuid, ext(entry))}
    end)
  end

  defp do_save_upload(source_path, uuid, file_ext) do
    dest = Path.join([:code.priv_dir(:weakty), "static", "uploads", "#{uuid}.#{file_ext}"])
    File.mkdir_p!(Path.dirname(dest))
    File.cp!(source_path, dest)
    %{"source_path" => dest, "uuid" => uuid}
    |> Weakty.Workers.GenerateThumbnails.new()
    |> Oban.insert!()
    "/uploads/#{uuid}.#{file_ext}"
  end

  defp maybe_auto_slug(params, current_auto_slug) do
    title = params["title"] || ""
    slug = params["slug"] || ""
    new_auto_slug = slugify(title)

    if slug == current_auto_slug do
      {Map.put(params, "slug", new_auto_slug), new_auto_slug}
    else
      {params, current_auto_slug}
    end
  end

  defp slugify(""), do: ""

  defp slugify(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  defp handle_tag_update(project, tags) do
    Weakty.Tags.TagManager.apply_tags(project, :project, tags, Weakty.Projects.ProjectTag, :project_id)
  end

  defp format_datetime_for_input(nil), do: ""
  defp format_datetime_for_input(%DateTime{} = datetime) do
    datetime |> DateTime.shift_zone!("Etc/UTC") |> Calendar.strftime("%Y-%m-%dT%H:%M")
  end
  defp format_datetime_for_input(_), do: ""

  defp ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    ext
  end
end
