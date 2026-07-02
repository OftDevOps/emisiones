#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FILE="$BACKUP_DIR/emisiones_db_$TIMESTAMP.dump"

mkdir -p "$BACKUP_DIR"

docker exec emisiones_db pg_dump -U emisiones_user -d emisiones_db -F c -f "/tmp/emisiones_db_$TIMESTAMP.dump"
docker cp "emisiones_db:/tmp/emisiones_db_$TIMESTAMP.dump" "$FILE"

echo "Backup created: $FILE"
