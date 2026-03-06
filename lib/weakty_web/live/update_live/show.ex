defmodule WeaktyWeb.UpdateLive.Show do
  use WeaktyWeb, :live_view
  require Ash.Query

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    post =
      Weakty.Posts.Post
      |> Ash.Query.for_read(:get_by_slug, %{slug: slug})
      |> Ash.read_one!()

    all_updates = Weakty.Posts.Post.list_published_updates!()
    {:ok,
     socket
     |> assign(:post, post)
     |> assign(:updates, all_updates)
     |> assign(:page_title, post.title)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container title={@post.title}>
      <:header>
        <div class="text-sm lowercase flex justify-center tracking-wider gap-3 mb-6 opacity-70">
          <%= if @post.published_at do %>
            <span>Now (an update)</span>
            <span> • </span>
            <span><%= format_date(@post.published_at) %></span>
          <% else %>
            <span><%= format_date(@post.updated_at) %> • Draft</span>
          <% end %>
        </div>
      </:header>

      <article class="prose prose-p:mb-0 prose-p:mt-0 prose-p:indent-6 mx-auto py-12">
        <div class="prose max-w-none">
          <%= raw(@post.html) %>
        </div>
      </article>

      <%= if !Enum.empty?(@updates) do %>
        <div class="border-t border-base-300 my-12"></div>
        <h2 class="text-lg font-normal tracking-wide averia opacity-60 mb-8">Updates</h2>
        <div class="space-y-3">
          <.content_item
            :for={update <- @updates}
            href={~p"/now/#{update.slug}"}
            title={update.title}
            date={update.published_at}
            current={update.id == @post.id}
          />
        </div>
      <% end %>
    </.page_container>
    """
  end

  defp format_date(datetime), do: Calendar.strftime(datetime, "%Y/%m/%d")
end
