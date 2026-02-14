# Seed script — run via:
#   mix run priv/repo/seeds.exs
#
# Or to fully reset and reseed from scratch:
#   mix ecto.reset   (drops, recreates, migrates, then runs this file)

import Ecto.Query

project_root = Path.expand("../..", __DIR__)

# Load import modules (entry points are guarded so they don't execute here)
Code.require_file(Path.join(project_root, "scripts/import_obsidian_books.exs"))
Code.require_file(Path.join(project_root, "scripts/import_ghost_posts.exs"))

user_email = "weakty@fastmail.com"
user_password = "password"

# ---------------------------------------------------------------------------
# 1. Create user
# ---------------------------------------------------------------------------

IO.puts(String.duplicate("=", 60))
IO.puts("Step 1: Creating user")
IO.puts(String.duplicate("=", 60))

user =
  case Weakty.Accounts.User
       |> Ash.Query.for_read(:get_by_email, %{email: user_email})
       |> Ash.read_one() do
    {:ok, existing} when not is_nil(existing) ->
      IO.puts("User already exists: #{existing.email}")
      existing

    _ ->
      case Weakty.Accounts.User
           |> Ash.Changeset.for_create(:register_with_password, %{
             email: user_email,
             password: user_password,
             password_confirmation: user_password
           })
           |> Ash.create(authorize?: false) do
        {:ok, new_user} ->
          IO.puts("Created user: #{new_user.email}")
          new_user

        {:error, error} ->
          IO.puts("Error creating user: #{inspect(error)}")
          System.halt(1)
      end
  end

# Mark the user as confirmed so they can sign in without clicking a link
Weakty.Repo.update_all(
  from(u in "users", where: u.id == ^user.id),
  set: [confirmed_at: DateTime.utc_now()]
)

IO.puts("User confirmed: #{user.email}")

# ---------------------------------------------------------------------------
# 2. Import Obsidian books
# ---------------------------------------------------------------------------

IO.puts("")
IO.puts(String.duplicate("=", 60))
IO.puts("Step 2: Importing Obsidian books")
IO.puts(String.duplicate("=", 60))

books_dir = Path.join(project_root, "seed/books")
ObsidianBookImporter.run(books_dir, user_email)

# ---------------------------------------------------------------------------
# 3. Import Ghost posts
# ---------------------------------------------------------------------------

IO.puts("")
IO.puts(String.duplicate("=", 60))
IO.puts("Step 3: Importing Ghost posts")
IO.puts(String.duplicate("=", 60))

ghost_json = Path.join(project_root, "seed/weakty-ghost.json")
GhostImporter.run(ghost_json, user_email)

IO.puts("")
IO.puts(String.duplicate("=", 60))
IO.puts("Seed complete!")
IO.puts(String.duplicate("=", 60))
