defmodule Weakty.Tags.TagManager do
  @moduledoc """
  Manages tag creation, assignment, and entity tag syncing across all resource types.

  Usage from a form's save handler:

      defp handle_tag_update(link, tags) do
        Weakty.Tags.TagManager.apply_tags(link, :link, tags, Weakty.Links.LinkTag, :link_id)
      end
  """

  require Ash.Query

  @doc """
  Syncs tags for a resource. Creates new tag join records, removes stale ones,
  and updates the corresponding entity's tags array.
  """
  def apply_tags(resource, entity_type, tag_names, join_module, resource_key) do
    domain = Ash.Resource.Info.domain(join_module)

    # Find or create each tag
    tags =
      tag_names
      |> Enum.map(&find_or_create_tag/1)
      |> Enum.filter(& &1)

    new_tag_ids = MapSet.new(tags, & &1.id)

    # Load current join records for this resource
    existing_joins =
      join_module
      |> Ash.Query.filter_input(%{resource_key => resource.id})
      |> Ash.read!(domain: domain)

    # Remove join records for tags no longer in the list
    existing_joins
    |> Enum.reject(fn j -> MapSet.member?(new_tag_ids, j.tag_id) end)
    |> Enum.each(&Ash.destroy!(&1, domain: domain))

    # Add join records for new tags not already linked
    existing_tag_ids = MapSet.new(existing_joins, & &1.tag_id)

    tags
    |> Enum.reject(fn tag -> MapSet.member?(existing_tag_ids, tag.id) end)
    |> Enum.each(fn tag ->
      params = %{resource_key => resource.id, tag_id: tag.id}
      Ash.create!(join_module, params, domain: domain)
    end)

    # Sync the entity's denormalized tags array
    sync_entity_tags(entity_type, resource.id, tag_names)

    :ok
  end

  @doc """
  Finds an existing tag by name or creates a new one.
  Returns the tag struct or nil on error.
  """
  def find_or_create_tag(name) do
    case Weakty.Tags.Tag
         |> Ash.Query.filter(name == ^name)
         |> Ash.read_one(domain: Weakty.Tags) do
      {:ok, nil} ->
        case Weakty.Tags.Tag.create_tag(%{name: name}) do
          {:ok, tag} -> tag
          _ -> nil
        end

      {:ok, tag} ->
        tag

      _ ->
        nil
    end
  end

  @doc """
  Deletes tags that are not linked to any resource.
  Returns {:ok, count} with the number of deleted tags.
  """
  def cleanup_orphaned_tags do
    orphaned =
      Weakty.Tags.Tag.list_tags!()
      |> Ash.load!([:links, :posts, :media_logs, :projects], domain: Weakty.Tags)
      |> Enum.filter(fn tag ->
        Enum.empty?(tag.links) &&
          Enum.empty?(tag.posts) &&
          Enum.empty?(tag.media_logs) &&
          Enum.empty?(tag.projects)
      end)

    Enum.each(orphaned, &Weakty.Tags.Tag.delete_tag/1)
    {:ok, length(orphaned)}
  end

  # Updates the entity's tags via join table to match the current tag names.
  defp sync_entity_tags(entity_type, source_id, tag_names) do
    case Weakty.Content.Entity.get_entity_by_source(entity_type, source_id) do
      {:ok, entity} when not is_nil(entity) ->
        # Get tag IDs from tag names
        tag_ids =
          tag_names
          |> Enum.map(fn name ->
            case Ash.get(Weakty.Tags.Tag, name: name) do
              {:ok, tag} -> tag.id
              _ -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        # Load current entity tags
        entity = Ash.load!(entity, [:tags], domain: Weakty.Content)

        current_tag_ids =
          case entity.tags do
            nil -> []
            tags when is_list(tags) -> Enum.map(tags, & &1.id)
            _ -> []
          end

        # Find tags to add and remove
        tags_to_add = tag_ids -- current_tag_ids
        tags_to_remove = current_tag_ids -- tag_ids

        # Add new tag associations
        Enum.each(tags_to_add, fn tag_id ->
          Weakty.Content.EntityTag.create_entity_tag(%{
            entity_id: entity.id,
            tag_id: tag_id
          })
        end)

        # Remove old tag associations
        if length(tags_to_remove) > 0 do
          Enum.each(tags_to_remove, fn tag_id ->
            case Ash.read(Weakty.Content.EntityTag,
                   filter: [entity_id: entity.id, tag_id: tag_id]
                 ) do
              {:ok, [join_record | _]} ->
                Weakty.Content.EntityTag.delete_entity_tag(join_record)

              _ ->
                :ok
            end
          end)
        end

        {:ok, entity}

      _ ->
        :ok
    end
  end
end
