defmodule WeaktyWeb.AdminLive.Tags.Show do
  use WeaktyWeb, :live_view

  import WeaktyWeb.AdminComponents

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    tag = Ash.get!(Weakty.Tags.Tag, id)
    tag = Ash.load!(tag, [:entities], domain: Weakty.Tags)

    {:ok,
     socket
     |> assign(:page_title, tag.name)
     |> assign(:current_path, "/admin/tags")
     |> assign(:pending_upload_url, nil)
     |> assign(:featured_image_removed, false)
     |> assign_tag(tag)
     |> allow_upload(:featured_image,
       accept: ~w(.jpg .jpeg .png .gif .webp),
       max_entries: 1,
       max_file_size: 5_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     ),
     layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :featured_image, ref)}
  end

  def handle_event("remove_featured_image", _, socket) do
    {:noreply, assign(socket, pending_upload_url: nil, featured_image_removed: true)}
  end

  def handle_event("update_tag", %{"tag" => tag_params}, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :featured_image, fn %{path: path}, entry ->
        dest = Path.join([:code.priv_dir(:weakty), "static", "uploads", "#{entry.uuid}.#{ext(entry)}"])
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

    case Weakty.Tags.Tag.update_tag(socket.assigns.tag, params) do
      {:ok, updated_tag} ->
        updated_tag = Ash.load!(updated_tag, [:entities], domain: Weakty.Tags)
        {:noreply,
         socket
         |> put_flash(:info, "Tag updated successfully")
         |> assign(:pending_upload_url, nil)
         |> assign(:featured_image_removed, false)
         |> assign_tag(updated_tag)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update tag")}
    end
  end

  def handle_progress(:featured_image, entry, socket) when entry.done? do
    url = consume_uploaded_entry(socket, entry, fn %{path: path} ->
      dest = Path.join([:code.priv_dir(:weakty), "static", "uploads", "#{entry.uuid}.#{ext(entry)}"])
      File.mkdir_p!(Path.dirname(dest))
      File.cp!(path, dest)
      {:ok, "/uploads/#{entry.uuid}.#{ext(entry)}"}
    end)
    {:noreply, assign(socket, :pending_upload_url, url)}
  end

  def handle_progress(_name, _entry, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_header title={@tag.name} subtitle={"#{length(@entities)} item#{if length(@entities) != 1, do: "s"}"}>
      <:actions>
        <.link navigate={~p"/admin/tags"} class="btn btn-ghost btn-sm">
          <.icon name="hero-arrow-left" class="w-4 h-4" />
          Tags
        </.link>
        <%= if @tag.public do %>
          <.link navigate={~p"/areas/#{@tag.slug}"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" />
            View area
          </.link>
        <% end %>
        <button
          class="btn btn-primary btn-sm"
          onclick="document.getElementById('edit_tag_modal').showModal()"
        >
          <.icon name="hero-pencil" class="w-4 h-4" />
          Edit
        </button>
      </:actions>
    </.admin_header>

    <div class="p-8">
      <%= if Enum.empty?(@entities) do %>
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body items-center text-center">
            <p class="text-base-content/60">No content tagged with "<%= @tag.name %>" yet</p>
          </div>
        </div>
      <% else %>
        <div class="space-y-8">
          <%= for {entity_type, entities} <- Enum.sort_by(@grouped, fn {k, _} -> to_string(k) end) do %>
            <div>
              <h2 class="text-xs uppercase tracking-widest opacity-40 mb-3 flex items-center gap-2">
                <.icon name={entity_type_icon(entity_type)} class="w-3.5 h-3.5" />
                <%= entity_type |> to_string() |> String.capitalize() %>
                <span class="opacity-60">[<%= length(entities) %>]</span>
              </h2>
              <div class="space-y-1">
                <%= for entity <- entities do %>
                  <div class="flex items-baseline gap-4 py-1.5 border-b border-base-200">
                    <a
                      href={"#{entity.source_path}/#{entity.slug}"}
                      class="flex-1 text-sm hover:opacity-60 transition-opacity truncate"
                      target="_blank"
                    >
                      <%= entity.title %>
                    </a>
                    <%= if entity.subtype do %>
                      <span class="text-xs opacity-30 flex-shrink-0"><%= entity.subtype %></span>
                    <% end %>
                    <time class="text-xs opacity-30 tabular-nums flex-shrink-0">
                      <%= if entity.published_at, do: Calendar.strftime(entity.published_at, "%Y-%m-%d") %>
                    </time>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>

    <dialog id="edit_tag_modal" class="modal">
      <div class="modal-box max-w-2xl">
        <h3 class="font-bold text-lg mb-4">Edit Tag</h3>
        <.form for={%{}} phx-submit="update_tag" phx-change="validate">
          <.input type="text" name="tag[name]" label="Tag Name" value={@tag.name} required />
          <.input type="checkbox" name="tag[public]" label="Public (show as an area)" checked={@tag.public} />

          <div class="form-control mb-4">
            <label class="label">
              <span class="label-text font-semibold">Featured Image</span>
            </label>
            <.live_file_input upload={@uploads.featured_image} class="hidden" />
            <%= cond do %>
              <% entry = List.first(@uploads.featured_image.entries) -> %>
                <div class="relative inline-block">
                  <.live_img_preview entry={entry} class="w-20 h-20 object-cover rounded-lg" />
                  <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} class="absolute -top-1 -right-1 btn btn-error btn-xs btn-circle">✕</button>
                </div>
                <progress value={entry.progress} max="100" class="progress progress-primary w-full mt-2"></progress>
              <% @pending_upload_url -> %>
                <div class="relative inline-block">
                  <img src={@pending_upload_url} alt="Featured image" class="w-20 h-20 object-cover rounded-lg" />
                  <button type="button" phx-click="remove_featured_image" class="absolute -top-1 -right-1 btn btn-error btn-xs btn-circle">✕</button>
                </div>
              <% !@featured_image_removed && @tag.featured_image -> %>
                <div class="relative inline-block">
                  <img src={@tag.featured_image} alt="Current featured image" class="w-20 h-20 object-cover rounded-lg" />
                  <button type="button" phx-click="remove_featured_image" class="absolute -top-1 -right-1 btn btn-error btn-xs btn-circle">✕</button>
                  <input type="hidden" name="tag[featured_image]" value={@tag.featured_image} />
                </div>
              <% true -> %>
                <section phx-drop-target={@uploads.featured_image.ref} class="border-2 border-dashed border-base-300 rounded-lg p-3 text-center">
                  <label for={@uploads.featured_image.ref} class="cursor-pointer block">
                    <.icon name="hero-photo" class="w-6 h-6 mx-auto text-base-content/30 mb-1" />
                    <span class="text-xs text-base-content/60">Drop image here or click to upload</span>
                  </label>
                </section>
            <% end %>
          </div>

          <.input type="textarea" name="tag[description]" label="Description (Markdown)" value={@tag.description} rows="6" />

          <div class="modal-action">
            <button type="submit" class="btn btn-primary">Update</button>
            <button type="button" class="btn" onclick="document.getElementById('edit_tag_modal').close()">Cancel</button>
          </div>
        </.form>
      </div>
      <form method="dialog" class="modal-backdrop">
        <button>close</button>
      </form>
    </dialog>
    """
  end

  defp assign_tag(socket, tag) do
    entities = Enum.sort_by(tag.entities, & &1.published_at, {:desc, DateTime})
    grouped = Enum.group_by(entities, & &1.entity_type)
    socket |> assign(:tag, tag) |> assign(:entities, entities) |> assign(:grouped, grouped)
  end

  defp entity_type_icon(:post), do: "hero-document-text"
  defp entity_type_icon(:link), do: "hero-link"
  defp entity_type_icon(:media_log), do: "hero-film"
  defp entity_type_icon(:project), do: "hero-folder"
  defp entity_type_icon(_), do: "hero-cube"

  defp ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    ext
  end
end
