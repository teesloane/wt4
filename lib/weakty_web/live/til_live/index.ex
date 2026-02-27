defmodule WeaktyWeb.TilLive.Index do
  use WeaktyWeb, :live_view
  require Ash.Query

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    tils =
      Weakty.Tils.Til
      |> Ash.Query.filter(public == true)
      |> Ash.Query.sort(published_at: :desc)
      |> Ash.read!(load: [:tags])

    {:ok, assign(socket, tils: tils)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container>
      <h1 class="text-4xl font-normal mb-16 text-center uppercase tracking-wide averia">
        TIL
      </h1>

      <div class="divide-y divide-base-content/10">
        <%= for til <- @tils do %>
          <article class="py-8">
            <div class="flex items-baseline gap-4 mb-3">
              <time class="text-xs opacity-40 tabular-nums flex-shrink-0">
                <%= if til.published_at, do: Calendar.strftime(til.published_at, "%Y-%m-%d") %>
              </time>
              <h2 class="text-lg font-normal averia">
                <.link navigate={~p"/til/#{til.slug}"} class="hover:opacity-70 transition-opacity">
                  <%= til.title %>
                </.link>
              </h2>
            </div>
            <%= if til.tags && length(til.tags) > 0 do %>
              <div class="flex gap-2 flex-wrap ml-[calc(theme(spacing.4)+1rem)] text-xs opacity-50">
                <%= for tag <- til.tags do %>
                  <span>#<%= tag.name %></span>
                <% end %>
              </div>
            <% end %>
          </article>
        <% end %>
      </div>
    </.page_container>
    """
  end
end
