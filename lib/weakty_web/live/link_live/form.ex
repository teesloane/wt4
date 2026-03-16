defmodule WeaktyWeb.LinkLive.Form do
  use WeaktyWeb, :live_view
  alias AshPhoenix.Form

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(params, _session, socket) do
    link =
      case params["id"] do
        nil ->
          nil

        id ->
          Weakty.Links.Link
          |> Ash.get!(id)
          |> Ash.load!(:tags)
      end

    existing_tags = if link, do: Enum.map(link.tags || [], & &1.name), else: []

    form =
      if link do
        Form.for_update(link, :update, domain: Weakty.Links, forms: [auto?: false])
      else
        Form.for_create(Weakty.Links.Link, :create,
          domain: Weakty.Links,
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

    {:ok,
     socket
     |> assign(form: form, link: link, tags: existing_tags, pending_og_image: nil)
     |> assign(:current_path, "/admin/links")
     |> allow_upload(:og_image,
       accept: ~w(.jpg .jpeg .png .webp .gif),
       max_entries: 1,
       max_file_size: 10_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     ), layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-8 py-8">
      <div class="flex items-center gap-4 mb-8">
        <.link navigate="/admin/links" class="btn btn-ghost btn-sm">
          <.icon name="hero-arrow-left" class="w-4 h-4" /> Links
        </.link>
        <div class="flex-1"></div>
        <button type="submit" form="link-form" class="btn btn-primary btn-sm">
          {if @link, do: "Update", else: "Save"}
        </button>
      </div>

      <.form
        id="link-form"
        for={@form}
        phx-submit="save"
        phx-change="validate"
        class="space-y-4"
      >
        <div class="form-control">
          <label class="label">
            <span class="label-text text-sm font-semibold">URL</span>
          </label>
          <input
            type="url"
            name={@form[:url].name}
            value={@form[:url].value}
            class="input input-bordered w-full"
            required
          />
        </div>

        <div class="form-control">
          <label class="label">
            <span class="label-text text-sm font-semibold">Title</span>
          </label>
          <input
            type="text"
            name={@form[:title].name}
            value={@form[:title].value}
            class="input input-bordered w-full"
            required
          />
        </div>

        <div class="form-control">
          <label class="label">
            <span class="label-text text-sm font-semibold">Commentary</span>
          </label>
          <textarea
            name={@form[:commentary].name}
            class="textarea textarea-bordered w-full h-32"
          ><%= @form[:commentary].value %></textarea>
        </div>

        <label class="label cursor-pointer justify-start gap-2 border border-base-300 rounded-lg px-3 py-2 w-fit">
          <input type="hidden" name={@form[:public].name} value="false" />
          <input
            type="checkbox"
            name={@form[:public].name}
            value="true"
            checked={@form[:public].value}
            class="toggle toggle-sm"
          />
          <span class="label-text text-sm">
            {if @form[:public].value, do: "Public", else: "Private"}
          </span>
        </label>
      </.form>

      <%!-- OG Image upload — only shown when editing an existing link --%>
      <%= if @link do %>
        <div class="form-control mt-6">
          <label class="label">
            <span class="label-text text-sm font-semibold">Preview Image</span>
            <%= if @pending_og_image || @link.og_image_pinned do %>
              <span class="badge badge-sm badge-info">pinned</span>
            <% end %>
          </label>

          <%!-- Current image preview (saved or just uploaded) --%>
          <% preview_image = @pending_og_image || @link.og_image %>
          <%= if preview_image do %>
            <div class="relative w-full aspect-video bg-base-300 rounded-lg overflow-hidden mb-3">
              <img
                src={preview_image}
                alt="Preview"
                class="w-full h-full object-cover"
              />
              <button
                type="button"
                phx-click="remove_og_image"
                class="absolute top-2 right-2 btn btn-xs btn-error"
                phx-confirm="Remove this image? The pin will also be cleared."
              >
                <.icon name="hero-x-mark" class="w-3 h-3" /> Remove
              </button>
            </div>
          <% end %>

          <%!-- File drop zone --%>
          <section
            phx-drop-target={@uploads.og_image.ref}
            class="border-2 border-dashed border-base-300 rounded-lg p-6 text-center [&.phx-drop-target-active]:border-primary [&.phx-drop-target-active]:bg-primary/5 transition-colors"
          >
            <.live_file_input form="link-form" upload={@uploads.og_image} class="hidden" />

            <%= for entry <- @uploads.og_image.entries do %>
              <article class="mb-3">
                <.live_img_preview entry={entry} class="w-full rounded-lg mb-2" />
                <progress value={entry.progress} max="100" class="progress progress-primary w-full">
                </progress>
                <div class="flex justify-between text-xs text-base-content/60 mt-1">
                  <span>{entry.client_name}</span>
                  <button
                    type="button"
                    phx-click="cancel_upload"
                    phx-value-ref={entry.ref}
                    class="text-error hover:underline"
                  >
                    Cancel
                  </button>
                </div>
              </article>
            <% end %>

            <%= if Enum.empty?(@uploads.og_image.entries) do %>
              <label for={@uploads.og_image.ref} class="cursor-pointer block">
                <.icon name="hero-photo" class="w-8 h-8 mx-auto text-base-content/30 mb-1" />
                <span class="text-sm text-base-content/60">
                  {if @link.og_image, do: "Drop or click to replace", else: "Drop image here or click to upload"}
                </span>
                <span class="block text-xs text-base-content/40 mt-1">JPG, PNG, WebP, GIF · max 10MB</span>
              </label>
            <% end %>

            <%= for err <- upload_errors(@uploads.og_image) do %>
              <p class="text-error text-xs mt-1">{upload_error_to_string(err)}</p>
            <% end %>
          </section>

          <p class="text-xs text-base-content/50 mt-2">
            Uploading an image pins it — the auto-fetch won't overwrite it.
            Remove it to let the fetcher try again.
          </p>
        </div>
      <% end %>

      <div class="form-control mt-4">
        <label class="label">
          <span class="label-text text-sm font-semibold">Tags</span>
        </label>
        <.live_component module={WeaktyWeb.TagAdder} id="tag-adder" tags={@tags} />
      </div>

      <%= if @link do %>
        <div class="divider mt-8"></div>
        <button
          type="button"
          phx-click="delete_link"
          phx-confirm="Are you sure you want to delete this link?"
          class="btn btn-error btn-sm w-full"
        >
          Delete link
        </button>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = Form.validate(socket.assigns.form, params, errors: true)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, link} ->
        handle_tag_update(link, socket.assigns.tags)
        maybe_consume_og_upload(socket, link)

        message =
          if socket.assigns.link,
            do: "Link updated successfully.",
            else: "Link saved successfully."

        {:noreply, socket |> put_flash(:info, message) |> push_navigate(to: ~p"/admin/links")}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :og_image, ref)}
  end

  def handle_event("remove_og_image", _params, socket) do
    link = socket.assigns.link

    link
    |> Ash.Changeset.for_update(:update_og, %{og_image: nil, og_image_pinned: false},
      authorize?: false
    )
    |> Ash.update(authorize?: false)

    updated_link = %{link | og_image: nil, og_image_pinned: false}
    {:noreply, assign(socket, link: updated_link, pending_og_image: nil)}
  end

  def handle_event("delete_link", _params, socket) do
    case Ash.destroy(socket.assigns.link) do
      :ok ->
        {:noreply, push_navigate(socket, to: ~p"/admin/links")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete link")}
    end
  end

  def handle_progress(:og_image, entry, socket) when entry.done? do
    local_path =
      consume_uploaded_entry(socket, entry, fn %{path: tmp_path} ->
        uuid = Ecto.UUID.generate()
        ext = entry.client_name |> Path.extname() |> String.trim_leading(".") |> String.downcase()
        ext = if ext in ~w(jpg jpeg png webp gif), do: ext, else: "jpg"
        filename = "#{uuid}.#{ext}"
        dir = Path.join([:code.priv_dir(:weakty), "static", "uploads", "link_thumbnails"])
        File.mkdir_p!(dir)
        File.cp!(tmp_path, Path.join(dir, filename))
        {:ok, "/uploads/link_thumbnails/#{filename}"}
      end)

    {:noreply, assign(socket, :pending_og_image, local_path)}
  end

  def handle_progress(_name, _entry, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:tag_changed, tags}, socket) do
    {:noreply, assign(socket, :tags, tags)}
  end

  defp maybe_consume_og_upload(socket, link) do
    case socket.assigns.pending_og_image do
      nil ->
        link

      local_path ->
        link
        |> Ash.Changeset.for_update(
          :update_og,
          %{og_image: local_path, og_image_pinned: true},
          authorize?: false
        )
        |> Ash.update(authorize?: false)

        link
    end
  end

  defp handle_tag_update(link, tags) do
    Weakty.Tags.TagManager.apply_tags(link, :link, tags, Weakty.Links.LinkTag, :link_id)
  end

  defp upload_error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp upload_error_to_string(:not_accepted), do: "Unsupported file type"
  defp upload_error_to_string(:too_many_files), do: "Only one image allowed"
  defp upload_error_to_string(_), do: "Upload failed"
end
