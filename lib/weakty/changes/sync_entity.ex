defmodule Weakty.Changes.SyncEntity do
  use Ash.Resource.Change
  require Logger

  @impl true
  def init(opts) do
    unless opts[:entity_type] do
      raise ArgumentError, "SyncEntity requires :entity_type option"
    end

    {:ok, opts}
  end

  @impl true
  def change(changeset, opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      skip_field = opts[:skip_if_nil]

      if skip_field && is_nil(Map.get(record, skip_field)) do
        destroy_entity_if_exists(opts[:entity_type], record.id)
        {:ok, record}
      else
        max_len = opts[:content_max_length] || 280

        entity_params = %{
          entity_type: opts[:entity_type],
          source_id: record.id,
          subtype: resolve_value(record, opts[:subtype]) |> to_string_or_nil(),
          title: resolve_value(record, opts[:title] || :title),
          content: resolve_value(record, opts[:content]) |> truncate(max_len),
          url: resolve_value(record, opts[:url]),
          slug: resolve_value(record, opts[:slug] || :slug),
          source_path: resolve_value(record, opts[:source_path]),
          hero_url: resolve_value(record, opts[:hero_url]),
          thumbnail_url: resolve_value(record, opts[:thumbnail_url]),
          rating: resolve_value(record, opts[:rating]),
          status: resolve_value(record, opts[:status]),
          favourite: resolve_value(record, opts[:favourite]) || false,
          public: resolve_value(record, opts[:public] || :public) || false,
          published_at:
            resolve_value(record, opts[:published_at])
            |> to_datetime()
            |> Kernel.||(Map.get(record, :inserted_at))
            |> Kernel.||(DateTime.utc_now())
        }

        case Weakty.Content.Entity.upsert_entity(entity_params) do
          {:ok, entity} ->
            # Sync tags relationship
            sync_entity_tags(entity, record)
            {:ok, record}

          {:error, error} ->
            Logger.error(
              "SyncEntity failed for #{opts[:entity_type]} #{record.id}: #{inspect(error)}"
            )

            {:ok, record}
        end
      end
    end)
  end

  defp destroy_entity_if_exists(entity_type, source_id) do
    case Weakty.Content.Entity.get_entity_by_source(entity_type, source_id) do
      {:ok, entity} -> Weakty.Content.Entity.delete_entity(entity)
      {:error, %Ash.Error.Query.NotFound{}} -> :ok
      {:error, _} -> :ok
    end
  end

  defp sync_entity_tags(entity, source_record) do
    # Load tags from the source record
    case Ash.load(source_record, :tags) do
      {:ok, loaded_record} ->
        source_tag_ids =
          case Map.get(loaded_record, :tags) do
            nil -> []
            tags when is_list(tags) -> Enum.map(tags, & &1.id)
            _ -> []
          end

        # Load current entity tags
        case Ash.load(entity, :tags) do
          {:ok, loaded_entity} ->
            current_tag_ids =
              case Map.get(loaded_entity, :tags) do
                nil -> []
                tags when is_list(tags) -> Enum.map(tags, & &1.id)
                _ -> []
              end

            # Find tags to add and remove
            tags_to_add = source_tag_ids -- current_tag_ids
            tags_to_remove = current_tag_ids -- source_tag_ids

            # Add new tag associations
            Enum.each(tags_to_add, fn tag_id ->
              Weakty.Content.EntityTag.create_entity_tag(%{
                entity_id: entity.id,
                tag_id: tag_id
              })
            end)

            # Remove old tag associations
            if length(tags_to_remove) > 0 do
              case Ash.load(loaded_entity, :tags) do
                {:ok, entity_with_tags} ->
                  Enum.each(entity_with_tags.tags, fn tag ->
                    if tag.id in tags_to_remove do
                      # Find and delete the join record
                      case Ash.read(Weakty.Content.EntityTag,
                             filter: [entity_id: entity.id, tag_id: tag.id]
                           ) do
                        {:ok, [join_record | _]} ->
                          Weakty.Content.EntityTag.delete_entity_tag(join_record)

                        _ ->
                          :ok
                      end
                    end
                  end)

                _ ->
                  :ok
              end
            end

          _ ->
            :ok
        end

      _ ->
        :ok
    end
  end

  defp to_datetime(%Date{} = date) do
    {:ok, dt, _} = DateTime.from_iso8601(Date.to_iso8601(date) <> "T00:00:00Z")
    dt
  end

  defp to_datetime(value), do: value

  defp resolve_value(_record, nil), do: nil
  defp resolve_value(_record, value) when is_binary(value), do: value
  defp resolve_value(record, field) when is_atom(field), do: Map.get(record, field)
  defp resolve_value(record, func) when is_function(func, 1), do: func.(record)

  defp resolve_value(record, {module, function}) when is_atom(module) and is_atom(function) do
    apply(module, function, [record])
  end

  defp truncate(nil, _max), do: nil
  defp truncate(str, max) when byte_size(str) <= max, do: str
  defp truncate(str, max), do: String.slice(str, 0, max - 1) <> "..."

  defp to_string_or_nil(nil), do: nil
  defp to_string_or_nil(value), do: to_string(value)
end
