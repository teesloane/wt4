
defmodule WeaktyWeb.LinkLive.Index do
  use WeaktyWeb, :live_view
  require Ash.Query

  # on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
      links =
        Weakty.Links.Link
        |> Ash.read!()

      {:ok, assign(socket, links: links)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl px-4 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold">My Links</h1>
        <button
          phx-click="new_link"
          class="btn btn-primary mt-4"
        >
          Add New Link
        </button>
      </div>

      <div class="space-y-4">
        <%= for link <- @links do %>
          <div class="card bg-base-200 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">
                <a href={link.url} target="_blank" class="link">
                  <%= link.title %>
                </a>
              </h2>
              <%= if link.commentary do %>
                <p><%= link.commentary %></p>
              <% end %>
              <div class="card-actions justify-end">
                <button
                  phx-click="edit"
                  phx-value-id={link.id}
                  class="btn btn-sm btn-ghost"
                >
                  Edit
                </button>
                <button
                  phx-click="delete"
                  phx-value-id={link.id}
                  data-confirm="Are you sure?"
                  class="btn btn-sm btn-error"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    link = Ash.get!(Weakty.Links.Link, id)
    Ash.destroy!(link)

    links =
      Weakty.Links.Link
      |> Ash.Query.filter(user_id == ^socket.assigns.current_user.id)
      |> Ash.read!()

    {:noreply, assign(socket, links: links)}
  end

  def handle_event("new_link", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/links/new")}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/links/#{id}/edit")}
  end
end
