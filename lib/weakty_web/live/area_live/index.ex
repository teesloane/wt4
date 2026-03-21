defmodule WeaktyWeb.AreaLive.Index do
  use WeaktyWeb, :live_view

  import Ecto.Query

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    require Ash.Query

    areas =
      Weakty.Tags.Tag
      |> Ash.Query.filter(public == true)
      |> Ash.read!()
      |> Enum.sort_by(& &1.name)

    tag_ids = Enum.map(areas, & &1.id)

    area_counts =
      Weakty.Repo.all(
        from t in "tags",
          where: t.id in ^tag_ids,
          left_join: pt in "post_tags", on: pt.tag_id == t.id,
          left_join: lt in "link_tags", on: lt.tag_id == t.id,
          left_join: mt in "media_log_tags", on: mt.tag_id == t.id,
          left_join: pr in "project_tags", on: pr.tag_id == t.id,
          group_by: t.id,
          select: {
            t.id,
            count(pt.post_id, :distinct) + count(lt.link_id, :distinct) +
              count(mt.media_log_id, :distinct) + count(pr.project_id, :distinct)
          }
      )
      |> Map.new()

    {:ok,
     socket
     |> assign(:page_title, "Areas")
     |> assign(:areas, areas)
     |> assign(:area_counts, area_counts)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container  title="Areas of Interest">
      <%= if @areas == [] do %>
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body items-center text-center">
            <p class="text-base-content/70">No public areas yet</p>
          </div>
        </div>
      <% else %>
        <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
          <%= for area <- @areas do %>
            <.link
              navigate={~p"/areas/#{area.slug}"}
              class=""
            >
              <%= if area.featured_image do %>
                <figure class="aspect-video">
                  <img src={area.featured_image} alt={area.name} class="w-full h-full object-cover" />
                </figure>
              <% end %>
              <div class="">
                <div class="text-sm">{area.name} ({Map.get(@area_counts, area.id, 0)}) </div>
                <%!--

                <%= if area.description do %>
                  <p class="text-base-content/70 line-clamp-3">
                    {String.slice(area.description, 0..150)}{if String.length(area.description) > 150,
                      do: "..."}
                  </p>
                <% end %>
                <div class="card-actions justify-end mt-4">
                  <div class="text-sm text-base-content/60">
                    {Map.get(@area_counts, area.id, 0)} items
                  </div>
                </div>
                --%>
              </div>
            </.link>
          <% end %>
        </div>
      <% end %>
    </.page_container>
    """
  end
end
