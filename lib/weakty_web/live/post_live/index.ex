defmodule WeaktyWeb.PostLive.Index do
  use WeaktyWeb, :live_view
  require Ash.Query

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_posts(socket, :all)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    tab = params["tab"] || "all"
    {:noreply, load_posts(socket, String.to_atom(tab))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl px-4 py-8">
      <div class="mb-8">
        <div class="flex justify-between items-center">
          <h1 class="text-3xl font-bold">Posts</h1>
        </div>
      </div>

      <div class="space-y-4">
        <%= if Enum.empty?(@posts) do %>
          <div class="card bg-base-200">
            <div class="card-body text-center">
              <p class="text-base-content/60">No posts found</p>
            </div>
          </div>
        <% else %>
          <%= for post <- @posts do %>
            <div class="card bg-base-100 cursor-pointer shadow-sm hover:shadow-md transition-shadow">
              <div class="card-body">
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <h2 class="card-title text-2xl">
                      <.link navigate={~p"/posts/#{post.slug}"} class="link link-hover">
                        <%= post.title %>
                      </.link>
                    </h2>
                    <%= if post.excerpt do %>
                      <p class="text-base-content/70 mt-2"><%= post.excerpt %></p>
                    <% end %>
                  </div>
                </div>

                <div class="flex items-center gap-4 text-sm text-base-content/60 mt-2">
                  <%= if post.published_at do %>
                    <span>Published <%= format_date(post.published_at) %></span>
                  <% else %>
                    <span>Updated <%= format_date(post.updated_at) %></span>
                  <% end %>
                  <%= if post.featured do %>
                    <span class="badge badge-sm badge-primary">Featured</span>
                  <% end %>
                  <%= if post.public do %>
                    <span class="badge badge-sm badge-info">Public</span>
                  <% end %>
                </div>

              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: ~p"/posts?tab=#{tab}")}
  end

  def handle_event("new_post", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/posts/new")}
  end

  def handle_event("edit", %{"slug" => slug}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/posts/#{slug}/edit")}
  end

  def handle_event("delete", %{"slug" => slug}, socket) do
    post = Weakty.Posts.Post
      |> Ash.Query.for_read(:get_by_slug, %{slug: slug})
      |> Ash.read_one!()
    Ash.destroy!(post)

    {:noreply, load_posts(socket, socket.assigns.tab)}
  end

  def handle_event("publish", %{"id" => id}, socket) do
    post = Ash.get!(Weakty.Posts.Post, id)
    Weakty.Posts.Post.publish_post(post)

    {:noreply, load_posts(socket, socket.assigns.tab)}
  end

  def handle_event("unpublish", %{"id" => id}, socket) do
    post = Ash.get!(Weakty.Posts.Post, id)
    Weakty.Posts.Post.unpublish_post(post)

    {:noreply, load_posts(socket, socket.assigns.tab)}
  end

  defp load_posts(socket, tab) do
    posts =
          Weakty.Posts.Post
          |> Ash.Query.sort(updated_at: :desc)
          |> Ash.read!()


    assign(socket, posts: posts, tab: tab)
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y")
  end
end
