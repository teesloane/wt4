defmodule WeaktyWeb.AdminLive.Links.Index do
  use WeaktyWeb, :live_view

  import WeaktyWeb.AdminComponents

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Links")
     |> assign(:current_path, "/admin/links")
     |> load_links(), layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    link = Ash.get!(Weakty.Links.Link, id)

    case Ash.destroy(link) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Link deleted successfully")
         |> load_links()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete link")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_header title="Links" subtitle={"#{length(@links)} link#{if length(@links) != 1, do: "s"}"}>
      <:actions>
        <.link navigate="/admin/links/new" class="btn btn-primary">
          <.icon name="hero-plus" class="w-4 h-4" />
          New Link
        </.link>
      </:actions>
    </.admin_header>

    <div class="p-8">
      <%= if @links == [] do %>
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body items-center text-center">
            <.icon name="hero-link" class="w-16 h-16 text-base-content/30" />
            <h2 class="card-title">No links yet</h2>
            <p class="text-base-content/70">Create your first link to get started</p>
            <.link navigate="/admin/links/new" class="btn btn-primary mt-4">
              <.icon name="hero-plus" class="w-4 h-4" />
              Create Link
            </.link>
          </div>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Title</th>
                <th>URL</th>
                <th>Tags</th>
                <th>Created</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for link <- @links do %>
                <tr class="hover cursor-pointer" phx-click={JS.navigate(~p"/admin/links/#{link.id}/edit")}>
                  <td>
                    <div class="font-bold"><%= link.title %></div>
                    <%= if link.commentary do %>
                      <div class="text-sm text-base-content/70 max-w-md truncate">
                        <%= link.commentary %>
                      </div>
                    <% end %>
                  </td>
                  <td>
                    <a
                      href={link.url}
                      target="_blank"
                      rel="noopener noreferrer"
                      class="link link-primary text-sm"
                      onclick="event.stopPropagation()"
                    >
                      <%= link.url |> String.replace(~r/^https?:\/\//, "") |> String.slice(0..40) %><%= if String.length(
                                                                                                            link.url
                                                                                                          ) > 40,
                                                                                                          do: "..." %>
                      <.icon name="hero-arrow-top-right-on-square" class="w-3 h-3 inline" />
                    </a>
                  </td>
                  <td>
                    <%= if link.tags && link.tags != [] do %>
                      <div class="flex gap-1 flex-wrap">
                        <%= for tag <- Enum.take(link.tags, 3) do %>
                          <span class="badge badge-sm"><%= tag.name %></span>
                        <% end %>
                        <%= if length(link.tags) > 3 do %>
                          <span class="badge badge-sm badge-ghost">+<%= length(link.tags) - 3 %></span>
                        <% end %>
                      </div>
                    <% else %>
                      <span class="text-base-content/50">-</span>
                    <% end %>
                  </td>
                  <td>
                    <%= if link.inserted_at do %>
                      <div class="text-sm">
                        <%= Calendar.strftime(link.inserted_at, "%b %d, %Y") %>
                      </div>
                    <% else %>
                      <span class="text-base-content/50">-</span>
                    <% end %>
                  </td>
                  <td onclick="event.stopPropagation()">
                    <div class="flex gap-2">
                      <.link
                        navigate={~p"/admin/links/#{link.id}/edit"}
                        class="btn btn-ghost btn-xs"
                        title="Edit"
                      >
                        <.icon name="hero-pencil" class="w-4 h-4" />
                      </.link>
                      <a
                        href={link.url}
                        target="_blank"
                        rel="noopener noreferrer"
                        class="btn btn-ghost btn-xs"
                        title="Visit"
                      >
                        <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" />
                      </a>
                      <button
                        phx-click="delete"
                        phx-value-id={link.id}
                        data-confirm="Are you sure you want to delete this link?"
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
    """
  end

  defp load_links(socket) do
    links = Ash.read!(Weakty.Links.Link, load: [:tags])
    assign(socket, :links, links)
  end
end
