#!/usr/bin/env bash
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: ./scripts/restore_db.sh backups/file.dump"
  exit 1
fi

FILE="$1"

docker cp "$FILE" emisiones_db:/tmp/restore.dump
docker exec emisiones_db pg_restore -U emisiones_user -d emisiones_db --clean --if-exists /tmp/restore.dump

echo "Restore completed from: $FILE"
