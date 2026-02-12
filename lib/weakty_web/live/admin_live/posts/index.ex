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
        <div class="space-y-4 font-sans">
          <%= for post <- @posts do %>
            <div
              class="flex gap-4 p-2 bg-base-100 rounded-lg hover:bg-base-200/50 cursor-pointer transition-colors "
              phx-click={JS.navigate(~p"/admin/posts/#{post.id}/edit")}
            >
              <!-- Featured Image Thumbnail -->
              <div class="flex-shrink-0 relative">
                <%= if post.featured_image do %>
                  <img
                    src={post.featured_image}
                    alt={post.title}
                    class="w-24 h-16 object-cover rounded-lg"
                    onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';"
                  />
                  <%# for displaying failed icons for broken image %>
                  <div class="w-24 h-16 bg-base-200 rounded-lg items-center justify-center hidden">
                    <.icon name="hero-exclamation-circle" class="w-6 h-6 text-base-content/20" />
                  </div>
                <% else %>
                  <div class="w-24 h-16 bg-base-200 rounded-lg flex items-center justify-center">
                    <.icon name="hero-photo" class="w-6 h-6 text-base-content/20" />
                  </div>
                <% end %>
              </div>

              <!-- Post Details -->
              <div class="flex-1 min-w-0">
                <h3 class="font-bold text-sm text-base-content mb-0">
                  <%= post.title %>
                </h3>

                <p class="text-base-content/60 text-sm mb-2">
                  By <%= if post.user, do: post.user.email |> to_string() |> String.split("@") |> hd(), else: "Unknown" %>
                  in <%= post.post_type || "post" %>
                  - <%= if post.status == :published && post.published_at do %>
                    <%= Calendar.strftime(post.published_at, "%d %b %Y") %>
                  <% else %>
                    <%= Calendar.strftime(post.updated_at, "%d %b %Y") %>
                  <% end %>
                </p>

                <%= if post.status == :draft do %>
                  <p class="text-pink-500 font-medium text-sm">Draft</p>
                <% else %>
                  <p class="text-base-content/60 text-sm">Published</p>
                <% end %>
              </div>
            </div>
            <hr class="text-base-300" />
          <% end %>
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

    # Load tags and user relationships
    posts = Ash.load!(posts, [:tags, :user])

    # Sort only in "all posts" mode: published by date, then drafts at top
    posts =
      if socket.assigns.filter == "all" do
        {drafts, published} = Enum.split_with(posts, fn post -> post.status == :draft end)

        # Sort published by published_at (most recent first)
        published = Enum.sort_by(published, & &1.published_at, {:desc, DateTime})

        # Sort drafts by updated_at (most recent first)
        drafts = Enum.sort_by(drafts, & &1.updated_at, {:desc, DateTime})

        # Drafts at top, then published
        drafts ++ published
      else
        posts
      end

    assign(socket, :posts, posts)
  end
end
