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
    <.page_container title="Posts">
      <%= if Enum.empty?(@posts) do %>
        <p class="text-base-content/60 text-center py-12">No posts found</p>
      <% else %>
        <div class="space-y-3">
          <div :for={post <- @posts} class="flex items-baseline gap-6">
            <a
              href={~p"/posts/#{post.slug}"}
              class="flex-1 no-underline hover:opacity-50 transition-opacity text-sm truncate"
            >
              {post.title}
            </a>
            <span class="text-xs opacity-30 tabular-nums flex-shrink-0 capitalize">
              {post.post_type}
            </span>
            <time class="text-xs opacity-30 tabular-nums flex-shrink-0">
              {if d = post.published_at || post.updated_at, do: Calendar.strftime(d, "%Y-%m-%d")}
            </time>
          </div>
        </div>
      <% end %>
    </.page_container>
    """
  end

  defp load_posts(socket, _tab) do
    assign(socket, posts: Weakty.Posts.Post.list_published_posts_only!())
  end
end
