#!/usr/bin/env bash
set -u

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR" || exit 1

FAILURES=0
WARNINGS=0

section() {
  printf '\n== %s ==\n' "$1"
}

ok() {
  printf 'OK: %s\n' "$1"
}

warn() {
  printf 'WARN: %s\n' "$1"
  WARNINGS=$((WARNINGS + 1))
}

fail() {
  printf 'FAIL: %s\n' "$1"
  FAILURES=$((FAILURES + 1))
}

section "140 v2 - Pilot technical smoke test"
echo "Project: $PROJECT_DIR"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S %z')"

section "Git baseline"
git status --short || true
git log --oneline --max-count=5 --decorate || true

section "Docker services status"
docker compose ps || fail "docker compose ps failed"

section "Container health checks"
for svc in backend db redis; do
  cid="$(docker compose ps -q "$svc" 2>/dev/null || true)"
  if [ -z "$cid" ]; then
    fail "$svc container not found"
    continue
  fi
  health="$(docker inspect "$cid" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || true)"
  echo "$svc health/status: $health"
  case "$health" in
    healthy|running) ok "$svc is $health" ;;
    *) fail "$svc is not healthy/running" ;;
  esac
done

section "Django system check"
if docker compose exec -T backend python manage.py check; then
  ok "manage.py check passed"
else
  fail "manage.py check failed"
fi

section "Django migrations dry-run"
if docker compose exec -T backend python manage.py makemigrations --check --dry-run; then
  ok "no model changes detected"
else
  fail "makemigrations dry-run failed or model changes detected"
fi

section "Django migrate plan"
if docker compose exec -T backend python manage.py migrate --plan; then
  ok "migrate --plan executed"
else
  fail "migrate --plan failed"
fi

section "Internal HTTP smoke from backend container"
if docker compose exec -T backend sh -lc 'curl -fsS --max-time 5 http://127.0.0.1:8000/health/ >/dev/null'; then
  ok "internal /health/ returned success"
else
  fail "internal /health/ failed"
fi

root_status="$(docker compose exec -T backend sh -lc "curl -sS -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:8000/" 2>/dev/null || true)"
echo "internal root status: ${root_status:-NO_RESPONSE}"
case "$root_status" in
  200|301|302|403) ok "internal root returned acceptable HTTP status $root_status" ;;
  *) fail "internal root returned unexpected status ${root_status:-NO_RESPONSE}" ;;
esac

section "Host HTTP smoke through published backend port"
port_line="$(docker compose port backend 8000 2>/dev/null || true)"
echo "backend published port: ${port_line:-NOT_FOUND}"
if [ "$port_line" = "127.0.0.1:8001" ]; then
  ok "backend published on expected localhost port"
else
  warn "backend published port differs from expected 127.0.0.1:8001"
fi

host_health_status="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 5 http://127.0.0.1:8001/health/ 2>/dev/null || true)"
echo "host /health/ status: ${host_health_status:-NO_RESPONSE}"
case "$host_health_status" in
  200) ok "host /health/ returned 200" ;;
  "") warn "host /health/ did not respond; likely Docker/firewalld/VPN host-to-published-port issue" ;;
  *) warn "host /health/ returned non-200 status $host_health_status" ;;
esac

section "Published ports exposure guard"
ports="$(docker compose ps 2>/dev/null || true)"
echo "$ports"
if echo "$ports" | grep -qE 'emisiones_db.*0\.0\.0\.0:5434'; then
  fail "db is exposed on 0.0.0.0:5434"
else
  ok "db is not exposed on 0.0.0.0:5434"
fi
if echo "$ports" | grep -qE 'emisiones_redis.*0\.0\.0\.0:6381'; then
  fail "redis is exposed on 0.0.0.0:6381"
else
  ok "redis is not exposed on 0.0.0.0:6381"
fi

section "Pre-pilot backup inventory"
latest_backup="$(find backups -maxdepth 1 -type f -name 'emisiones_pre_piloto_*.dump' 2>/dev/null | sort | tail -n 1 || true)"
if [ -n "$latest_backup" ]; then
  ls -lh "$latest_backup"
  if [ -f "$latest_backup.sha256" ]; then
    ok "sha256 file exists for latest backup"
    sha256sum -c "$latest_backup.sha256" || fail "sha256 verification failed"
  else
    fail "sha256 file missing for latest backup"
  fi
  if docker compose exec -T db pg_restore -l "/tmp/nonexistent" >/dev/null 2>&1; then
    warn "unexpected pg_restore behavior"
  fi
  if docker compose cp "$latest_backup" db:/tmp/smoke_restore_list.dump >/dev/null 2>&1 && docker compose exec -T db pg_restore -l /tmp/smoke_restore_list.dump >/dev/null 2>&1; then
    ok "latest backup can be listed by pg_restore"
    docker compose exec -T db rm -f /tmp/smoke_restore_list.dump >/dev/null 2>&1 || true
  else
    fail "latest backup cannot be listed by pg_restore"
  fi
else
  fail "no pre-pilot backup found"
fi

section "Result"
if [ "$FAILURES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  echo "PILOT_TECHNICAL_SMOKE_READY"
elif [ "$FAILURES" -eq 0 ]; then
  echo "PILOT_TECHNICAL_SMOKE_READY_WITH_WARNINGS"
  echo "Warnings: $WARNINGS"
else
  echo "PILOT_TECHNICAL_SMOKE_BLOCKED"
  echo "Failures: $FAILURES"
  echo "Warnings: $WARNINGS"
  exit 1
fi
