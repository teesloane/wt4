defmodule WeaktyWeb.PostLive.Form do
  use WeaktyWeb, :live_view
  alias AshPhoenix.Form

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(params, _session, socket) do
    post =
      case params["slug"] do
        nil -> nil
        slug ->
          Weakty.Posts.Post
          |> Ash.Query.for_read(:get_by_slug, %{slug: slug})
          |> Ash.read_one!()
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
      |> assign(form: form, post: post, preview: false, tags: existing_tags, tag_input: "")
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
            <%= if @post, do: "Draft - Saved", else: "New Post" %>
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
                class="input input-ghost w-full text-4xl font-bold px-0 focus:outline-none"
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

          <!-- Status -->
          <div class="form-control mb-4">
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

          <!-- Access and Featured -->
          <div class="grid grid-cols-2 gap-3 mb-4">
            <label class="label cursor-pointer justify-start gap-2 border border-base-300 rounded-lg px-3 py-2">
              <input
                type="checkbox"
                form="post-form"
                name={@form[:public].name}
                checked={@form[:public].value}
                class="toggle toggle-sm"
              />
              <span class="label-text text-sm"><%= if @form[:public].value, do: "Public", else: "Private" %></span>
            </label>

            <label class="label cursor-pointer justify-start gap-2 border border-base-300 rounded-lg px-3 py-2">
              <input
                type="checkbox"
                form="post-form"
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

  def handle_event("remove_featured_image", _params, socket) do
    form = Form.validate(socket.assigns.form, %{"featured_image" => nil})
    {:noreply, assign(socket, form: to_form(form))}
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

  def handle_event("validate", %{"_target" => ["featured_image"]}, socket) do
    # Auto-upload featured image when selected
    uploaded_files =
      consume_uploaded_entries(socket, :featured_image, fn %{path: path}, entry ->
        dest = Path.join(["priv", "static", "uploads", "#{entry.uuid}.#{ext(entry)}"])
        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)
        {:ok, "/uploads/#{entry.uuid}.#{ext(entry)}"}
      end)

    case uploaded_files do
      [url | _] ->
        form = Form.validate(socket.assigns.form, %{"featured_image" => url})
        {:noreply, assign(socket, form: to_form(form))}

      [] ->
        {:noreply, socket}
    end
  end

  def handle_event("validate", %{"_target" => ["content_images"]}, socket) do
    # Auto-upload content images when selected
    uploaded_files =
      consume_uploaded_entries(socket, :content_images, fn %{path: path}, entry ->
        dest = Path.join(["priv", "static", "uploads", "#{entry.uuid}.#{ext(entry)}"])
        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)
        {:ok, "/uploads/#{entry.uuid}.#{ext(entry)}"}
      end)

    content_images = socket.assigns.content_images ++ uploaded_files
    {:noreply, assign(socket, content_images: content_images)}
  end

  def handle_event("save", %{"form" => params}, socket) do
    IO.puts("\n=== POST SAVE EVENT ===")
    IO.inspect(socket.assigns.tags, label: "Tags to save")

    # Add content_images to params
    params = Map.put(params, "content_images", socket.assigns.content_images)

    # First, create/update the post without tags
    result = Form.submit(socket.assigns.form, params: params)

    case result do
      {:ok, post} ->
        IO.inspect(post.id, label: "Created/updated post ID")
        handle_tag_update(post, socket.assigns.tags)
        {:noreply, push_navigate(socket, to: ~p"/admin/posts")}

      {:error, form} ->
        IO.puts("Form validation error:")
        IO.inspect(form.errors)
        IO.puts("Form source:")
        IO.inspect(form.source, label: "form.source", limit: :infinity, printable_limit: :infinity)
        IO.puts("Form source keys:")
        if is_map(form.source), do: IO.inspect(Map.keys(form.source), label: "keys")

        # Check if there's a resource in the form source (means post was created despite error)
        post_from_error =
          case form.source do
            %{resource: %Weakty.Posts.Post{} = post} -> post
            %{data: %Weakty.Posts.Post{} = post} -> post
            %Ash.Changeset{data: %Weakty.Posts.Post{} = post} -> post
            _ -> nil
          end

        IO.inspect(post_from_error, label: "post_from_error")

        cond do
          # Post was created despite form error - use it for tags
          post_from_error && post_from_error.id ->
            IO.puts("Post was created despite form error, updating tags...")
            IO.inspect(post_from_error.id, label: "Post ID from error")
            handle_tag_update(post_from_error, socket.assigns.tags)
            {:noreply, push_navigate(socket, to: ~p"/admin/posts")}

          # Editing existing post - reload it
          socket.assigns.post ->
            IO.puts("Reloading existing post for tag update...")
            post = Ash.get!(Weakty.Posts.Post, socket.assigns.post.id)
            handle_tag_update(post, socket.assigns.tags)
            {:noreply, push_navigate(socket, to: ~p"/admin/posts")}

          # Creating new post - form validation actually failed
          true ->
            {:noreply, assign(socket, form: to_form(form))}
        end
    end
  end

  defp handle_tag_update(post, tags) do
    if length(tags) > 0 do
      tags_param = Enum.map(tags, &%{name: &1})
      IO.inspect(tags_param, label: "Tags param")

      # Update the post with tags
      result =
        post
        |> Ash.Changeset.for_update(:update, %{}, domain: Weakty.Posts)
        |> Ash.Changeset.set_argument(:tags, tags_param)
        |> Ash.update(domain: Weakty.Posts)

      IO.inspect(result, label: "Update result")

      case result do
        {:ok, updated_post} ->
          IO.puts("Tags updated successfully")
          # Load tags to verify
          loaded = Ash.load!(updated_post, :tags)
          IO.inspect(loaded.tags, label: "Loaded tags")

        {:error, error} ->
          IO.puts("ERROR updating tags:")
          IO.inspect(error)
      end
    else
      IO.puts("No tags to save")
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
