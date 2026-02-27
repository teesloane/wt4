# Weakty — Claude Notes

## Tag Deletion: Join Table Cleanup

The `destroy` action in `lib/weakty/tags/tag.ex` manually deletes all join table rows referencing a tag before the record is destroyed (SQLite FK constraints require this).

**When a new `*_tags` join table is added**, you must add a corresponding cleanup line to the `before_action` block:

```elixir
Weakty.Repo.delete_all(from ft in "foo_tags", where: ft.tag_id == ^tag.id)
```

Currently cleaned up: `link_tags`, `post_tags`, `media_log_tags`, `project_tags`, `entity_tags`, `til_tags`, `quote_tags`.

Forgetting this causes intermittent "referenced something that does not exist" errors when deleting tags that have associations to the new content type.
