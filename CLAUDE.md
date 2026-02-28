# Weakty — Claude Notes

## Ash Migration Workflow

`mix ash_sqlite.generate_migrations` runs automatically when resource files change. It diffs the resource against `priv/resource_snapshots/` and emits a migration.

**Let Ash own DDL. Only write manual migrations for data movement (INSERT/UPDATE/DELETE) and DROP TABLE.**

Correct workflow when adding columns + migrating data:
1. Update the Ash resource
2. `mix ash_sqlite.generate_migrations` → Ash emits the ALTER TABLE migration
3. Edit that generated migration to also include data migration SQL

If a manual migration and Ash-generated one both add the same column: make the Ash-generated one a no-op (empty `up`/`down`).

## Tag Deletion: Join Table Cleanup

The `destroy` action in `lib/weakty/tags/tag.ex` manually deletes all join table rows referencing a tag before the record is destroyed (SQLite FK constraints require this).

**When a new `*_tags` join table is added**, you must add a corresponding cleanup line to the `before_action` block:

```elixir
Weakty.Repo.delete_all(from ft in "foo_tags", where: ft.tag_id == ^tag.id)
```

Currently cleaned up: `link_tags`, `post_tags`, `media_log_tags`, `project_tags`, `entity_tags`.

Note: TILs and Quotes are now `post_type: :til` and `post_type: :quote` in the `posts` table — their tags are in `post_tags` (already covered above). The old `til_tags` and `quote_tags` tables no longer exist.

Forgetting this causes intermittent "referenced something that does not exist" errors when deleting tags that have associations to the new content type.

## Entity Deletion: entity_tags Cleanup

When deleting an entity (via `Weakty.Changes.DestroyEntity`), the `entity_tags` join table must be cleared first. This is already handled in `lib/weakty/changes/destroy_entity.ex`:

```elixir
Weakty.Repo.delete_all(from et in "entity_tags", where: et.entity_id == ^entity.id)
```

The entity `destroy` action uses the Ash default (no built-in join cleanup), so this manual step is required. Forgetting it causes "referenced something that does not exist" errors when deleting any content that has entity tags.
