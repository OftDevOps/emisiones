#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== 139 - Create pre-pilot PostgreSQL backup =="
echo "Project: $PROJECT_DIR"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S %z')"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

warn() {
  echo "WARN: $*" >&2
}

require_file() {
  test -f "$1" || fail "required file not found: $1"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

get_env_value() {
  local key="$1"
  grep -E "^${key}=" .env | tail -n 1 | cut -d= -f2-
}

echo
echo "== Baseline =="
git status --short || true
git log --oneline --max-count=5 --decorate || true

require_file ".env"
require_file "docker-compose.yml"
require_cmd docker

POSTGRES_DB="$(get_env_value POSTGRES_DB)"
POSTGRES_USER="$(get_env_value POSTGRES_USER)"
POSTGRES_HOST="$(get_env_value POSTGRES_HOST)"
POSTGRES_PORT="$(get_env_value POSTGRES_PORT)"

[ -n "$POSTGRES_DB" ] || fail "POSTGRES_DB missing in .env"
[ -n "$POSTGRES_USER" ] || fail "POSTGRES_USER missing in .env"
[ -n "$POSTGRES_HOST" ] || fail "POSTGRES_HOST missing in .env"
[ -n "$POSTGRES_PORT" ] || fail "POSTGRES_PORT missing in .env"

echo
echo "== PostgreSQL env summary =="
echo "POSTGRES_DB=$POSTGRES_DB"
echo "POSTGRES_USER=$POSTGRES_USER"
echo "POSTGRES_HOST=$POSTGRES_HOST"
echo "POSTGRES_PORT=$POSTGRES_PORT"

if [ "$POSTGRES_HOST" != "db" ]; then
  warn "POSTGRES_HOST is not 'db'; docker compose service backup expects service name db"
fi

echo
echo "== Docker db service =="
docker compose ps db || fail "docker compose ps db failed"

if ! docker compose ps db | grep -q "healthy"; then
  fail "db service is not healthy"
fi

mkdir -p backups
TS="$(date '+%Y%m%d_%H%M%S')"
REMOTE_DUMP="/tmp/emisiones_pre_piloto_${TS}.dump"
BACKUP_FILE="backups/emisiones_pre_piloto_${TS}.dump"
SHA_FILE="${BACKUP_FILE}.sha256"


echo
echo "== Creating PostgreSQL custom-format dump inside db container =="
docker compose exec -T db pg_dump \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  -F c \
  -f "$REMOTE_DUMP" || fail "pg_dump failed"


echo
echo "== Copying backup to host =="
docker compose cp "db:${REMOTE_DUMP}" "$BACKUP_FILE" || fail "docker compose cp backup failed"


echo
echo "== Removing temporary dump from db container =="
docker compose exec -T db rm -f "$REMOTE_DUMP" || warn "could not remove remote temporary dump"


echo
echo "== Backup file verification =="
test -s "$BACKUP_FILE" || fail "backup file is empty or missing: $BACKUP_FILE"
ls -lh "$BACKUP_FILE"
sha256sum "$BACKUP_FILE" | tee "$SHA_FILE"


echo
echo "== pg_restore list verification =="
docker compose exec -T db sh -c "pg_restore -l < /dev/stdin" < "$BACKUP_FILE" | head -n 30 || fail "pg_restore list verification failed"


echo
echo "== Backup inventory =="
ls -lh backups/emisiones_pre_piloto_*.dump backups/emisiones_pre_piloto_*.dump.sha256 2>/dev/null || true


echo
echo "== Result =="
echo "PRE_PILOT_BACKUP_CREATED"
echo "BACKUP_FILE=$BACKUP_FILE"
echo "SHA256_FILE=$SHA_FILE"
