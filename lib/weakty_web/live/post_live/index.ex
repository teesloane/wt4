defmodule WeaktyWeb.PostLive.Index do
  use WeaktyWeb, :live_view
  require Ash.Query

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_posts(socket, :all)}
  end


  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto px-6 py-16">
      <div class="space-y-12">
        <%= if Enum.empty?(@posts) do %>
          <p class="text-base-content/60 text-center py-12">No posts found</p>
        <% else %>
          <%= for post <- @posts do %>
            <article class="last:border-b-0 mb-2">
              <div class="">
              <div class="flex justify-between">

                <h2 class="text-md font-normal tracking-wide averia">
                  <.link navigate={~p"/posts/#{post.slug}"} class="hover:opacity-70 transition-opacity">
                    <%= post.title %>
                  </.link>
                </h2>
                <div class="text-sm opacity-60">
                  <%= if post.published_at do %>
                    <%= format_date(post.published_at) %>
                  <% else %>
                    <%= format_date(post.updated_at) %>
                  <% end %>
                </div>
                </div>
              </div>
            </article>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end


  defp load_posts(socket, _tab) do
    assign(socket, posts: Weakty.Posts.Post.list_published_posts_only!())
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d %b %Y")
  end
end
