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
    <.page_container>
      <div class="mb-16 text-center">
        <h1 class="text-4xl font-normal mb-6 uppercase tracking-wide averia">
          Links
        </h1>
        <button
          phx-click="new_link"
          class="btn btn-sm"
        >
          Add New
        </button>
      </div>

      <div class="space-y-10">
        <%= for link <- @links do %>
          <article class="border-b border-base-300 pb-10 last:border-b-0">
            <h2 class="text-2xl font-normal mb-3 averia">
              <a
                href={link.url}
                target="_blank"
                rel="noopener noreferrer"
                class="hover:opacity-70 transition-opacity"
              >
                {link.title}
              </a>
            </h2>
            <%= if link.commentary do %>
              <div class="prose prose-sm max-w-none opacity-80 mb-4">
                {Phoenix.HTML.raw(MDEx.to_html!(link.commentary))}
              </div>
            <% end %>
            <div class="flex gap-3 text-sm opacity-60">
              <button
                phx-click="edit"
                phx-value-id={link.id}
                class="hover:opacity-100 transition-opacity"
              >
                Edit
              </button>
              <span>·</span>
              <button
                phx-click="delete"
                phx-value-slug={link.slug}
                phx-confirm="Are you sure?"
                class="hover:text-error transition-colors"
              >
                Delete
              </button>
            </div>
          </article>
        <% end %>
      </div>
    </.page_container>
    """
  end

  @impl true
  def handle_event("delete", %{"slug" => slug}, socket) do
    link =
      Weakty.Links.Link
      |> Ash.Query.for_read(:get_by_slug, %{slug: slug})
      |> Ash.read_one!()

    Ash.destroy!(link)

    links =
      Weakty.Links.Link
      |> Ash.Query.filter(user_id == ^socket.assigns.current_user.id)
      |> Ash.read!()

    {:noreply, assign(socket, links: links)}
  end

  def handle_event("new_link", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/links/new")}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/links/#{id}/edit")}
  end
end
