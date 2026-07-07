#!/usr/bin/env bash
set -euo pipefail

cd /home/dchirinos/oftalmiIA/emisiones/emisiones

echo "== Finalizar F2-P10: Exportacion operativa basica =="
echo "== Estado inicial =="
git status --short

echo "== Validando diff whitespace =="
git diff --check

echo "== Ruff focal previo al commit =="
docker compose exec backend ruff check \
  apps/payment_requests/views.py \
  apps/payment_requests/urls.py \
  apps/payment_requests/tests/test_reports.py

echo "== Tests focales F2-P10 previo al commit =="
docker compose exec backend python manage.py test \
  apps.payment_requests.tests.test_reports

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== Verificando migraciones pendientes =="
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== Agregando archivos F2-P10 =="
git add \
  backend/apps/payment_requests/tests/test_reports.py \
  backend/apps/payment_requests/urls.py \
  backend/apps/payment_requests/views.py \
  backend/templates/payment_requests/paymentrequest_report.html \
  docs/roadmap_fase2.md \
  docs/f2_p10_exportacion_operativa_basica.md \
  scripts/120_f2_p10_basic_report_export.sh \
  scripts/121_fix_f2_p10_test_reports_eof.sh \
  scripts/122_finalize_f2_p10_commit.sh

echo "== Estado staged =="
git status --short

echo "== Commit =="
git commit -m "feat: add basic operational report export"

echo "== Push origin develop =="
git push origin develop

echo "== Estado final =="
git status --short
git log --oneline --max-count=5 --decorate

echo "== F2-P10 cerrado y publicado en origin/develop =="
