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
