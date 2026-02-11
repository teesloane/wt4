defmodule WeaktyWeb.AdminLive.Posts.Index do
  use WeaktyWeb, :live_view

  import WeaktyWeb.AdminComponents

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Posts")
     |> assign(:current_path, "/admin/posts")
     |> assign(:filter, "all")
     |> load_posts(), layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    filter = Map.get(params, "filter", "all")

    {:noreply,
     socket
     |> assign(:filter, filter)
     |> load_posts()}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    post = Ash.get!(Weakty.Posts.Post, id)

    case Weakty.Posts.Post.delete_post(post) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post deleted successfully")
         |> load_posts()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete post")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_header title="Posts" subtitle={"#{length(@posts)} post#{if length(@posts) != 1, do: "s"}"}>
      <:actions>
        <.link navigate="/admin/posts/new" class="btn btn-primary">
          <.icon name="hero-plus" class="w-4 h-4" />
          New Post
        </.link>
      </:actions>
    </.admin_header>

    <div class="p-8">
      <div class="mb-4 flex gap-2">
        <.link
          patch={~p"/admin/posts?filter=all"}
          class={["btn btn-sm", if(@filter == "all", do: "btn-active", else: "btn-ghost")]}
        >
          All Posts
        </.link>
        <.link
          patch={~p"/admin/posts?filter=published"}
          class={["btn btn-sm", if(@filter == "published", do: "btn-active", else: "btn-ghost")]}
        >
          Published
        </.link>
        <.link
          patch={~p"/admin/posts?filter=drafts"}
          class={["btn btn-sm", if(@filter == "drafts", do: "btn-active", else: "btn-ghost")]}
        >
          Drafts
        </.link>
      </div>

      <%= if @posts == [] do %>
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body items-center text-center">
            <.icon name="hero-document-text" class="w-16 h-16 text-base-content/30" />
            <h2 class="card-title">No posts yet</h2>
            <p class="text-base-content/70">Create your first post to get started</p>
            <.link navigate="/admin/posts/new" class="btn btn-primary mt-4">
              <.icon name="hero-plus" class="w-4 h-4" />
              Create Post
            </.link>
          </div>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Title</th>
                <th>Excerpt</th>
                <th>Status</th>
                <th>Published</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for post <- @posts do %>
                <tr class="hover cursor-pointer" phx-click={JS.navigate(~p"/admin/posts/#{post.slug}/edit")}>
                  <td>
                    <div>
                      <div class="font-bold"><%= post.title %></div>
                      <%= if post.tags && post.tags != [] do %>
                        <div class="text-sm opacity-50 flex gap-1 mt-1">
                          <%= for tag <- Enum.take(post.tags, 3) do %>
                            <span class="badge badge-xs"><%= tag.name %></span>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  </td>
                  <td>
                    <div class="text-sm text-base-content/70 max-w-md truncate">
                      <%= post.excerpt %>
                    </div>
                  </td>
                  <td>
                    <.status_badge status={post.status} />
                  </td>
                  <td>
                    <%= if post.published_at do %>
                      <div class="text-sm">
                        <%= Calendar.strftime(post.published_at, "%b %d, %Y") %>
                      </div>
                    <% else %>
                      <span class="text-base-content/50">-</span>
                    <% end %>
                  </td>
                  <td onclick="event.stopPropagation()">
                    <div class="flex gap-2">
                      <.link
                        navigate={~p"/admin/posts/#{post.slug}/edit"}
                        class="btn btn-ghost btn-xs"
                        title="Edit"
                      >
                        <.icon name="hero-pencil" class="w-4 h-4" />
                      </.link>
                      <.link
                        navigate={~p"/posts/#{post.slug}"}
                        class="btn btn-ghost btn-xs"
                        title="View"
                      >
                        <.icon name="hero-eye" class="w-4 h-4" />
                      </.link>
                      <button
                        phx-click="delete"
                        phx-value-id={post.id}
                        data-confirm="Are you sure you want to delete this post?"
                        class="btn btn-ghost btn-xs text-error"
                        title="Delete"
                      >
                        <.icon name="hero-trash" class="w-4 h-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  defp load_posts(socket) do
    posts =
      case socket.assigns.filter do
        "published" -> Weakty.Posts.Post.list_published_posts!()
        "drafts" -> Weakty.Posts.Post.list_drafts!()
        _ -> Weakty.Posts.Post.list_posts!()
      end

    # Load tags relationship
    posts = Ash.load!(posts, :tags)

    assign(socket, :posts, posts)
  end
end
