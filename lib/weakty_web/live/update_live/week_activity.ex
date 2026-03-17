defmodule WeaktyWeb.UpdateLive.WeekActivity do
  use Phoenix.Component
  require Ash.Query

  import WeaktyWeb.CoreComponents

  attr :week_entities, :list, required: true
  attr :week_media_logs, :list, required: true

  def week_activity(assigns) do
    ~H"""
    <div :if={@week_entities != [] or @week_media_logs !=[]}
    class="border border-base-300 p-8 mt-8 mb-16 bg-base-200/50 rounded-sm">
    <%= if @week_entities != [] do %>
      <h2 class="text-sm uppercase font-sans font-bold tracking-wide averia opacity-60 mb-8">
        Around the site this week:
      </h2>
      <div class="space-y-3">
        <%= for entity <- @week_entities do %>
          <.content_item
            href={entity_href(entity)}
            title={entity.title}
            date={entity.published_at}
            label={entity_type_label(entity)}
          />
        <% end %>
      </div>
    <% end %>

    <div class="my-8" :if={@week_media_logs != [] and @week_entities != []} />

    <%= if @week_media_logs != [] do %>
      <h2 class="text-sm uppercase font-sans font-bold tracking-wide averia opacity-60 mb-8">
        Reading / Listening:
      </h2>
      <div class="space-y-3">
        <%= for log <- @week_media_logs do %>
          <div class="flex items-center gap-3 group">
            <%= if log.thumbnail_url do %>
              <img
                src={log.thumbnail_url}
                alt={log.title}
                class="w-10 h-10 object-cover rounded shrink-0"
              />
            <% else %>
              <div class="w-10 h-10 bg-base-200 rounded shrink-0 flex items-center justify-center text-base-content/30 text-xs">
                {log.media_type |> to_string() |> String.at(0) |> String.upcase()}
              </div>
            <% end %>
            <div class="min-w-0">
              <div class="text-sm truncate">{log.title}</div>
              <%= if log.creator do %>
                <div class="text-xs opacity-50">{log.creator}</div>
              <% end %>
            </div>
            <span class="ml-auto text-xs opacity-30 shrink-0">
              {log.media_type |> to_string() |> String.replace("_", " ")}
            </span>
          </div>
        <% end %>
      </div>
    <% end %>
      </div>
    """
  end

  def load_week_entities(published_at) do
    from_dt = DateTime.add(published_at, -6 * 24 * 60 * 60, :second)

    Weakty.Content.Entity
    |> Ash.Query.for_read(:timeline)
    |> Ash.Query.filter(
      public == true and
        not (entity_type == :post and subtype == "update") and
        not (entity_type == :media_log) and
        published_at >= ^from_dt and
        published_at <= ^published_at
    )
    |> Ash.read!(authorize?: false)
  end

  def load_week_media_logs(published_at) do
    from_date = published_at |> DateTime.add(-6 * 24 * 60 * 60, :second) |> DateTime.to_date()
    to_date = DateTime.to_date(published_at)

    music =
      Weakty.MediaLogs.MediaLog
      |> Ash.Query.filter(
        public == true and
          media_type == :music and
          date_consumed >= ^from_date and
          date_consumed <= ^to_date
      )
      |> Ash.read!(authorize?: false)

    books =
      Weakty.MediaLogs.MediaLog
      |> Ash.Query.filter(
        public == true and
          (media_type == :book or media_type == :comic) and
          date_started <= ^to_date and
          (is_nil(date_finished) or date_finished >= ^from_date)
      )
      |> Ash.read!(authorize?: false)

    music ++ books
  end

  defp entity_href(%{source_path: source_path, slug: slug}), do: "#{source_path}/#{slug}"

  defp entity_type_label(%{entity_type: :post, subtype: subtype})
       when subtype in ["til", "quote", "fiction"],
       do: subtype

  defp entity_type_label(%{entity_type: type}),
    do: type |> to_string() |> String.replace("_", " ")
end
