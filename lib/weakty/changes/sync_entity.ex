defmodule Weakty.Changes.SyncEntity do
  use Ash.Resource.Change

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
      max_len = opts[:content_max_length] || 280

      entity_params = %{
        entity_type: opts[:entity_type],
        source_id: record.id,
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
        published_at: resolve_value(record, opts[:published_at] || :inserted_at)
      }

      case Weakty.Content.Entity.upsert_entity(entity_params) do
        {:ok, _entity} -> {:ok, record}
        {:error, error} -> {:error, error}
      end
    end)
  end

  defp resolve_value(_record, nil), do: nil
  defp resolve_value(_record, value) when is_binary(value), do: value
  defp resolve_value(record, field) when is_atom(field), do: Map.get(record, field)

  defp truncate(nil, _max), do: nil
  defp truncate(str, max) when byte_size(str) <= max, do: str
  defp truncate(str, max), do: String.slice(str, 0, max - 1) <> "..."
end
