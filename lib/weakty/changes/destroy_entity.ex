defmodule Weakty.Changes.DestroyEntity do
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    unless opts[:entity_type] do
      raise ArgumentError, "DestroyEntity requires :entity_type option"
    end

    {:ok, opts}
  end

  @impl true
  def change(changeset, opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      case Weakty.Content.Entity.get_entity_by_source(opts[:entity_type], record.id) do
        {:ok, entity} ->
          case Weakty.Content.Entity.delete_entity(entity) do
            :ok -> {:ok, record}
            {:ok, _} -> {:ok, record}
            {:error, error} -> {:error, error}
          end

        {:error, %Ash.Error.Query.NotFound{}} ->
          {:ok, record}

        {:error, error} ->
          {:error, error}
      end
    end)
  end
end
