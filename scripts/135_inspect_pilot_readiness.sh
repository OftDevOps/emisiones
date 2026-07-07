#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

printf '\n== 135 - Inspect pilot readiness ==\n'
printf 'Project: %s\n' "$PROJECT_DIR"
printf 'Date: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"

printf '\n== Git baseline ==\n'
git status --short
git branch --show-current
git log --oneline --max-count=8 --decorate

printf '\n== Expected pilot documentation ==\n'
missing=0
for f in \
  docs/checklist_predespliegue_piloto_interno.md \
  docs/variables_entorno_piloto_interno.md \
  docs/backup_restore_postgresql_piloto.md \
  docs/despliegue_piloto_interno.md \
  docs/smoke_test_piloto_interno.md \
  docs/monitoreo_basico_piloto_interno.md \
  docs/plan_rollback_piloto_interno.md \
  docs/guia_operacion_piloto_interno.md
 do
  if [ -f "$f" ]; then
    printf 'OK: %s\n' "$f"
  else
    printf 'MISSING: %s\n' "$f"
    missing=1
  fi
done

printf '\n== Environment files inventory ==\n'
find . -maxdepth 2 -type f \( -name '.env' -o -name '.env.*' -o -name 'env.example' -o -name '.env.example' \) -print | sort || true

printf '\n== Sensitive files guardrail ==\n'
if git ls-files | grep -E '(^|/)\.env($|\.)' >/tmp/emisiones_tracked_env_files.txt; then
  printf 'FAIL: tracked env-like files detected:\n'
  cat /tmp/emisiones_tracked_env_files.txt
  missing=1
else
  printf 'OK: no tracked .env files detected by git ls-files\n'
fi
rm -f /tmp/emisiones_tracked_env_files.txt

printf '\n== Docker compose availability ==\n'
if command -v docker >/dev/null 2>&1; then
  docker --version
else
  printf 'FAIL: docker command not found\n'
  missing=1
fi

if docker compose version >/dev/null 2>&1; then
  docker compose version
else
  printf 'FAIL: docker compose not available\n'
  missing=1
fi

printf '\n== Docker compose config check ==\n'
if docker compose config >/tmp/emisiones_compose_config.txt 2>/tmp/emisiones_compose_config.err; then
  printf 'OK: docker compose config valid\n'
  grep -nE 'services:|backend:|db:' /tmp/emisiones_compose_config.txt | head -n 20 || true
else
  printf 'FAIL: docker compose config invalid\n'
  cat /tmp/emisiones_compose_config.err
  missing=1
fi
rm -f /tmp/emisiones_compose_config.txt /tmp/emisiones_compose_config.err

printf '\n== Docker compose services status ==\n'
docker compose ps || true

printf '\n== Disk capacity ==\n'
df -h .

printf '\n== Backup directory status ==\n'
if [ -d backups ]; then
  ls -lah backups | tail -n 20
else
  printf 'INFO: backups directory does not exist yet; expected before real pilot backup step\n'
fi

printf '\n== Django static project indicators ==\n'
for f in manage.py backend/manage.py pyproject.toml docker-compose.yml compose.yml docker-compose.yaml; do
  [ -e "$f" ] && printf 'FOUND: %s\n' "$f"
done

printf '\n== Readiness result ==\n'
if [ "$missing" -eq 0 ]; then
  printf 'PILOT_READINESS_INSPECTION_OK\n'
else
  printf 'PILOT_READINESS_INSPECTION_HAS_FINDINGS\n'
  exit 1
fi
