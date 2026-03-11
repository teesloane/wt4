defmodule WeaktyWeb.ArchiveLive.Index do
  use WeaktyWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Get all public entities and sort by published date (most recent first)
    entities =
      Weakty.Content.Entity.list_entities!()
      |> Ash.load!([:tags], domain: Weakty.Content)
      |> Enum.filter(& &1.public)
      |> Enum.sort_by(& &1.published_at, {:desc, DateTime})
      |> Enum.uniq_by(&{&1.entity_type, &1.slug})

    {:ok, assign(socket, entities: entities)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container title="Archive">
      <div class="space-y-3">
        <.content_item
          :for={e <- @entities}
          href={if e.entity_type != :media_log, do: "#{e.source_path}/#{e.slug}"}
          title={e.title}
          date={e.published_at}
          label={human_label(e.subtype || e.entity_type)}
        />
      </div>
    </.page_container>
    """
  end

  defp human_label("fiction"), do: "short story"
  defp human_label(label), do: label |> to_string() |> String.replace("_", " ")
end
