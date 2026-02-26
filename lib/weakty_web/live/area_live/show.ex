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
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <div class="mb-8">
        <.link navigate={~p"/areas"} class="text-sm text-base-content/70 hover:text-base-content mb-4 inline-block">
          ← Back to Areas
        </.link>

        <%= if @tag.featured_image do %>
          <div class="w-full h-64 mb-8 rounded-lg overflow-hidden">
            <img src={@tag.featured_image} alt={@tag.name} class="w-full h-full object-cover" />
          </div>
        <% end %>

        <h1 class="text-4xl font-bold mb-4"><%= @tag.name %></h1>

        <%= if @tag.description_html do %>
          <div class="prose max-w-none mb-8">
            <%= Phoenix.HTML.raw(@tag.description_html) %>
          </div>
        <% end %>
      </div>

      <div class="mb-8">
        <p class="text-base-content/70 mb-6">
          <%= length(@entities) %> item<%= if length(@entities) != 1, do: "s" %>
        </p>
      </div>

      <%= if @entities == [] do %>
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body items-center text-center">
            <p class="text-base-content/70">No public content in this area yet</p>
          </div>
        </div>
      <% else %>
        <div class="space-y-6">
          <%= for entity <- @entities do %>
            <div class="card bg-base-100 shadow-lg">
              <div class="card-body">
                <div class="flex items-start justify-between gap-4">
                  <div class="flex-1">
                    <div class="flex items-center gap-2 mb-2">
                      <span class="badge badge-sm"><%= entity.entity_type %></span>
                      <%= if entity.published_at do %>
                        <span class="text-sm text-base-content/60">
                          <%= Calendar.strftime(entity.published_at, "%B %d, %Y") %>
                        </span>
                      <% end %>
                    </div>

                    <h3 class="card-title mb-2">
                      <.link navigate={"#{entity.source_path}/#{entity.slug}"} class="hover:underline">
                        <%= entity.title %>
                      </.link>
                    </h3>


                    <%= if entity.content do %>
                      <p class="text-base-content/70 mb-4"><%= entity.content %></p>
                    <% end %>

                    <%= if length(entity.tags) > 0 do %>
                      <div class="flex flex-wrap gap-2">
                        <%= for tag <- entity.tags do %>
                          <%= if tag.public do %>
                            <.link navigate={~p"/areas/#{tag.slug}"} class="badge badge-outline badge-sm">
                              <%= tag.name %>
                            </.link>
                          <% else %>
                            <span class="badge badge-ghost badge-sm"><%= tag.name %></span>
                          <% end %>
                        <% end %>
                      </div>
                    <% end %>
                  </div>

                  <%= if entity.thumbnail_url || entity.hero_url do %>
                    <div class="w-32 h-32 flex-shrink-0">
                      <img
                        src={entity.thumbnail_url || entity.hero_url}
                        alt={entity.title}
                        class="w-full h-full object-cover rounded"
                      />
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
