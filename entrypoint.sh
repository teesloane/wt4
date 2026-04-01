#!/bin/sh
set -eu

# Docker creates a directory instead of a file when the host path doesn't exist at mount time.
# Detect and remove it so SQLite can create a proper database file.
if [ -d /data/weakty.db ]; then
    rmdir /data/weakty.db
fi

# Run Ecto migrations
/app/bin/weakty eval "Weakty.Release.migrate()"

# Start the app
exec /app/bin/weakty start
