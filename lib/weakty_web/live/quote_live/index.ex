defmodule WeaktyWeb.QuoteLive.Index do
  use WeaktyWeb, :live_view
  require Ash.Query

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    quotes =
      Weakty.Posts.Post
      |> Ash.Query.filter(post_type == :quote and public == true)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read!()

    {:ok, assign(socket, quotes: quotes)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container>
      <h1 class="text-4xl font-normal mb-16 text-center uppercase tracking-wide averia">
        Quotes
      </h1>

      <div class="space-y-12">
        <%= for quote <- @quotes do %>
          <blockquote class="border-l-2 border-base-content/20 pl-6">
            <p class="text-xl font-normal leading-relaxed averia mb-4">
              "<%= quote.markdown %>"
            </p>
            <%= if quote.attribution do %>
              <footer class="text-sm opacity-60">
                <%= if quote.attribution_url do %>
                  <a href={quote.attribution_url} target="_blank" rel="noopener noreferrer" class="hover:opacity-100">
                    — <%= quote.attribution %>
                  </a>
                <% else %>
                  — <%= quote.attribution %>
                <% end %>
              </footer>
            <% end %>
          </blockquote>
        <% end %>
      </div>
    </.page_container>
    """
  end
end
