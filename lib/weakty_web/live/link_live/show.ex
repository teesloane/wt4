defmodule WeaktyWeb.LinkLive.Show do
  use WeaktyWeb, :live_view

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    link =
      Weakty.Links.Link
      |> Ash.Query.for_read(:get_by_slug, %{slug: slug})
      |> Ash.read_one!()
      |> Ash.load!(:tags)

    if is_nil(link) or (not link.public and not admin?(socket)) do
      {:ok, push_navigate(socket, to: ~p"/links")}
    else
      {:ok,
       socket
       |> assign(link: link)
       |> assign(page_title: link.title)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container>
      <article>
        <header class="mb-8">
          <div class="text-sm lowercase tracking-wider mb-4 opacity-70">link</div>
          <h1 class="text-2xl font-normal averia mb-4">
            <a
              href={@link.url}
              target="_blank"
              rel="noopener noreferrer"
              class="hover:opacity-70 transition-opacity"
            >
              {@link.title} →
            </a>
          </h1>
          <div class="text-sm opacity-60">
            {Calendar.strftime(@link.inserted_at, "%d %b %Y")}
          </div>
        </header>

        <%= if @link.commentary do %>
          <div class="prose max-w-none mb-6">
            {Phoenix.HTML.raw(MDEx.to_html!(@link.commentary))}
          </div>
        <% end %>

        <%= if @link.tags && length(@link.tags) > 0 do %>
          <div class="flex flex-wrap gap-3 text-sm opacity-60">
            <%= for tag <- @link.tags do %>
              <span>#{tag.name}</span>
            <% end %>
          </div>
        <% end %>

        <%= if @current_user do %>
          <div class="border-t border-base-300 mt-16 pt-8 text-center">
            <div class="flex gap-3 justify-center">
              <.link navigate={~p"/admin/links/#{@link.id}/edit"} class="btn btn-primary btn-sm">
                Edit Link
              </.link>
              <%= if @link.public do %>
                <button phx-click="unpublish" class="btn btn-warning btn-sm">
                  Make Private
                </button>
              <% else %>
                <button phx-click="publish" class="btn btn-success btn-sm">
                  Make Public
                </button>
              <% end %>
              <button
                phx-click="delete"
                phx-confirm="Are you sure you want to delete this link?"
                class="btn btn-error btn-sm"
              >
                Delete
              </button>
            </div>
          </div>
        <% end %>
      </article>
    </.page_container>
    """
  end

  @impl true
  def handle_event("publish", _params, socket) do
    {:ok, link} = Ash.update(socket.assigns.link, %{public: true}, action: :update)
    {:noreply, assign(socket, link: link)}
  end

  def handle_event("unpublish", _params, socket) do
    {:ok, link} = Ash.update(socket.assigns.link, %{public: false}, action: :update)
    {:noreply, assign(socket, link: link)}
  end

  def handle_event("delete", _params, socket) do
    Ash.destroy!(socket.assigns.link)
    {:noreply, push_navigate(socket, to: ~p"/links")}
  end

  defp admin?(socket) do
    socket.assigns[:current_user] != nil
  end
end
