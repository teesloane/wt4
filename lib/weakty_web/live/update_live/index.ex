defmodule WeaktyWeb.UpdateLive.Index do
  use WeaktyWeb, :live_view

  import WeaktyWeb.UpdateLive.WeekActivity

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    updates = Weakty.Posts.Post.list_published_updates!()

    featured_update = List.first(updates)
    remaining_updates = if featured_update, do: Enum.drop(updates, 1), else: []

    week_entities =
      if featured_update.published_at, do: load_week_entities(featured_update.published_at), else: []

    week_media_logs =
      if featured_update.published_at, do: load_week_media_logs(featured_update.published_at), else: []

    {:ok,
     socket
     |> assign(:featured_update, featured_update)
     |> assign(:week_entities, week_entities)
     |> assign(:week_media_logs, week_media_logs)
     |> assign(:updates, remaining_updates)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container title={"NOW"}>
      <:header>
        <div class="text-center text-base">
          {@featured_update.title}
        </div>
      </:header>

      <%= if @featured_update do %>
        <article class="prose prose-p:mb-0 prose-p:mt-0 prose-p:indent-6 mx-auto">
          <div class="prose max-w-none">
            {raw(@featured_update.html)}
          </div>
        </article>

        <.week_activity week_entities={@week_entities} week_media_logs={@week_media_logs} />

        <div class="border-t border-base-300 my-12"></div>

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
