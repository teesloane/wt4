require Ash.Query

projects = Ash.read!(Weakty.Projects.Project, authorize?: false)
IO.puts("Found #{length(projects)} projects")

Enum.each(projects, fn project ->
  # Trigger a no-op update so SyncEntity runs and upserts the entity + syncs tags
  case project
       |> Ash.Changeset.for_update(:update, %{})
       |> Ash.update(authorize?: false) do
    {:ok, _} -> IO.puts("  synced: #{project.title}")
    {:error, err} -> IO.puts("  ERROR #{project.title}: #{inspect(err)}")
  end
end)

IO.puts("Done")
