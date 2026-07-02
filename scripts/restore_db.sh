#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Uso: $0 backups/archivo.sql.gz" >&2
  exit 1
fi

FILE="$1"
if [ ! -f "$FILE" ]; then
  echo "ERROR: no existe $FILE" >&2
  exit 1
fi

gunzip -c "$FILE" | docker compose exec -T db psql -U "${POSTGRES_USER:-emisiones_user}" "${POSTGRES_DB:-emisiones_db}"
echo "Restore aplicado desde: $FILE"
