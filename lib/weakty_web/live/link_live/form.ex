
defmodule WeaktyWeb.LinkLive.Form do
  use WeaktyWeb, :live_view
  alias AshPhoenix.Form

  @impl true
  def mount(params, _session, socket) do
    if socket.assigns[:current_user] do
      link =
        case params["id"] do
          nil -> nil
          id ->
            Weakty.Links.Link
            |> Ash.get!(id)
            |> Ash.load!(:tags)
        end

      # Extract existing tag names if editing
      existing_tags = if link, do: Enum.map(link.tags || [], & &1.name), else: []

      form =
        if link do
          Form.for_update(link, :update, domain: Weakty.Links, forms: [auto?: false])
        else
          Form.for_create(Weakty.Links.Link, :create,
            domain: Weakty.Links,
            forms: [auto?: false],
            prepare_source: fn changeset ->
              Ash.Changeset.set_context(changeset, %{user_id: socket.assigns.current_user.id})
            end
          )
        end
        |> Form.validate(%{})
        |> to_form()

      {:ok,
       socket
       |> assign(form: form, link: link, tags: existing_tags, tag_input: "")
       |> assign(:current_path, "/admin/links"),
       layout: {WeaktyWeb.Layouts, :admin}}
    else
      {:ok, redirect(socket, to: "/sign-in")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">
        <%= if @link, do: "Edit Link", else: "New Link" %>
      </h1>

      <.form
        for={@form}
        phx-submit="save"
        phx-change="validate"
        class="space-y-4"
      >
        <div class="form-control">
          <label class="label">
            <span class="label-text">URL</span>
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
            <span class="label-text">Title</span>
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
            <span class="label-text">Commentary</span>
          </label>
          <textarea
            name={@form[:commentary].name}
            class="textarea textarea-bordered w-full h-32"
          ><%= @form[:commentary].value %></textarea>
        </div>

        <div class="form-control">
          <label class="label">
            <span class="label-text">Tags</span>
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
              placeholder="Add a tag (press Enter)"
              class="input input-bordered join-item w-full"
              phx-keydown="add_tag"
              phx-key="Enter"
            />
            <button
              type="button"
              phx-click="add_tag"
              class="btn btn-primary join-item"
            >
              Add
            </button>
          </div>
        </div>

        <.input field={@form[:public]} type="checkbox" label="Public" />

        <input
          type="hidden"
          name={@form[:user_id].name}
          value={@current_user.id}
        />

        <div class="flex gap-2">
          <button type="submit" class="btn btn-primary">
            Save
          </button>
          <.link navigate={~p"/links"} class="btn btn-ghost">
            Cancel
          </.link>
        </div>
      </.form>
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

  def handle_event("save", %{"form" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, link} ->
        handle_tag_update(link, socket.assigns.tags)
        {:noreply, push_navigate(socket, to: ~p"/admin/links")}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  defp handle_tag_update(link, tags) do
    Weakty.Tags.TagManager.apply_tags(link, :link, tags, Weakty.Links.LinkTag, :link_id)
  end
end
