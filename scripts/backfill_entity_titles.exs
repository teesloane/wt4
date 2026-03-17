require Ash.Query
import Ecto.Query, only: [from: 2]

# Find all media_log entities
entities =
  Weakty.Content.Entity
  |> Ash.Query.filter(entity_type == :media_log)
  |> Ash.read!(authorize?: false)

IO.puts("Found #{length(entities)} media_log entities")

results =
  Enum.reduce(entities, %{updated: 0, skipped: 0, errors: 0}, fn entity, acc ->
    case Ash.get(Weakty.MediaLogs.MediaLog, entity.source_id, authorize?: false) do
      {:ok, log} ->
        expected_title =
          if log.creator && log.creator != "" do
            "#{log.creator} - #{log.title}"
          else
            log.title
          end

        if entity.title == expected_title do
          Map.update!(acc, :skipped, &(&1 + 1))
        else
          IO.puts("  #{inspect(entity.title)} → #{inspect(expected_title)}")

          # Use upsert (create action with upsert? true) to update title
          params = %{
            entity_type: entity.entity_type,
            source_id: entity.source_id,
            title: expected_title,
            content: entity.content,
            url: entity.url,
            slug: entity.slug,
            source_path: entity.source_path,
            hero_url: entity.hero_url,
            thumbnail_url: entity.thumbnail_url,
            rating: entity.rating,
            subtype: entity.subtype,
            status: entity.status,
            favourite: entity.favourite || false,
            published_at: entity.published_at,
            public: entity.public || false
          }

          case Weakty.Content.Entity.upsert_entity(params, authorize?: false) do
            {:ok, _} -> Map.update!(acc, :updated, &(&1 + 1))
            {:error, err} ->
              IO.puts("  ERROR: #{inspect(err)}")
              Map.update!(acc, :errors, &(&1 + 1))
          end
        end

      {:error, _} ->
        IO.puts("  Could not find media_log for entity #{entity.id}, skipping")
        Map.update!(acc, :skipped, &(&1 + 1))
    end
  end)

IO.puts("\nDone: #{results.updated} updated, #{results.skipped} skipped, #{results.errors} errors")
