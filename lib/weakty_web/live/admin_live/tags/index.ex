defmodule WeaktyWeb.AdminLive.Tags.Index do
  use WeaktyWeb, :live_view

  import WeaktyWeb.AdminComponents

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Tags")
     |> assign(:current_path, "/admin/tags")
     |> assign(:editing_tag, nil)
     |> assign(:new_tag_name, "")
     |> assign(:pending_upload_url, nil)
     |> assign(:featured_image_removed, false)
     |> assign(:view, "grid")
     |> allow_upload(:featured_image,
       accept: ~w(.jpg .jpeg .png .gif .webp),
       max_entries: 1,
       max_file_size: 5_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )
     |> load_tags(), layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def handle_event("start_edit", %{"id" => id}, socket) do
    tag = Enum.find(socket.assigns.tags, &(&1.id == id))

    {:noreply,
     assign(socket, editing_tag: tag, pending_upload_url: nil, featured_image_removed: false)}
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    {:noreply,
     assign(socket, editing_tag: nil, pending_upload_url: nil, featured_image_removed: false)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :featured_image, ref)}
  end

  @impl true
  def handle_event("remove_featured_image", _, socket) do
    {:noreply, assign(socket, pending_upload_url: nil, featured_image_removed: true)}
  end

  @impl true
  def handle_event("update_tag", %{"tag" => tag_params}, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :featured_image, fn %{path: path}, entry ->
        dest =
          Path.join([:code.priv_dir(:weakty), "static", "uploads", "#{entry.uuid}.#{ext(entry)}"])

        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)
        {:ok, "/uploads/#{entry.uuid}.#{ext(entry)}"}
      end)

    featured_image =
      cond do
        socket.assigns.featured_image_removed -> nil
        url = List.first(uploaded_files) -> url
        url = socket.assigns.pending_upload_url -> url
        true -> Map.get(tag_params, "featured_image")
      end

    params =
      tag_params
      |> Map.put("featured_image", featured_image)
      |> Map.take(["name", "public", "featured_image", "description"])
      |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
      |> Map.new()

    case Weakty.Tags.Tag.update_tag(socket.assigns.editing_tag, params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Tag updated successfully")
         |> assign(:editing_tag, nil)
         |> assign(:pending_upload_url, nil)
         |> assign(:featured_image_removed, false)
         |> load_tags()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update tag")}
    end
  end

  @impl true
  def handle_event("create_tag", %{"tag" => tag_params}, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :featured_image, fn %{path: path}, entry ->
        dest =
          Path.join([:code.priv_dir(:weakty), "static", "uploads", "#{entry.uuid}.#{ext(entry)}"])

        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)
        {:ok, "/uploads/#{entry.uuid}.#{ext(entry)}"}
      end)

    featured_image = List.first(uploaded_files) || socket.assigns.pending_upload_url

    params =
      tag_params
      |> Map.put("featured_image", featured_image)
      |> Map.take(["name", "public", "featured_image", "description"])
      |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
      |> Map.new()

    case Weakty.Tags.Tag.create_tag(params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Tag created successfully")
         |> assign(:new_tag_name, "")
         |> assign(:pending_upload_url, nil)
         |> assign(:featured_image_removed, false)
         |> load_tags()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create tag")}
    end
  end

  @impl true
  def handle_event("cleanup_orphaned", _, socket) do
    case Weakty.Tags.TagManager.cleanup_orphaned_tags() do
      {:ok, 0} ->
        {:noreply, put_flash(socket, :info, "No orphaned tags found")}

      {:ok, count} ->
        {:noreply,
         socket
         |> put_flash(:info, "Deleted #{count} orphaned tag#{if count != 1, do: "s"}")
         |> load_tags()}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    tag = Ash.get!(Weakty.Tags.Tag, id)

    case Weakty.Tags.Tag.delete_tag(tag) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Tag deleted successfully")
         |> load_tags()}

      {:error, e} ->
        IO.inspect(e, label: "failed to delete tag....")

        {:noreply, put_flash(socket, :error, "Failed to delete tag")}
    end
  end

  @impl true
  def handle_event("set_view", %{"view" => view}, socket) when view in ["grid", "table"] do
    {:noreply, assign(socket, :view, view)}
  end

  def handle_progress(:featured_image, entry, socket) when entry.done? do
    {:noreply, assign(socket, :pending_upload_url, save_upload(socket, entry))}
  end

  def handle_progress(_name, _entry, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_header title="Tags" subtitle={"#{length(@tags)} tag#{if length(@tags) != 1, do: "s"}"}>
      <:actions>
        <button
          phx-click="cleanup_orphaned"
          phx-confirm="Delete all tags not attached to any content?"
          class="btn btn-ghost btn-sm"
        >
          Clean up unused
        </button>
        <button
          class="btn btn-primary"
          onclick="document.getElementById('new_tag_modal').showModal()"
        >
          <.icon name="hero-plus" class="w-4 h-4" /> New Tag
        </button>
      </:actions>
    </.admin_header>

    <div class="p-8">
      <%= if @tags == [] do %>
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body items-center text-center">
            <.icon name="hero-tag" class="w-16 h-16 text-base-content/30" />
            <h2 class="card-title">No tags yet</h2>
            <p class="text-base-content/70">Create your first tag to organize your content</p>
            <button
              class="btn btn-primary mt-4"
              onclick="document.getElementById('new_tag_modal').showModal()"
            >
              <.icon name="hero-plus" class="w-4 h-4" /> Create Tag
            </button>
          </div>
        </div>
      <% else %>
        <div class="flex justify-end mb-4">
          <div class="join">
            <button
              class={[
                "join-item btn btn-sm",
                if(@view == "grid", do: "btn-active", else: "btn-ghost")
              ]}
              phx-click="set_view"
              phx-value-view="grid"
            >
              <.icon name="hero-squares-2x2" class="w-4 h-4" />
            </button>
            <button
              class={[
                "join-item btn btn-sm",
                if(@view == "table", do: "btn-active", else: "btn-ghost")
              ]}
              phx-click="set_view"
              phx-value-view="table"
            >
              <.icon name="hero-bars-3" class="w-4 h-4" />
            </button>
          </div>
        </div>

        <%= if @view == "grid" do %>
          <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-8 gap-0">
            <%= for tag <- @tags do %>
              <.link
                navigate={~p"/admin/tags/#{tag.id}"}
                class="font-medium text-sm leading-tight hover:opacity-60 transition-opacity"
              >
                <div class="border border-base-300/50 p-3 hover:bg-base-200/50 transition-colors min-h-28">
                  <div class="flex items-start justify-between gap-1 mb-2">
                    {tag.name}
                    <%= if tag.public do %>
                      <.icon name="hero-eye" class="w-3 h-3" />
                    <% end %>
                  </div>
                  <div class="flex gap-3 flex-wrap text-xs text-base-content/40 mb-3">
                    <%= for {type, posts} <- Enum.group_by(tag.posts, & &1.post_type) do %>
                      <span class="flex items-center gap-0.5" title={to_string(type)}>
                        <.icon name={post_type_icon(type)} class="w-3 h-3" />{length(posts)}
                      </span>
                    <% end %>
                    <%= if length(tag.links) > 0 do %>
                      <span class="flex items-center gap-0.5">
                        <.icon name="hero-link" class="w-3 h-3" />{length(tag.links)}
                      </span>
                    <% end %>
                    <%= if length(tag.media_logs) > 0 do %>
                      <span class="flex items-center gap-0.5">
                        <.icon name="hero-film" class="w-3 h-3" />{length(tag.media_logs)}
                      </span>
                    <% end %>
                    <%= if length(tag.projects) > 0 do %>
                      <span class="flex items-center gap-0.5">
                        <.icon name="hero-folder" class="w-3 h-3" />{length(tag.projects)}
                      </span>
                    <% end %>
                  </div>
                  <div :if={false} class="flex gap-1">
                    <button phx-click="start_edit" phx-value-id={tag.id} class="btn btn-ghost btn-xs">
                      <.icon name="hero-pencil" class="w-3 h-3" />
                    </button>
                    <button
                      phx-click="delete"
                      phx-value-id={tag.id}
                      phx-confirm="Are you sure you want to delete this tag?"
                      class="btn btn-ghost btn-xs text-error"
                    >
                      <.icon name="hero-trash" class="w-3 h-3" />
                    </button>
                  </div>
                </div>
              </.link>
            <% end %>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <table class="table table-zebra">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Slug</th>
                  <th>Public</th>
                  <th>Posts</th>
                  <th>Links</th>
                  <th>Media</th>
                  <th>Projects</th>
                  <th>Total</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                <%= for tag <- @tags do %>
                  <tr class="hover">
                    <td>
                      <.link
                        navigate={~p"/admin/tags/#{tag.id}"}
                        class="badge badge-lg hover:opacity-60 transition-opacity"
                      >
                        {tag.name}
                      </.link>
                    </td>
                    <td><code class="text-sm text-base-content/70">{tag.slug}</code></td>
                    <td>
                      <%= if tag.public do %>
                        <span class="badge badge-success badge-sm">Yes</span>
                      <% else %>
                        <span class="badge badge-ghost badge-sm">No</span>
                      <% end %>
                    </td>
                    <td>
                      <div class="text-sm">{length(tag.posts)}</div>
                    </td>
                    <td>
                      <div class="text-sm">{length(tag.links)}</div>
                    </td>
                    <td>
                      <div class="text-sm">{length(tag.media_logs)}</div>
                    </td>
                    <td>
                      <div class="text-sm">{length(tag.projects)}</div>
                    </td>
                    <td>
                      <div class="font-semibold">
                        {length(tag.posts) + length(tag.links) + length(tag.media_logs) +
                          length(tag.projects)}
                      </div>
                    </td>
                    <td>
                      <div class="flex gap-2">
                        <button
                          phx-click="start_edit"
                          phx-value-id={tag.id}
                          class="btn btn-ghost btn-xs"
                          title="Edit"
                        >
                          <.icon name="hero-pencil" class="w-4 h-4" />
                        </button>
                        <button
                          phx-click="delete"
                          phx-value-id={tag.id}
                          phx-confirm="Are you sure you want to delete this tag? This will remove it from all posts and links."
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
      <% end %>
    </div>
    <%!-- New Tag Modal --%>
    <dialog id="new_tag_modal" class="modal">
      <div class="modal-box max-w-2xl">
        <h3 class="font-bold text-lg mb-4">Create New Tag</h3>
        <.form for={%{}} phx-submit="create_tag" phx-change="validate">
          <.input type="text" name="tag[name]" label="Tag Name" value={@new_tag_name} required />

          <.input
            type="checkbox"
            name="tag[public]"
            label="Public (show as an area)"
            checked={false}
          />

          <div class="form-control mb-4">
            <label class="label">
              <span class="label-text font-semibold">Featured Image</span>
            </label>
            <.live_file_input upload={@uploads.featured_image} class="hidden" />

            <%= cond do %>
              <% entry = List.first(@uploads.featured_image.entries) -> %>
                <%!-- Upload in progress --%>
                <div class="relative inline-block">
                  <.live_img_preview entry={entry} class="w-20 h-20 object-cover rounded-lg" />
                  <button
                    type="button"
                    phx-click="cancel-upload"
                    phx-value-ref={entry.ref}
                    class="absolute -top-1 -right-1 btn btn-error btn-xs btn-circle"
                  >
                    ✕
                  </button>
                </div>
                <progress
                  value={entry.progress}
                  max="100"
                  class="progress progress-primary w-full mt-2"
                >
                </progress>
              <% @pending_upload_url -> %>
                <%!-- Uploaded image --%>
                <div class="relative inline-block">
                  <img
                    src={@pending_upload_url}
                    alt="Featured image"
                    class="w-20 h-20 object-cover rounded-lg"
                  />
                  <button
                    type="button"
                    phx-click="remove_featured_image"
                    class="absolute -top-1 -right-1 btn btn-error btn-xs btn-circle"
                  >
                    ✕
                  </button>
                </div>
              <% true -> %>
                <%!-- No image: show drop zone --%>
                <section
                  phx-drop-target={@uploads.featured_image.ref}
                  class="border-2 border-dashed border-base-300 rounded-lg p-3 text-center [&.phx-drop-target-active]:border-primary [&.phx-drop-target-active]:bg-primary/5 transition-colors"
                >
                  <label for={@uploads.featured_image.ref} class="cursor-pointer block">
                    <.icon name="hero-photo" class="w-6 h-6 mx-auto text-base-content/30 mb-1" />
                    <span class="text-xs text-base-content/60">
                      Drop image here or click to upload
                    </span>
                  </label>
                  <%= for err <- upload_errors(@uploads.featured_image) do %>
                    <p class="text-error text-xs mt-1">{error_to_string(err)}</p>
                  <% end %>
                </section>
            <% end %>
          </div>

          <.input
            type="textarea"
            name="tag[description]"
            label="Description (Markdown)"
            value=""
            rows="6"
          />

          <div class="modal-action">
            <button type="submit" class="btn btn-primary">Create</button>
            <button
              type="button"
              class="btn"
              onclick="document.getElementById('new_tag_modal').close()"
            >
              Cancel
            </button>
          </div>
        </.form>
      </div>
      <form method="dialog" class="modal-backdrop">
        <button>close</button>
      </form>
    </dialog>
    <%!-- Edit Tag Modal --%>
    <%= if @editing_tag do %>
      <dialog id="edit_tag_modal" class="modal" open>
        <div class="modal-box max-w-2xl">
          <h3 class="font-bold text-lg mb-4">Edit Tag</h3>
          <.form for={%{}} phx-submit="update_tag" phx-change="validate">
            <.input
              type="text"
              name="tag[name]"
              label="Tag Name"
              value={@editing_tag.name}
              required
            />

            <.input
              type="checkbox"
              name="tag[public]"
              label="Public (show as an area)"
              checked={@editing_tag.public}
            />

            <div class="form-control mb-4">
              <label class="label">
                <span class="label-text font-semibold">Featured Image</span>
              </label>
              <.live_file_input upload={@uploads.featured_image} class="hidden" />

              <%= cond do %>
                <% entry = List.first(@uploads.featured_image.entries) -> %>
                  <%!-- Upload in progress --%>
                  <div class="relative inline-block">
                    <.live_img_preview entry={entry} class="w-20 h-20 object-cover rounded-lg" />
                    <button
                      type="button"
                      phx-click="cancel-upload"
                      phx-value-ref={entry.ref}
                      class="absolute -top-1 -right-1 btn btn-error btn-xs btn-circle"
                    >
                      ✕
                    </button>
                  </div>
                  <progress
                    value={entry.progress}
                    max="100"
                    class="progress progress-primary w-full mt-2"
                  >
                  </progress>
                <% @pending_upload_url -> %>
                  <%!-- New upload saved --%>
                  <div class="relative inline-block">
                    <img
                      src={@pending_upload_url}
                      alt="Featured image"
                      class="w-20 h-20 object-cover rounded-lg"
                    />
                    <button
                      type="button"
                      phx-click="remove_featured_image"
                      class="absolute -top-1 -right-1 btn btn-error btn-xs btn-circle"
                    >
                      ✕
                    </button>
                  </div>
                <% !@featured_image_removed && @editing_tag.featured_image -> %>
                  <%!-- Existing image from DB --%>
                  <div class="relative inline-block">
                    <img
                      src={@editing_tag.featured_image}
                      alt="Current featured image"
                      class="w-20 h-20 object-cover rounded-lg"
                    />
                    <button
                      type="button"
                      phx-click="remove_featured_image"
                      class="absolute -top-1 -right-1 btn btn-error btn-xs btn-circle"
                    >
                      ✕
                    </button>
                    <input
                      type="hidden"
                      name="tag[featured_image]"
                      value={@editing_tag.featured_image}
                    />
                  </div>
                <% true -> %>
                  <%!-- No image: show drop zone --%>
                  <section
                    phx-drop-target={@uploads.featured_image.ref}
                    class="border-2 border-dashed border-base-300 rounded-lg p-3 text-center [&.phx-drop-target-active]:border-primary [&.phx-drop-target-active]:bg-primary/5 transition-colors"
                  >
                    <label for={@uploads.featured_image.ref} class="cursor-pointer block">
                      <.icon name="hero-photo" class="w-6 h-6 mx-auto text-base-content/30 mb-1" />
                      <span class="text-xs text-base-content/60">
                        Drop image here or click to upload
                      </span>
                    </label>
                    <%= for err <- upload_errors(@uploads.featured_image) do %>
                      <p class="text-error text-xs mt-1">{error_to_string(err)}</p>
                    <% end %>
                  </section>
              <% end %>
            </div>

            <.input
              type="textarea"
              name="tag[description]"
              label="Description (Markdown)"
              value={@editing_tag.description}
              rows="6"
            />

            <div class="modal-action">
              <button type="submit" class="btn btn-primary">Update</button>
              <button type="button" phx-click="cancel_edit" class="btn">Cancel</button>
            </div>
          </.form>
        </div>
        <form method="dialog" class="modal-backdrop" phx-click="cancel_edit">
          <button>close</button>
        </form>
      </dialog>
    <% end %>
    """
  end

  defp load_tags(socket) do
    tags =
      Weakty.Tags.Tag.list_tags!()
      |> Ash.load!([:links, :posts, :media_logs, :projects], domain: Weakty.Tags)
      |> Enum.sort_by(
        fn tag ->
          length(tag.posts) + length(tag.links) + length(tag.media_logs) + length(tag.projects)
        end,
        :desc
      )

    assign(socket, :tags, tags)
  end

  defp save_upload(socket, entry) do
    consume_uploaded_entry(socket, entry, fn %{path: path} ->
      dest =
        Path.join([:code.priv_dir(:weakty), "static", "uploads", "#{entry.uuid}.#{ext(entry)}"])

      File.mkdir_p!(Path.dirname(dest))
      File.cp!(path, dest)
      {:ok, "/uploads/#{entry.uuid}.#{ext(entry)}"}
    end)
  end

  defp error_to_string(:too_large), do: "File too large (max 5MB)"
  defp error_to_string(:too_many_files), do: "Too many files selected"

  defp error_to_string(:not_accepted),
    do: "Invalid file type (only .jpg, .jpeg, .png, .gif, .webp)"

  defp error_to_string(error), do: "Upload error: #{inspect(error)}"

  defp ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    ext
  end

  defp post_type_icon(:post), do: "hero-document-text"
  defp post_type_icon(:update), do: "hero-arrow-path"
  defp post_type_icon(:til), do: "hero-light-bulb"
  defp post_type_icon(:quote), do: "hero-chat-bubble-left"
  defp post_type_icon(:fiction), do: "hero-book-open"
  defp post_type_icon(:process), do: "hero-beaker"
  defp post_type_icon(:page), do: "hero-document"
  defp post_type_icon(_), do: "hero-document-text"
end
