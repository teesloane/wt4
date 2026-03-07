defmodule WeaktyWeb.FictionLive.Index do
  use WeaktyWeb, :live_view
  require Ash.Query

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {_, posts} = Weakty.Posts.Post.list_fiction
      # Weakty.Posts.Post
      # |> Ash.Query.filter(status == :published and post_type == :fiction)
      # |> Ash.Query.sort(published_at: :desc)
      # |> Ash.read!()

    {:ok, assign(socket, posts: posts)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container title={"Fiction"}>
      <%= if Enum.empty?(@posts) do %>
        <p class="text-base-content/60 text-center py-12">No fiction found</p>
      <% else %>
        <div class="space-y-3">
          <.content_item
            :for={post <- @posts}
            href={~p"/posts/#{post.slug}"}
            title={post.title}
            date={post.published_at || post.updated_at}
          />
        </div>
      <% end %>
    </.page_container>
    """
  end
end
