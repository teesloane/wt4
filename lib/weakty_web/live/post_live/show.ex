defmodule WeaktyWeb.PostLive.Show do
  use WeaktyWeb, :live_view

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    post = Weakty.Posts.Post
      |> Ash.Query.for_read(:get_by_slug, %{slug: slug})
      |> Ash.read_one!()
      |> Ash.load!(:user)

    {:ok, assign(socket, post: post)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <article class="max-w-3xl mx-auto px-6 py-16">
      <header class="text-center mb-16">
        <div class="text-sm lowercase tracking-wider mb-6 opacity-70">
          <%= @post.post_type || "essay" %>
        </div>

        <h1 class="text-xl font-normal leading-tight tracking-wider uppercase mb-8 averia">
          <%= @post.title %>
        </h1>

        <div class="flex items-center justify-center gap-4 mt-8">
          <div class="w-12 h-12 rounded-full bg-base-200 border-2 border-base-300 flex-shrink-0">
            <!-- Avatar placeholder - you can add user avatar here -->
          </div>
          <div class="text-left">
            <div class="text-lg font-normal mb-1">
              <%= if @post.user, do: @post.user.email |> to_string() |> String.split("@") |> hd(), else: "Anonymous" %>
            </div>
            <div class="text-sm opacity-60">
              <%= if @post.published_at do %>
                <%= format_date(@post.published_at) %> · <%= estimate_read_time(@post.html) %> min read
              <% else %>
                <%= format_date(@post.updated_at) %> · Draft
              <% end %>
            </div>
          </div>
        </div>
      </header>

      <%= if @post.featured_image do %>
        <img
          src={@post.featured_image}
          alt={@post.title}
          class="w-full mb-12 rounded"
        />
      <% end %>

      <div class="prose mx-auto">
        <%= raw(@post.html) %>
      </div>

      <%= if @current_user && @current_user.id == @post.user_id do %>
        <div class="border-t border-base-300 mt-16 pt-8 text-center">
          <div class="flex gap-3 justify-center">
            <.link navigate={~p"/admin/posts/#{@post.slug}/edit"} class="btn btn-primary btn-sm">
              Edit Post
            </.link>
            <%= if @post.status == :draft do %>
              <button
                phx-click="publish"
                class="btn btn-success btn-sm"
              >
                Publish
              </button>
            <% else %>
              <button
                phx-click="unpublish"
                class="btn btn-warning btn-sm"
              >
                Unpublish
              </button>
            <% end %>
            <button
              phx-click="delete"
              data-confirm="Are you sure you want to delete this post?"
              class="btn btn-error btn-sm"
            >
              Delete
            </button>
          </div>
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

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d %b %Y")
  end

  defp estimate_read_time(html) when is_binary(html) do
    # Remove HTML tags and count words
    text = html
    |> String.replace(~r/<[^>]*>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()

    word_count = text
    |> String.split(" ")
    |> length()

    # Average reading speed: 200 words per minute
    max(1, round(word_count / 200))
  end

  defp estimate_read_time(_), do: 1
end
