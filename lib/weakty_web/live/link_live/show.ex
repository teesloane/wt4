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
          <p class="opacity-80 leading-relaxed mb-6">{@link.commentary}</p>
        <% end %>

        <%= if @link.tags && length(@link.tags) > 0 do %>
          <div class="flex flex-wrap gap-3 text-sm opacity-60">
            <%= for tag <- @link.tags do %>
              <span>#{tag.name}</span>
            <% end %>
          </div>
        <% end %>
      </article>
    </.page_container>
    """
  end

  defp admin?(socket) do
    socket.assigns[:current_user] != nil
  end
end
