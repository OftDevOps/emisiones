#!/usr/bin/env bash
set -euo pipefail

cd /home/dchirinos/oftalmiIA/emisiones/emisiones

echo "== Validacion completa F2-P09: Reporte basico por estado, empresa y fecha =="

echo "== Desconectando NordVPN para evitar bloqueo de Docker local =="
nordvpn disconnect || true
sleep 3

echo "== Estado Git =="
git status
git log --oneline --max-count=5 --decorate

echo "== Validando diff whitespace =="
git diff --check

echo "== Ruff completo =="
docker compose exec backend ruff check .

echo "== Django system check =="
docker compose exec backend python manage.py check

echo "== Migraciones pendientes =="
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== Aplicando migraciones existentes =="
docker compose exec backend python manage.py migrate

echo "== Test suite Fase 2 apps principales =="
docker compose exec backend python manage.py test \
  apps.organization \
  apps.accounts \
  apps.beneficiaries \
  apps.payment_requests \
  apps.payment_documents \
  apps.payment_approvals \
  apps.payment_execution

echo "== Reconectando NordVPN =="
nordvpn connect United_States || true
nordvpn status || true

echo "== Validacion completa F2-P09 OK =="
