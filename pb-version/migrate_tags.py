#!/usr/bin/env python3
"""
Migrate multi-tag relationships from old Elixir SQLite DB to PocketBase DB.

Old DB: many-to-many via join tables (post_tags, link_tags, etc.)
New DB: PocketBase relation field (JSON array of IDs)
"""

import sqlite3
import json
import sys

OLD_DB = "/Users/ty/Sync/PARA/projects/development/weakty4/weakty_dev.db"
NEW_DB = "/Users/ty/Sync/PARA/projects/development/weakty4/pb-version/backend/pb_data/data.db"

old = sqlite3.connect(OLD_DB)
new = sqlite3.connect(NEW_DB)
old.row_factory = sqlite3.Row
new.row_factory = sqlite3.Row

# Build slug → PocketBase ID map for tags
pb_tag_ids = {row["slug"]: row["id"] for row in new.execute("SELECT id, slug FROM tags")}
print(f"Loaded {len(pb_tag_ids)} tags from PocketBase")

# Collections to migrate: (collection_name, join_table, fk_column, old_table)
collections = [
    ("posts",      "post_tags",      "post_id",      "posts"),
    ("links",      "link_tags",      "link_id",       "links"),
    ("media_logs", "media_log_tags", "media_log_id",  "media_logs"),
    ("projects",   "project_tags",   "project_id",    "projects"),
]

total_updated = 0
total_skipped = 0
total_missing = 0

for pb_collection, join_table, fk_col, old_table in collections:
    # Fetch all tag relationships from old DB grouped by record slug
    rows = old.execute(f"""
        SELECT r.slug, GROUP_CONCAT(t.slug, ',') as tag_slugs
        FROM {old_table} r
        JOIN {join_table} jt ON jt.{fk_col} = r.id
        JOIN tags t ON t.id = jt.tag_id
        GROUP BY r.slug
    """).fetchall()

    updated = skipped = missing = 0

    for row in rows:
        slug = row["slug"]
        tag_slugs = row["tag_slugs"].split(",") if row["tag_slugs"] else []

        # Map tag slugs to PocketBase IDs
        pb_ids = []
        for ts in tag_slugs:
            if ts in pb_tag_ids:
                pb_ids.append(pb_tag_ids[ts])
            else:
                print(f"  WARNING: tag '{ts}' not found in PocketBase (for {pb_collection}/{slug})")

        if not pb_ids:
            skipped += 1
            continue

        # Find the record in PocketBase by slug
        pb_rec = new.execute(f"SELECT id, tags FROM {pb_collection} WHERE slug = ?", (slug,)).fetchone()
        if pb_rec is None:
            print(f"  MISSING: {pb_collection}/{slug} not found in PocketBase")
            missing += 1
            continue

        # Store as JSON array (PocketBase multi-relation format)
        new_tags = json.dumps(pb_ids)

        new.execute(f"UPDATE {pb_collection} SET tags = ? WHERE id = ?", (new_tags, pb_rec["id"]))
        updated += 1

    print(f"{pb_collection}: {updated} updated, {skipped} skipped (no tags), {missing} missing")
    total_updated += updated
    total_skipped += skipped
    total_missing += missing

new.commit()
old.close()
new.close()

print(f"\nDone. Total: {total_updated} updated, {total_skipped} skipped, {total_missing} missing")
