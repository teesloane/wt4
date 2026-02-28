defmodule WeaktyWeb.TilLive.Form do
  use WeaktyWeb, :live_view
  alias AshPhoenix.Form
  require Logger

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(params, _session, socket) do
    til =
      case params["id"] do
        nil -> nil
        id ->
          Weakty.Posts.Post
          |> Ash.get!(id)
          |> Ash.load!(:tags)
      end

    existing_tags = if til, do: Enum.map(til.tags || [], & &1.name), else: []

    form =
      if til do
        Form.for_update(til, :update, domain: Weakty.Posts, forms: [auto?: false])
      else
        Form.for_create(Weakty.Posts.Post, :create,
          domain: Weakty.Posts,
          forms: [auto?: false],
          prepare_source: fn changeset ->
            changeset
            |> Ash.Changeset.set_context(%{user_id: socket.assigns.current_user.id})
            |> Ash.Changeset.force_change_attribute(:user_id, socket.assigns.current_user.id)
            |> Ash.Changeset.force_change_attribute(:post_type, :til)
            |> Ash.Changeset.force_change_attribute(:status, :published)
          end
        )
      end
      |> Form.validate(%{})
      |> to_form()

    {:ok,
     socket
     |> assign(form: form, til: til, tags: existing_tags, tag_input: "", tag_suggestions: [])
     |> assign(:current_path, "/admin/til"),
     layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen">
      <div class="flex-1 max-w-4xl mx-auto px-8 py-8">
        <div class="flex items-center gap-4 mb-8">
          <.link navigate={~p"/admin/til"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="w-4 h-4" />
            TILs
          </.link>
          <div class="text-sm text-base-content/70">
            <%= if @til, do: "Editing", else: "New TIL" %>
          </div>
          <div class="flex-1" />
          <button type="submit" form="til-form" class="btn btn-primary btn-sm">
            <%= if @til, do: "Update", else: "Create" %>
          </button>
        </div>

        <.form id="til-form" for={@form} phx-submit="save" phx-change="validate" class="space-y-6">
          <input
            type="text"
            name={@form[:title].name}
            value={@form[:title].value}
            class="input input-ghost w-full text-2xl py-4 font-bold px-0 focus:outline-none"
            placeholder="Today I learned..."
            required
          />
          <textarea
            name={@form[:markdown].name}
            class="textarea textarea-ghost w-full min-h-[400px] text-base leading-relaxed px-0 focus:outline-none font-mono"
            placeholder="Write in markdown..."
          ><%= @form[:markdown].value %></textarea>
        </.form>
      </div>

      <div class="w-80 border-l border-base-300 bg-base-100 p-6 overflow-y-auto max-h-screen sticky top-0">
        <h2 class="text-xl font-bold mb-6">Details</h2>
        <div class="space-y-4">
          <div class="form-control">
            <label class="label mb-1">
              <span class="label-text text-sm font-semibold">Published</span>
            </label>
            <input
              type="date"
              form="til-form"
              name={@form[:published_at].name}
              value={format_date(@form[:published_at].value)}
              class="input input-bordered input-sm w-full"
            />
          </div>

          <div class="form-control">
            <label class="label mb-1">
              <span class="label-text text-sm font-semibold">Tags</span>
            </label>
            <.tag_adder tags={@tags} tag_input={@tag_input} suggestions={@tag_suggestions} />
          </div>

          <div class="divider"></div>

          <.input field={@form[:public]} type="checkbox" label="Public" form="til-form" />

          <%= if @til do %>
            <div class="divider"></div>
            <button
              type="button"
              phx-click="delete"
              data-confirm="Delete this TIL?"
              class="btn btn-error btn-sm w-full"
            >
              Delete
            </button>
          <% end %>
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

  def handle_event("save", %{"form" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, post} ->
        handle_tag_update(post, socket.assigns.tags)
        {:noreply,
         socket
         |> put_flash(:info, "Saved successfully.")
         |> push_navigate(to: ~p"/admin/til")}

      {:error, form} ->
        Logger.error("TIL save failed: #{inspect(form.source.errors)}")
        {:noreply,
         socket
         |> put_flash(:error, "Could not save.")
         |> assign(form: to_form(form))}
    end
  end

  def handle_event("delete", _params, socket) do
    case Ash.destroy(socket.assigns.til) do
      :ok -> {:noreply, push_navigate(socket, to: ~p"/admin/til")}
      {:ok, _} -> {:noreply, push_navigate(socket, to: ~p"/admin/til")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to delete")}
    end
  end

  defp handle_tag_update(post, tags) do
    Weakty.Tags.TagManager.apply_tags(
      post, :post, tags,
      Weakty.Posts.PostTag, :post_id
    )
  end

  defp format_date(nil), do: ""
  defp format_date(%DateTime{} = dt), do: DateTime.to_date(dt) |> Date.to_iso8601()
  defp format_date(%Date{} = d), do: Date.to_iso8601(d)
  defp format_date(s) when is_binary(s), do: s
end
