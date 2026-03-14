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
  def handle_event("refresh_og", %{"id" => id}, socket) do
    %{"link_id" => id}
    |> Weakty.Workers.FetchLinkMetadata.new()
    |> Oban.insert()

    {:noreply, put_flash(socket, :info, "Refreshing Open Graph data...")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_header title="Links" subtitle={"#{length(@links)} link#{if length(@links) != 1, do: "s"}"}>
      <:actions>
        <.link navigate="/admin/links/new" class="btn btn-primary">
          <.icon name="hero-plus" class="w-4 h-4" /> New Link
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
              <.icon name="hero-plus" class="w-4 h-4" /> Create Link
            </.link>
          </div>
        </div>
      <% else %>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          <%= for link <- @links do %>
            <div class="card bg-base-200 shadow-sm hover:shadow-md transition-shadow">
              <%!-- OG thumbnail --%>
              <figure class="relative aspect-video bg-base-300 overflow-hidden rounded-t-2xl">
                <%= if link.og_image do %>
                  <img
                    src={link.og_image}
                    alt={link.og_title || link.title}
                    class="w-full h-full object-cover"
                  />
                <% else %>
                  <div class="w-full h-full flex items-center justify-center">
                    <.icon name="hero-link" class="w-12 h-12 text-base-content/20" />
                  </div>
                <% end %>
                <%!-- Public badge --%>
                <div class="absolute top-2 right-2">
                  <%= if link.public do %>
                    <span class="badge badge-success badge-sm">public</span>
                  <% else %>
                    <span class="badge badge-ghost badge-sm">draft</span>
                  <% end %>
                </div>
              </figure>

              <div class="card-body p-3 gap-2">
                <%!-- Title --%>
                <h3
                  class="font-semibold text-sm leading-snug line-clamp-2 cursor-pointer hover:text-primary"
                  phx-click={JS.navigate(~p"/admin/links/#{link.id}/edit")}
                >
                  {link.og_title || link.title}
                </h3>

                <%!-- OG description if different from title --%>
                <%= if link.og_description do %>
                  <p class="text-xs text-base-content/60 line-clamp-2">{link.og_description}</p>
                <% end %>

                <%!-- URL --%>
                <a
                  href={link.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-xs text-primary truncate hover:underline"
                  onclick="event.stopPropagation()"
                >
                  {link.url |> String.replace(~r/^https?:\/\//, "") |> String.slice(0..50)}
                </a>

                <%!-- Tags --%>
                <%= if link.tags && link.tags != [] do %>
                  <div class="flex gap-1 flex-wrap">
                    <%= for tag <- Enum.take(link.tags, 3) do %>
                      <span class="badge badge-xs">{tag.name}</span>
                    <% end %>
                    <%= if length(link.tags) > 3 do %>
                      <span class="badge badge-xs badge-ghost">+{length(link.tags) - 3}</span>
                    <% end %>
                  </div>
                <% end %>

                <%!-- Actions --%>
                <div class="flex gap-1 pt-1 border-t border-base-300">
                  <.link
                    navigate={~p"/admin/links/#{link.id}/edit"}
                    class="btn btn-ghost btn-xs flex-1"
                    title="Edit"
                  >
                    <.icon name="hero-pencil" class="w-3 h-3" />
                  </.link>
                  <a
                    href={link.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="btn btn-ghost btn-xs flex-1"
                    title="Visit"
                  >
                    <.icon name="hero-arrow-top-right-on-square" class="w-3 h-3" />
                  </a>
                  <button
                    phx-click="refresh_og"
                    phx-value-id={link.id}
                    class="btn btn-ghost btn-xs flex-1"
                    title="Refresh Open Graph"
                  >
                    <.icon name="hero-arrow-path" class="w-3 h-3" />
                  </button>
                  <button
                    phx-click="delete"
                    phx-value-id={link.id}
                    data-confirm="Are you sure you want to delete this link?"
                    class="btn btn-ghost btn-xs text-error flex-1"
                    title="Delete"
                  >
                    <.icon name="hero-trash" class="w-3 h-3" />
                  </button>
                </div>
              </div>
            </div>
          <% end %>
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
