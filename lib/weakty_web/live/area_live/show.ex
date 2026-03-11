defmodule WeaktyWeb.AreaLive.Show do
  use WeaktyWeb, :live_view

  on_mount {WeaktyWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Ash.get(Weakty.Tags.Tag, slug: slug) do
      {:ok, tag} ->
        unless tag.public do
          {:ok,
           socket
           |> put_flash(:error, "This area is not public")
           |> push_navigate(to: ~p"/areas")}
        else
          # Load the tag with its entities
          tag = Ash.load!(tag, [:entities], domain: Weakty.Tags)

          # Load entities with their tags for display
          entities =
            tag.entities
            |> Enum.filter(& &1.public)
            |> Enum.sort_by(& &1.published_at, {:desc, DateTime})
            |> Enum.map(fn entity ->
              Ash.load!(entity, [:tags], domain: Weakty.Content)
            end)

          {:ok,
           socket
           |> assign(:page_title, tag.name)
           |> assign(:tag, tag)
           |> assign(:entities, entities)}
        end

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Area not found")
         |> push_navigate(to: ~p"/areas")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container title={@tag.name}>
      <%= if @tag.description_html do %>
        <div class="prose mx-auto mb-10 opacity-70">
          {Phoenix.HTML.raw(@tag.description_html)}
        </div>
      <% end %>

      <%= if @entities == [] do %>
        <p class="text-base-content/60 text-center py-12">No public content in this area yet</p>
      <% else %>
        <div class="space-y-3">
          <.content_item
            :for={entity <- @entities}
            href={"#{entity.source_path}/#{entity.slug}"}
            title={entity.title}
            label={entity.subtype || entity.entity_type |> to_string() |> String.capitalize()}
            date={entity.published_at}
          />
        </div>
      <% end %>
    </.page_container>
    """
  end
end
