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
     |> load_tags(), layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def handle_event("start_edit", %{"id" => id}, socket) do
    tag = Enum.find(socket.assigns.tags, &(&1.id == id))
    {:noreply, assign(socket, editing_tag: tag)}
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, editing_tag: nil)}
  end

  @impl true
  def handle_event("update_tag", %{"tag" => %{"name" => name}}, socket) do
    case Weakty.Tags.Tag.update_tag(socket.assigns.editing_tag, %{name: name}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Tag updated successfully")
         |> assign(:editing_tag, nil)
         |> load_tags()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update tag")}
    end
  end

  @impl true
  def handle_event("create_tag", %{"tag" => %{"name" => name}}, socket) do
    case Weakty.Tags.Tag.create_tag(%{name: name}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Tag created successfully")
         |> assign(:new_tag_name, "")
         |> load_tags()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create tag")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    tag = Ash.get!(Weakty.Tags.Tag, id)

    case Weakty.Tags.Tag.delete_tag(tag) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Tag deleted successfully")
         |> load_tags()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete tag")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_header title="Tags" subtitle={"#{length(@tags)} tag#{if length(@tags) != 1, do: "s"}"}>
      <:actions>
        <button
          class="btn btn-primary"
          onclick="document.getElementById('new_tag_modal').showModal()"
        >
          <.icon name="hero-plus" class="w-4 h-4" />
          New Tag
        </button>
      </:actions>
    </.admin_header>

    <div class="p-8">
      <%= if @tags == [] do %>
        <div class="card bg-base-200 shadow-xl">
          <div class="card-body items-center text-center">
            <.icon name="hero-tag" class="w-16 h-16 text-base-content/30" />
            <h2 class="card-title">No tags yet</h2>
            <p class="text-base-content/70">Create your first tag to organize your content</p>
            <button
              class="btn btn-primary mt-4"
              onclick="document.getElementById('new_tag_modal').showModal()"
            >
              <.icon name="hero-plus" class="w-4 h-4" />
              Create Tag
            </button>
          </div>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Name</th>
                <th>Slug</th>
                <th>Posts</th>
                <th>Links</th>
                <th>Total Usage</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for tag <- @tags do %>
                <tr class="hover">
                  <td>
                    <span class="badge badge-lg"><%= tag.name %></span>
                  </td>
                  <td>
                    <code class="text-sm text-base-content/70"><%= tag.slug %></code>
                  </td>
                  <td>
                    <div class="text-sm">
                      <%= if tag.posts do %>
                        <%= length(tag.posts) %>
                      <% else %>
                        0
                      <% end %>
                    </div>
                  </td>
                  <td>
                    <div class="text-sm">
                      <%= if tag.links do %>
                        <%= length(tag.links) %>
                      <% else %>
                        0
                      <% end %>
                    </div>
                  </td>
                  <td>
                    <div class="font-semibold">
                      <%= (if(tag.posts, do: length(tag.posts), else: 0) + if(tag.links, do: length(tag.links), else: 0)) %>
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
                        data-confirm="Are you sure you want to delete this tag? This will remove it from all posts and links."
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
    </div>
    <%!-- New Tag Modal --%>
    <dialog id="new_tag_modal" class="modal">
      <div class="modal-box">
        <h3 class="font-bold text-lg mb-4">Create New Tag</h3>
        <.form for={%{}} phx-submit="create_tag">
          <.input type="text" name="tag[name]" label="Tag Name" value={@new_tag_name} required />
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
        <div class="modal-box">
          <h3 class="font-bold text-lg mb-4">Edit Tag</h3>
          <.form for={%{}} phx-submit="update_tag">
            <.input
              type="text"
              name="tag[name]"
              label="Tag Name"
              value={@editing_tag.name}
              required
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
    tags = Weakty.Tags.Tag.list_tags!()
    tags = Ash.load!(tags, [:links, :posts])
    assign(socket, :tags, tags)
  end
end
