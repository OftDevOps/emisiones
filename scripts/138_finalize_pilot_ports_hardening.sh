#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

printf '== 138 - Finalize pilot ports hardening ==\n'
printf 'Project: %s\n' "$PROJECT_DIR"
printf 'Date: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"

printf '== Git baseline ==\n'
git status --short
git branch --show-current
git log --oneline --max-count=5 --decorate
printf '\n'

printf '== Expected docker-compose.yml port bindings ==\n'
if grep -q '127\.0\.0\.1:5434:5432' docker-compose.yml; then
  echo 'OK: db port bound to 127.0.0.1:5434:5432'
else
  echo 'FAIL: db port binding not found in docker-compose.yml'
  exit 1
fi

if grep -q '127\.0\.0\.1:6381:6379' docker-compose.yml; then
  echo 'OK: redis port bound to 127.0.0.1:6381:6379'
else
  echo 'FAIL: redis port binding not found in docker-compose.yml'
  exit 1
fi
printf '\n'

printf '== Docker compose resolved port bindings ==\n'
docker compose config | awk '
  /services:/ {in_services=1}
  in_services && /host_ip:|published:|target:/ {print NR ":" $0}
' | sed -n '1,160p'

if docker compose config | grep -A4 'published: "5434"' | grep -q 'host_ip: 127.0.0.1'; then
  echo 'OK: resolved db binding includes host_ip 127.0.0.1'
else
  echo 'WARN: resolved db binding check by proximity was inconclusive; review output above'
fi

if docker compose config | grep -A4 'published: "6381"' | grep -q 'host_ip: 127.0.0.1'; then
  echo 'OK: resolved redis binding includes host_ip 127.0.0.1'
else
  echo 'WARN: resolved redis binding check by proximity was inconclusive; review output above'
fi
printf '\n'

printf '== Active container ports ==\n'
docker compose ps
printf '\n'

if docker compose ps | grep -q '0\.0\.0\.0:5434'; then
  echo 'FAIL: db is still exposed on 0.0.0.0:5434'
  exit 1
else
  echo 'OK: db is not exposed on 0.0.0.0:5434'
fi

if docker compose ps | grep -q '0\.0\.0\.0:6381'; then
  echo 'FAIL: redis is still exposed on 0.0.0.0:6381'
  exit 1
else
  echo 'OK: redis is not exposed on 0.0.0.0:6381'
fi
printf '\n'

printf '== .env.example manual-risk note ==\n'
if git ls-files --error-unmatch .env.example >/dev/null 2>&1; then
  echo 'WARN: .env.example is tracked; acceptable only if values are placeholders and no real secrets exist.'
  grep -nE 'SECRET_KEY|PASSWORD|TOKEN|WEBHOOK|CLIENT_SECRET' .env.example | sed -E 's/(=).*/=***REDACTED***/' || true
else
  echo 'OK: .env.example is not tracked'
fi
printf '\n'

printf '== Cleanup recommendation ==\n'
if ls docker-compose.yml.bak.* >/dev/null 2>&1; then
  ls -lh docker-compose.yml.bak.*
  echo 'WARN: backup file exists and should not be committed. Remove it after confirming docker-compose.yml diff.'
else
  echo 'OK: no compose backup files found'
fi
printf '\n'

printf '== Final git diff summary ==\n'
git diff -- docker-compose.yml
printf '\n'

printf '== Result ==\n'
echo 'PILOT_PORTS_HARDENING_READY_FOR_VALIDATION'
