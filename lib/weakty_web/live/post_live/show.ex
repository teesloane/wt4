defmodule WeaktyWeb.PostLive.Show do
  use WeaktyWeb, :live_view

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    post = Weakty.Posts.Post
      |> Ash.Query.for_read(:get_by_slug, %{slug: slug})
      |> Ash.read_one!()
      |> Ash.load!([:user, :tags])

    related = get_related_content(post)

    {:ok,
     socket
     |> assign(post: post)
     |> assign(related: related)
     |> assign(og_content: post)
     |> assign(page_title: post.title)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container>
    <article>
      <header class="text-center mb-16">

        <h1 class="text-xl font-normal leading-tight tracking-wider uppercase mb-8 averia">
          <%= @post.title %>
        </h1>

        <div class="flex items-center justify-center gap-4 mt-8">
          <div class="text-center">
            <div class="text-sm lowercase flex divide-solid tracking-wider gap-3  mb-6 opacity-70">
              <%= if @post.published_at do %>
                <span class="capitalize"><%= @post.post_type || "" %></span>
                  <span> • </span>
                  <span> <%= format_date(@post.published_at) %> </span>
                  <span> • </span>
                  <span> <%= estimate_read_time(@post.html) %> min read</span>
              <% else %>
                <%= format_date(@post.updated_at) %> • Draft
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

      <div class="prose prose-p:mb-0 prose-p:mt-0 prose-p:indent-6 mx-auto py-12">

        <%= raw(@post.html) %>
      </div>

      <%= if @current_user && @current_user.id == @post.user_id do %>
        <div class="border-t border-base-300 mt-16 pt-8 text-center">
          <div class="flex gap-3 justify-center">
            <.link navigate={~p"/admin/posts/#{@post.id}/edit"} class="btn btn-primary btn-sm">
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

    <%= if @related != [] do %>
      <aside class="text-sm border-base-300 mt-4 pt-4 border border-base-300 p-4  mx-auto">
        <h3 class="uppercase tracking-widest opacity-40 mb-8">Maybe Related?</h3>
        <div class="space-y-2">
          <%= for entity <- @related do %>
            <div class="flex items-baseline opacity-50 hover:opacity-70 ">
              <div class="flex items-baseline gap-3 w-full min-w-0">
              <%= if entity.published_at do %>
                <span class="flex-shrink-0"><%= format_date(entity.published_at) %></span>
              <% end %>

                <.link
                  navigate={"#{entity.source_path}/#{entity.slug}"}
                  class="hover:opacity-60 transition-opacity truncate w-full flex-1"
                >
                  <%= entity.title %>
                </.link>

                
                <span class="capitalize flex-shrink-0">(<%= entity.entity_type %>:</span>
                <%= for tag <- Enum.slice(entity.tags, 0..2) do %>
                #<%= tag.name %>
                <% end %>
                )
              </div>
            </div>
          <% end %>
        </div>
      </aside>
    <% end %>
    </.page_container>
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

  defp get_related_content(post) do
    tag_ids = Enum.map(post.tags, & &1.id)

    if Enum.empty?(tag_ids) do
      []
    else
      case Weakty.Content.Entity.related_entities(tag_ids, post.id) do
        {:ok, entities} ->
          entities
          |> Ash.load!(:tags, domain: Weakty.Content)
          |> Enum.map(fn entity ->
            score = Enum.count(entity.tags, fn t -> t.id in tag_ids end)
            {score, entity}
          end)
          |> Enum.sort_by(fn {score, entity} ->
            type_priority = if entity.entity_type == :post, do: 0, else: 1
            {-score, type_priority}
          end)
          |> Enum.take(6)
          |> Enum.map(fn {_score, entity} -> entity end)

        _ ->
          []
      end
    end
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%Y/%m/%d")
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
    max(1, round(word_count / 250))
  end

  defp estimate_read_time(_), do: 1
end
