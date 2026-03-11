defmodule WeaktyWeb.AdminLive.Dashboard do
  use WeaktyWeb, :live_view

  import WeaktyWeb.AdminComponents

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign(:current_path, "/admin")
     |> load_stats(), layout: {WeaktyWeb.Layouts, :admin}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_header title="Dashboard" subtitle="Overview of your content">
      <:actions>
        <div class="flex gap-2">
          <.link navigate="/admin/posts/new" class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="w-4 h-4" /> New Post
          </.link>
          <.link navigate="/admin/til/new" class="btn btn-sm">
            <.icon name="hero-plus" class="w-4 h-4" /> New TIL
          </.link>
          <.link navigate="/admin/quotes/new" class="btn btn-sm">
            <.icon name="hero-plus" class="w-4 h-4" /> New Quote
          </.link>
        </div>
      </:actions>
    </.admin_header>

    <div class="p-8">
      <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4 mb-8">
        <.stat_card label="Total Posts" value={@stats.total_posts} />
        <.stat_card label="Published" value={@stats.published_posts} />
        <.stat_card label="Drafts" value={@stats.draft_posts} />
        <.stat_card label="Links" value={@stats.total_links} />
        <.stat_card label="TILs" value={@stats.total_tils} />
        <.stat_card label="Quotes" value={@stats.total_quotes} />
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body">
            <h2 class="card-title">Quick Actions</h2>
            <div class="flex flex-col gap-2">
              <.link navigate="/admin/posts" class="btn btn-ghost justify-start">
                <.icon name="hero-document-text" class="w-5 h-5" /> Manage Posts
              </.link>
              <.link navigate="/admin/til" class="btn btn-ghost justify-start">
                <.icon name="hero-light-bulb" class="w-5 h-5" /> Manage TILs
              </.link>
              <.link navigate="/admin/quotes" class="btn btn-ghost justify-start">
                <.icon name="hero-chat-bubble-left" class="w-5 h-5" /> Manage Quotes
              </.link>
              <.link navigate="/admin/links" class="btn btn-ghost justify-start">
                <.icon name="hero-link" class="w-5 h-5" /> Manage Links
              </.link>
              <.link navigate="/admin/tags" class="btn btn-ghost justify-start">
                <.icon name="hero-tag" class="w-5 h-5" /> Manage Tags
              </.link>
              <.link navigate="/archive" class="btn btn-ghost justify-start">
                <.icon name="hero-eye" class="w-5 h-5" /> View Site
              </.link>
            </div>
          </div>
        </div>

        <div class="card bg-base-200 shadow-sm">
          <div class="card-body">
            <h2 class="card-title">Recent Activity</h2>
            <div class="space-y-2">
              <%= if @recent_posts != [] do %>
                <div class="text-sm">
                  <p class="font-semibold mb-2">Recent Posts:</p>
                  <ul class="space-y-1">
                    <%= for post <- @recent_posts do %>
                      <li>
                        <.link
                          navigate={~p"/posts/#{post.slug}"}
                          class="link link-hover text-base-content/70"
                        >
                          {post.title}
                        </.link>
                        <.status_badge status={post.status} />
                      </li>
                    <% end %>
                  </ul>
                </div>
              <% else %>
                <p class="text-base-content/70">No recent posts</p>
              <% end %>

              <%= if @recent_links != [] do %>
                <div class="text-sm mt-4">
                  <p class="font-semibold mb-2">Recent Links:</p>
                  <ul class="space-y-1">
                    <%= for link <- @recent_links do %>
                      <li>
                        <.link
                          navigate={~p"/admin/links/#{link.id}/edit"}
                          class="link link-hover text-base-content/70"
                        >
                          {link.title}
                        </.link>
                      </li>
                    <% end %>
                  </ul>
                </div>
              <% else %>
                <p class="text-base-content/70 mt-4">No recent links</p>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp load_stats(socket) do
    require Ash.Query

    all_posts = Weakty.Posts.Post.list_posts!()
    posts = Enum.filter(all_posts, &(&1.post_type in [:post, :update, :page]))
    published_posts = Enum.filter(posts, &(&1.status == :published))
    draft_posts = Enum.filter(posts, &(&1.status == :draft))
    tils = Enum.filter(all_posts, &(&1.post_type == :til))
    quotes = Enum.filter(all_posts, &(&1.post_type == :quote))
    links = Ash.read!(Weakty.Links.Link)

    recent_posts = posts |> Enum.take(5)
    recent_links = links |> Enum.take(5)

    socket
    |> assign(:stats, %{
      total_posts: length(posts),
      published_posts: length(published_posts),
      draft_posts: length(draft_posts),
      total_links: length(links),
      total_tils: length(tils),
      total_quotes: length(quotes)
    })
    |> assign(:recent_posts, recent_posts)
    |> assign(:recent_links, recent_links)
  end
end
