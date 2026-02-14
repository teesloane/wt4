defmodule WeaktyWeb.AdminLive.Posts.Form do
  use WeaktyWeb, :live_view
  alias AshPhoenix.Form

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(params, _session, socket) do
    post =
      case params["id"] do
        nil -> nil
        id ->
          Weakty.Posts.Post
          |> Ash.get!(id)
          |> Ash.load!(:tags)
      end

    # Extract existing tag names if editing
    existing_tags = if post, do: Enum.map(post.tags || [], & &1.name), else: []

    form =
      if post do
        Form.for_update(post, :update, domain: Weakty.Posts, forms: [auto?: false])
      else
        Form.for_create(Weakty.Posts.Post, :create,
          domain: Weakty.Posts,
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
      |> assign(form: form, post: post, preview: false, tags: existing_tags, tag_input: "", auto_slug: "")
      |> assign(:current_path, "/admin/posts")
      |> assign(:content_images, (post && post.content_images) || [])
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

  defp error_to_string(:too_large), do: "File too large (max 5MB)"
  defp error_to_string(:too_many_files), do: "Too many files selected"
  defp error_to_string(:not_accepted), do: "Invalid file type (only .jpg, .jpeg, .png, .gif, .webp)"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen">
      <!-- Main Content Area -->
      <div class="flex-1 max-w-4xl mx-auto px-8 py-8">
        <div class="flex items-center gap-4 mb-8">
          <.link navigate={~p"/admin/posts"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="w-4 h-4" />
            Posts
          </.link>
          <div class="text-sm text-base-content/70">
            <%= if @post, do: "Draft - Saved (not implemented)", else: "New Post" %>
          </div>
          <div class="flex-1"></div>
          <button
            phx-click="toggle_preview"
            class="btn btn-ghost btn-sm"
          >
            Preview
          </button>
          <button type="submit" form="post-form" class="btn btn-primary btn-sm">
            <%= if @post, do: "Update", else: "Publish" %>
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
            id="post-form"
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
                class="input input-ghost w-full text-2xl py-4 font-bold px-0 focus:outline-none"
                placeholder="Post title"
                required
              />
            </div>

            <!-- Content -->
            <div class="form-control">
              <textarea
                name={@form[:markdown].name}
                class="textarea textarea-ghost w-full min-h-[600px] text-lg leading-relaxed px-0 focus:outline-none"
                style="font-family: 'IBM Plex Serif', serif;"
                placeholder="Begin writing your post..."
                required
              ><%= @form[:markdown].value %></textarea>
            </div>
          </.form>
        <% end %>
      </div>

      <!-- Sidebar -->
      <div class="w-96 border-l border-base-300 bg-base-100 p-6 overflow-y-auto max-h-[calc(100vh-2rem)] sticky top-4" style="font-family: 'IBM Plex Sans', sans-serif;">
        <h2 class="text-xl font-bold mb-6">Post settings</h2>

        <div class="space-y-6">
          <!-- Post URL (Slug) -->
          <div class="form-control mb-4">
            <label class="label mb-2">
              <span class="label-text text-sm font-semibold">Post URL</span>
            </label>
            <div class="flex items-center gap-2">
              <.icon name="hero-link" class="w-4 h-4 text-base-content/50" />
              <input
                type="text"
                form="post-form"
                name={@form[:slug].name}
                value={@form[:slug].value}
                class="input input-bordered input-sm flex-1 text-sm"
                placeholder="url-friendly-slug"
              />
            </div>
            <div class="text-xs text-base-content/60 mt-1">
              weakty.com/<%= @form[:slug].value || "post-slug" %>/
            </div>
          </div>

          <!-- Published At -->
          <div class="form-control mb-4">
            <label class="label mb-2">
              <span class="label-text text-sm font-semibold">Publish date</span>
            </label>
            <input
              type="datetime-local"
              form="post-form"
              name={@form[:published_at].name}
              value={format_datetime_for_input(@form[:published_at].value)}
              class="input input-bordered input-sm w-full text-sm"
            />
            <div class="text-xs text-base-content/60 mt-1">
              Leave empty to auto-set when publishing
            </div>
          </div>

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

            <form phx-submit="add_tag" phx-change="update_tag_input" class="join w-full">
              <input
                type="text"
                name="tag_input"
                value={@tag_input}
                placeholder="Add a tag"
                class="input input-bordered input-sm join-item flex-1 text-sm"
              />
              <button type="submit" class="btn btn-sm btn-ghost join-item">
                Add
              </button>
            </form>
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

              <%= for err <- upload_errors(@uploads.featured_image) do %>
                <p class="text-error text-xs"><%= error_to_string(err) %></p>
              <% end %>
            </div>

            <!-- Hidden input to preserve existing value -->
            <input type="hidden" form="post-form" name={@form[:featured_image].name} value={@form[:featured_image].value} />
          </div>

          <!-- Content Images -->
          <div class="form-control mb-4">
            <label class="label mb-2">
              <span class="label-text text-sm font-semibold">Content Images</span>
            </label>

            <%= if length(@content_images) > 0 do %>
              <div class="grid grid-cols-2 gap-2 mb-2">
                <%= for {image_url, index} <- Enum.with_index(@content_images) do %>
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
                        phx-click="remove_content_image"
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

            <%= for err <- upload_errors(@uploads.content_images) do %>
              <p class="text-error text-xs"><%= error_to_string(err) %></p>
            <% end %>

            <div class="text-xs text-base-content/60 mt-1">
              Click image thumbnails to copy markdown syntax
            </div>
          </div>

          <!-- Excerpt -->
          <div class="form-control mb-4">
            <label class="label mb-2">
              <span class="label-text text-sm font-semibold">Excerpt</span>
            </label>
            <textarea
              form="post-form"
              name={@form[:excerpt].name}
              class="textarea textarea-bordered textarea-sm w-full h-20 text-sm"
              placeholder="Short summary of your post..."
            ><%= @form[:excerpt].value %></textarea>
          </div>

          <div class="divider"></div>

          <!-- Post Type + Status -->
          <div class="grid grid-cols-2 gap-3 mb-4">
            <div class="form-control">
              <label class="label mb-2">
                <span class="label-text text-sm font-semibold">Post Type</span>
              </label>
              <select
                form="post-form"
                name={@form[:post_type].name}
                class="select select-bordered select-sm w-full text-sm"
              >
                <option value="post" selected={@form[:post_type].value == :post || @form[:post_type].value == "post"}>
                  Post
                </option>
                <option value="update" selected={@form[:post_type].value == :update || @form[:post_type].value == "update"}>
                  Update
                </option>
              </select>
            </div>

            <div class="form-control">
              <label class="label mb-2">
                <span class="label-text text-sm font-semibold">Status</span>
              </label>
              <select
                form="post-form"
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
          </div>

          <!-- Access and Featured -->
          <div class="grid grid-cols-2 gap-3 mb-4">
            <label class="label cursor-pointer justify-start gap-2 border border-base-300 rounded-lg px-3 py-2">
              <input type="hidden" form="post-form" name={@form[:public].name} value="false" />
              <input
                type="checkbox"
                form="post-form"
                name={@form[:public].name}
                value="true"
                checked={@form[:public].value}
                class="toggle toggle-sm"
              />
              <span class="label-text text-sm"><%= if @form[:public].value, do: "Public", else: "Private" %></span>
            </label>

            <label class="label cursor-pointer justify-start gap-2 border border-base-300 rounded-lg px-3 py-2">
              <input type="hidden" form="post-form" name={@form[:featured].name} value="false" />
              <input
                type="checkbox"
                form="post-form"
                name={@form[:featured].name}
                value="true"
                checked={@form[:featured].value}
                class="toggle toggle-sm"
              />
              <span class="label-text text-sm">Featured</span>
            </label>
          </div>

          <%= if @post do %>
            <div class="divider"></div>
            <button
              type="button"
              phx-click="delete_post"
              data-confirm="Are you sure you want to delete this post?"
              class="btn btn-error btn-sm w-full"
            >
              Delete post
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
      if is_nil(socket.assigns.post),
        do: maybe_auto_slug(params, socket.assigns.auto_slug),
        else: {params, socket.assigns.auto_slug}

    form = Form.validate(socket.assigns.form, params, errors: true)
    {:noreply, assign(socket, form: form, auto_slug: auto_slug)}
  end

  def handle_event("toggle_preview", _params, socket) do
    {:noreply, assign(socket, preview: !socket.assigns.preview)}
  end

  def handle_event("update_tag_input", %{"tag_input" => value}, socket) do
    {:noreply, assign(socket, tag_input: value)}
  end

  def handle_event("add_tag", %{"tag_input" => value}, socket) do
    tag = String.trim(value)

    if tag != "" and tag not in socket.assigns.tags do
      {:noreply, assign(socket, tags: socket.assigns.tags ++ [tag], tag_input: "")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_tag", %{"tag" => tag}, socket) do
    {:noreply, assign(socket, tags: List.delete(socket.assigns.tags, tag))}
  end

  def handle_event("remove_featured_image", _params, socket) do
    form = Form.validate(socket.assigns.form, %{"featured_image" => nil})
    {:noreply, assign(socket, form: to_form(form))}
  end

  def handle_event("delete_post", _params, socket) do
    case Weakty.Posts.Post.delete_post(socket.assigns.post) do
      :ok -> {:noreply, push_navigate(socket, to: ~p"/admin/posts")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to delete post")}
    end
  end

  def handle_event("remove_content_image", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    content_images = List.delete_at(socket.assigns.content_images, index)
    {:noreply, assign(socket, content_images: content_images)}
  end

  def handle_event("copy_image_markdown", %{"url" => url}, socket) do
    # Send JavaScript command to copy to clipboard
    {:noreply, push_event(socket, "copy-to-clipboard", %{text: "![](#{url})"})}
  end

  def handle_event("save", %{"form" => params}, socket) do
    params = Map.put(params, "content_images", socket.assigns.content_images)

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, post} ->
        handle_tag_update(post, socket.assigns.tags)
        {:noreply, push_navigate(socket, to: ~p"/admin/posts")}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  def handle_progress(:featured_image, entry, socket) when entry.done? do
    uploaded_files =
      consume_uploaded_entries(socket, :featured_image, fn %{path: path}, entry ->
        dest = Path.join([:code.priv_dir(:weakty), "static", "uploads", "#{entry.uuid}.#{ext(entry)}"])
        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)
        {:ok, "/uploads/#{entry.uuid}.#{ext(entry)}"}
      end)

    case uploaded_files do
      [{:ok, url} | _] ->
        form = Form.validate(socket.assigns.form, %{"featured_image" => url})
        {:noreply, assign(socket, form: to_form(form))}

      [] ->
        {:noreply, socket}
    end
  end

  def handle_progress(:content_images, entry, socket) when entry.done? do
    uploaded_files =
      consume_uploaded_entries(socket, :content_images, fn %{path: path}, entry ->
        dest = Path.join([:code.priv_dir(:weakty), "static", "uploads", "#{entry.uuid}.#{ext(entry)}"])
        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)
        {:ok, "/uploads/#{entry.uuid}.#{ext(entry)}"}
      end)

    new_urls = Enum.map(uploaded_files, fn {:ok, url} -> url end)
    content_images = socket.assigns.content_images ++ new_urls
    {:noreply, assign(socket, content_images: content_images)}
  end

  def handle_progress(_name, _entry, socket), do: {:noreply, socket}

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

  defp handle_tag_update(post, tags) do
    Weakty.Tags.TagManager.apply_tags(post, :post, tags, Weakty.Posts.PostTag, :post_id)
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
