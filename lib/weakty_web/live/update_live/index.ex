defmodule WeaktyWeb.UpdateLive.Index do
  use WeaktyWeb, :live_view
  require Ash.Query

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    updates = Weakty.Posts.Post.list_published_updates!()

    # Get the most recent update (first one since they're sorted by published_at desc)
    featured_update = List.first(updates)

    # Get remaining updates for the list
    remaining_updates = if featured_update, do: Enum.drop(updates, 1), else: []

    {:ok,
     socket
     |> assign(:featured_update, featured_update)
     |> assign(:updates, remaining_updates)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container>
      <%= if @featured_update do %>
        <!-- Featured Update (Most Recent) -->
        <article class="prose prose-p:mb-0 prose-p:mt-0 prose-p:indent-6 mx-auto py-12">
          <div class="mb-8 flex">
            <div class="flex flex-1 justify-center mb-8">
              <h1 class="text-2xl font-normal text-center tracking-wide averia">
                NOW: <%= @featured_update.title %>
              </h1>
            </div>
          </div>

          <div class="prose max-w-none">
            <%= raw(@featured_update.html) %>
          </div>
        </article>

        <!-- Divider -->
        <div class="border-t border-base-300 my-12"></div>

        <!-- Previous Updates List -->
        <%= if !Enum.empty?(@updates) do %>
          <h2 class="text-lg font-normal tracking-wide averia opacity-60 mb-8">Previous Updates</h2>
          <div class="space-y-3">
            <.content_item
              :for={update <- @updates}
              href={~p"/now/#{update.slug}"}
              title={update.title}
              date={update.published_at}
            />
          </div>
        <% end %>
      <% else %>
        <p class="text-base-content/60 text-center py-12">No updates yet</p>
      <% end %>
    </.page_container>
    """
  end


end
