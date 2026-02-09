defmodule WeaktyWeb.PostLive.Index do
  use WeaktyWeb, :live_view
  require Ash.Query

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

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
          <button
            phx-click="new_post"
            class="btn btn-primary"
          >
            New Post
          </button>
        </div>

        <div class="tabs tabs-boxed mt-6">
          <a
            class={["tab", if(@tab == :all, do: "tab-active")]}
            phx-click="change_tab"
            phx-value-tab="all"
          >
            All
          </a>
          <a
            class={["tab", if(@tab == :published, do: "tab-active")]}
            phx-click="change_tab"
            phx-value-tab="published"
          >
            Published
          </a>
          <a
            class={["tab", if(@tab == :drafts, do: "tab-active")]}
            phx-click="change_tab"
            phx-value-tab="drafts"
          >
            Drafts
          </a>
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
            <div class="card bg-base-200 shadow-xl hover:shadow-2xl transition-shadow">
              <div class="card-body">
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <h2 class="card-title text-2xl">
                      <.link navigate={~p"/posts/#{post.id}"} class="link link-hover">
                        <%= post.title %>
                      </.link>
                    </h2>
                    <%= if post.excerpt do %>
                      <p class="text-base-content/70 mt-2"><%= post.excerpt %></p>
                    <% end %>
                  </div>
                  <div class={["badge badge-lg", if(post.status == :published, do: "badge-success", else: "badge-warning")]}>
                    <%= post.status %>
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

                <div class="card-actions justify-end mt-4">
                  <%= if post.status == :draft do %>
                    <button
                      phx-click="publish"
                      phx-value-id={post.id}
                      class="btn btn-sm btn-success"
                    >
                      Publish
                    </button>
                  <% else %>
                    <button
                      phx-click="unpublish"
                      phx-value-id={post.id}
                      class="btn btn-sm btn-warning"
                    >
                      Unpublish
                    </button>
                  <% end %>
                  <button
                    phx-click="edit"
                    phx-value-id={post.id}
                    class="btn btn-sm btn-ghost"
                  >
                    Edit
                  </button>
                  <button
                    phx-click="delete"
                    phx-value-id={post.id}
                    data-confirm="Are you sure you want to delete this post?"
                    class="btn btn-sm btn-error"
                  >
                    Delete
                  </button>
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

  def handle_event("edit", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/posts/#{id}/edit")}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    post = Ash.get!(Weakty.Posts.Post, id)
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
      case tab do
        :published ->
          Weakty.Posts.Post.list_published_posts!()

        :drafts ->
          Weakty.Posts.Post.list_drafts!()

        _ ->
          Weakty.Posts.Post
          |> Ash.Query.sort(updated_at: :desc)
          |> Ash.read!()
      end
      |> Enum.filter(&(&1.user_id == socket.assigns.current_user.id))

    assign(socket, posts: posts, tab: tab)
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y")
  end
end
