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
     |> assign(form: form, link: link, tags: existing_tags)
     |> assign(:current_path, "/admin/links"), layout: {WeaktyWeb.Layouts, :admin}}
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
          data-confirm="Are you sure you want to delete this link?"
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

        message =
          if socket.assigns.link,
            do: "Link updated successfully.",
            else: "Link saved successfully."

        {:noreply, socket |> put_flash(:info, message) |> push_navigate(to: ~p"/admin/links")}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  def handle_event("delete_link", _params, socket) do
    case Ash.destroy(socket.assigns.link) do
      :ok ->
        {:noreply, push_navigate(socket, to: ~p"/admin/links")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete link")}
    end
  end

  @impl true
  def handle_info({:tag_changed, tags}, socket) do
    {:noreply, assign(socket, :tags, tags)}
  end

  defp handle_tag_update(link, tags) do
    Weakty.Tags.TagManager.apply_tags(link, :link, tags, Weakty.Links.LinkTag, :link_id)
  end
end
