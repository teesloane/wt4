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
        <dl class="flex justify-center gap-8 mb-8 text-xs tracking-widest">
          <div class="flex flex-col items-center gap-1">
            <dt class="uppercase opacity-30">Type</dt>
            <dd class="capitalize opacity-60">Update</dd>
          </div>
          <div class="flex flex-col items-center gap-1">
            <dt class="uppercase opacity-30">Date</dt>
            <dd class="opacity-60 tabular-nums">
              {if @post.published_at, do: format_date(@post.published_at), else: "Draft"}
            </dd>
          </div>
        </dl>
      </:header>

      <%= if @post.featured_image do %>
        <% srcset = Weakty.ImageProcessor.srcset_for(@post.featured_image) %>
        <img
          src={@post.featured_image}
          srcset={srcset}
          sizes={srcset && "(max-width: 400px) 400px, (max-width: 800px) 800px, 1200px"}
          alt={@post.title}
          class="w-full mb-12 rounded"
        />
      <% end %>

      <article class="prose prose-p:mb-0 prose-p:mt-0 prose-p:indent-6 mx-auto py-12">
        <div class="prose max-w-none">
          {raw(@post.html)}
        </div>
      </article>

      <%= if @current_user && @current_user.id == @post.user_id do %>
        <div class="border-t border-base-300 mt-16 pt-8 text-center">
          <div class="flex gap-3 justify-center">
            <.link navigate={~p"/admin/posts/#{@post.id}/edit"} class="btn btn-primary btn-sm">
              Edit
            </.link>
          </div>
        </div>
      <% end %>

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
