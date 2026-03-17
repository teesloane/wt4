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
          <.content_item
            :for={post <- @posts}
            title={post.title}
            href={~p"/posts/#{post.slug}"}
            label={to_string(post.post_type)}
            label_position={:right}
            date={post.published_at || post.updated_at}
          />
        </div>
      <% end %>
    </.page_container>
    """
  end

  defp load_posts(socket, _tab) do
    assign(socket, posts: Weakty.Posts.Post.list_published_posts_only!())
  end
end
