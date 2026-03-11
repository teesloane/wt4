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
     |> assign(:type, "all")
     |> load_posts(), layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    filter = Map.get(params, "filter", "all")
    type = Map.get(params, "type", "all")

    {:noreply,
     socket
     |> assign(:filter, filter)
     |> assign(:type, type)
     |> load_posts()}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    post = Ash.get!(Weakty.Posts.Post, id)

    case Weakty.Posts.Post.delete_post(post) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Post deleted successfully")
         |> load_posts()}

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
        <div class="dropdown dropdown-end">
          <div tabindex="0" role="button" class="btn btn-sm btn-primary">
            <.icon name="hero-plus" class="w-4 h-4" /> New…
          </div>
          <ul
            tabindex="0"
            class="dropdown-content menu bg-base-100 rounded-box border border-base-300 shadow-lg z-10 w-40 p-1 mt-1"
          >
            <li><.link navigate="/admin/posts/new?type=post">Post</.link></li>
            <li><.link navigate="/admin/til/new">TIL</.link></li>
            <li><.link navigate="/admin/quotes/new">Quote</.link></li>
            <li><.link navigate="/admin/posts/new?type=update">Update</.link></li>
          </ul>
        </div>
      </:actions>
    </.admin_header>

    <div class="p-8">
      <div class="mb-4 flex gap-2 flex-wrap items-center">
        <.link
          patch={~p"/admin/posts?filter=all&type=#{@type}"}
          class={["btn btn-sm", if(@filter == "all", do: "btn-active", else: "btn-ghost")]}
        >
          All [{@counts.all}]
        </.link>
        <.link
          patch={~p"/admin/posts?filter=published&type=#{@type}"}
          class={["btn btn-sm", if(@filter == "published", do: "btn-active", else: "btn-ghost")]}
        >
          Published [{@counts.published}]
        </.link>
        <.link
          patch={~p"/admin/posts?filter=drafts&type=#{@type}"}
          class={["btn btn-sm", if(@filter == "drafts", do: "btn-active", else: "btn-ghost")]}
        >
          Drafts [{@counts.drafts}]
        </.link>
        <.link
          patch={~p"/admin/posts?filter=untagged&type=#{@type}"}
          class={["btn btn-sm", if(@filter == "untagged", do: "btn-active", else: "btn-ghost")]}
        >
          Untagged [{@counts.untagged}]
        </.link>

        <div class="w-px h-5 bg-base-300 mx-1"></div>

        <div class="dropdown">
          <div
            tabindex="0"
            role="button"
            class={["btn btn-sm", if(@type != "all", do: "btn-active", else: "btn-ghost")]}
          >
            {if @type == "all", do: "Type", else: String.capitalize(@type)} [{Map.get(
              @counts.by_type,
              @type,
              if(@type == "all", do: @counts.all, else: 0)
            )}] <.icon name="hero-chevron-down" class="w-3 h-3" />
          </div>
          <ul
            tabindex="0"
            class="dropdown-content menu bg-base-100 rounded-box z-10 w-48 p-2 shadow border border-base-300 mt-1"
          >
            <li>
              <.link
                patch={~p"/admin/posts?filter=#{@filter}&type=all"}
                class={if(@type == "all", do: "active", else: "")}
              >
                All Types
              </.link>
            </li>
            <%= for type <- Weakty.Posts.PostType.values() do %>
              <% count = Map.get(@counts.by_type, to_string(type), 0) %>
              <li>
                <.link
                  patch={~p"/admin/posts?filter=#{@filter}&type=#{type}"}
                  class={if(@type == to_string(type), do: "active", else: "")}
                >
                  {type |> to_string() |> String.capitalize()} [{count}]
                </.link>
              </li>
            <% end %>
          </ul>
        </div>
      </div>

      <%= if @posts == [] do %>
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body items-center text-center">
            <.icon name="hero-document-text" class="w-16 h-16 text-base-content/30" />
            <h2 class="card-title">No posts yet</h2>
            <p class="text-base-content/70">Create your first post to get started</p>
            <.link navigate="/admin/posts/new" class="btn btn-primary mt-4">
              <.icon name="hero-plus" class="w-4 h-4" /> Create Post
            </.link>
          </div>
        </div>
      <% else %>
        <div class="space-y-4 font-sans">
          <%= for post <- @posts do %>
            <div
              class="flex gap-4 p-2 bg-base-100 rounded-lg hover:bg-base-200/50 cursor-pointer transition-colors "
              phx-click={
                JS.navigate(
                  "/admin/posts/#{post.id}/edit?return_to=#{URI.encode_www_form("/admin/posts?filter=#{@filter}&type=#{@type}")}"
                )
              }
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
                  <%!-- for displaying failed icons for broken image --%>
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
                  {post.title}
                </h3>

                <p class="text-base-content/60 text-sm mb-2">
                  By {if post.user,
                    do: post.user.email |> to_string() |> String.split("@") |> hd(),
                    else: "Unknown"} in {post.post_type || "post"} -
                  <%= if post.status == :published && post.published_at do %>
                    {Calendar.strftime(post.published_at, "%d %b %Y")}
                  <% else %>
                    {Calendar.strftime(post.updated_at, "%d %b %Y")}
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
    all_posts = Weakty.Posts.Post.list_posts!() |> Ash.load!([:tags, :user])

    counts = %{
      all: length(all_posts),
      published: Enum.count(all_posts, &(&1.status == :published)),
      drafts: Enum.count(all_posts, &(&1.status == :draft)),
      untagged: Enum.count(all_posts, &Enum.empty?(&1.tags)),
      by_type: Enum.frequencies_by(all_posts, &to_string(&1.post_type))
    }

    posts =
      case socket.assigns.filter do
        "published" -> Enum.filter(all_posts, &(&1.status == :published))
        "drafts" -> Enum.filter(all_posts, &(&1.status == :draft))
        "untagged" -> Enum.filter(all_posts, &Enum.empty?(&1.tags))
        _ -> all_posts
      end

    posts =
      case socket.assigns.type do
        "all" -> posts
        type -> Enum.filter(posts, fn post -> to_string(post.post_type) == type end)
      end

    {drafts, published} = Enum.split_with(posts, fn post -> post.status == :draft end)
    published = Enum.sort_by(published, & &1.published_at, {:desc, DateTime})
    drafts = Enum.sort_by(drafts, & &1.updated_at, {:desc, DateTime})
    posts = drafts ++ published

    socket |> assign(:posts, posts) |> assign(:counts, counts)
  end
end
