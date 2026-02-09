defmodule WeaktyWeb.PostLive.Show do
  use WeaktyWeb, :live_view

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    post = Weakty.Posts.Post
      |> Ash.Query.for_read(:get_by_slug, %{slug: slug})
      |> Ash.read_one!()
      |> Ash.load!(:user)

    # Check if user can view this post
    can_view? =
      post.public ||
        (socket.assigns[:current_user] &&
           socket.assigns.current_user.id == post.user_id)

    if can_view? do
      {:ok, assign(socket, post: post)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to view this post")
       |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <article class="mx-auto max-w-4xl px-4 py-8">
      <div class="mb-8">
        <.link navigate={~p"/posts"} class="btn btn-ghost btn-sm mb-4">
          ← Back to Posts
        </.link>

        <div class="flex items-center gap-2 mb-4">
          <div class={["badge", if(@post.status == :published, do: "badge-success", else: "badge-warning")]}>
            <%= @post.status %>
          </div>
          <%= if @post.featured do %>
            <div class="badge badge-primary">Featured</div>
          <% end %>
          <%= if @post.public do %>
            <div class="badge badge-info">Public</div>
          <% end %>
        </div>

        <h1 class="text-4xl font-bold mb-4"><%= @post.title %></h1>

        <div class="text-base-content/60 mb-6">
          <%= if @post.published_at do %>
            Published <%= format_date(@post.published_at) %>
          <% else %>
            Last updated <%= format_date(@post.updated_at) %>
          <% end %>
        </div>

        <%= if @post.featured_image do %>
          <img
            src={@post.featured_image}
            alt={@post.title}
            class="w-full rounded-lg shadow-lg mb-8"
          />
        <% end %>

        <%= if @post.excerpt do %>
          <p class="text-xl text-base-content/80 mb-8 italic"><%= @post.excerpt %></p>
        <% end %>
      </div>

      <div class="prose prose-lg max-w-none">
        <%= raw(render_markdown(@post.markdown)) %>
      </div>

      <%= if @current_user && @current_user.id == @post.user_id do %>
        <div class="divider my-8"></div>
        <div class="flex gap-2">
          <.link navigate={~p"/admin/posts/#{@post.slug}/edit"} class="btn btn-primary">
            Edit Post
          </.link>
          <%= if @post.status == :draft do %>
            <button
              phx-click="publish"
              class="btn btn-success"
            >
              Publish
            </button>
          <% else %>
            <button
              phx-click="unpublish"
              class="btn btn-warning"
            >
              Unpublish
            </button>
          <% end %>
          <button
            phx-click="delete"
            data-confirm="Are you sure you want to delete this post?"
            class="btn btn-error"
          >
            Delete
          </button>
        </div>
      <% end %>
    </article>
    """
  end

  @impl true
  def handle_event("publish", _params, socket) do
    Weakty.Posts.Post.publish_post(socket.assigns.post)
    post = Weakty.Posts.Post
      |> Ash.Query.for_read(:get_by_slug, %{slug: socket.assigns.post.slug})
      |> Ash.read_one!()
      |> Ash.load!(:user)
    {:noreply, assign(socket, post: post)}
  end

  def handle_event("unpublish", _params, socket) do
    Weakty.Posts.Post.unpublish_post(socket.assigns.post)
    post = Weakty.Posts.Post
      |> Ash.Query.for_read(:get_by_slug, %{slug: socket.assigns.post.slug})
      |> Ash.read_one!()
      |> Ash.load!(:user)
    {:noreply, assign(socket, post: post)}
  end

  def handle_event("delete", _params, socket) do
    Ash.destroy!(socket.assigns.post)
    {:noreply, push_navigate(socket, to: ~p"/posts")}
  end

  defp render_markdown(nil), do: ""
  defp render_markdown(""), do: ""

  defp render_markdown(markdown) do
    case Earmark.as_html(markdown) do
      {:ok, html, _} -> html
      {:error, _, _} -> "<p>Error rendering markdown</p>"
    end
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y")
  end
end
