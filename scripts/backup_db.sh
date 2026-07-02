#!/usr/bin/env bash
set -euo pipefail

mkdir -p backups
STAMP=$(date +%Y%m%d_%H%M%S)
OUT="backups/emisiones_db_${STAMP}.sql.gz"

docker compose exec -T db pg_dump -U "${POSTGRES_USER:-emisiones_user}" "${POSTGRES_DB:-emisiones_db}" | gzip > "$OUT"
echo "Backup creado: $OUT"
