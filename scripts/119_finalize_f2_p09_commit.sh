#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== Finalizar F2-P09: Reporte basico por estado, empresa y fecha =="

echo "== Estado inicial =="
git status --short

echo "== Validando diff whitespace =="
git diff --check

echo "== Ruff focal previo al commit =="
docker compose exec backend ruff check \
  apps/accounts/context_processors.py \
  apps/accounts/role_permissions.py \
  apps/payment_requests/urls.py \
  apps/payment_requests/views.py \
  apps/payment_requests/tests/test_reports.py \
  apps/payment_requests/tests/test_dashboard.py \
  apps/payment_requests/tests/test_views.py

echo "== Tests focales F2-P09 previo al commit =="
docker compose exec backend python manage.py test \
  apps.payment_requests.tests.test_reports \
  apps.payment_requests.tests.test_dashboard \
  apps.payment_requests.tests.test_views

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== Agregando archivos F2-P09 =="
git add \
  backend/apps/accounts/context_processors.py \
  backend/apps/accounts/role_permissions.py \
  backend/apps/payment_requests/urls.py \
  backend/apps/payment_requests/views.py \
  backend/apps/payment_requests/tests/test_reports.py \
  backend/templates/payment_requests/paymentrequest_dashboard.html \
  backend/templates/payment_requests/paymentrequest_report.html \
  docs/roadmap_fase2.md \
  docs/f2_p09_reporte_basico_estado_empresa_fecha.md \
  scripts/112_inspect_f2_p09_report_scope.sh \
  scripts/113_f2_p09_basic_payment_request_report.sh \
  scripts/114_fix_f2_p09_dashboard_whitespace.sh \
  scripts/115_validate_f2_p09_full.sh \
  scripts/116_fix_f2_p09_permission_helper_signature.sh \
  scripts/117_fix_f2_p09_payment_list_permission_call.sh \
  scripts/118_fix_f2_p09_clean_payment_list_dispatch.sh \
  scripts/119_finalize_f2_p09_commit.sh

echo "== Estado staged =="
git status --short

if git diff --cached --quiet; then
  echo "ERROR: no hay cambios staged para commit."
  exit 1
fi

echo "== Commit =="
git commit -m "feat: add basic payment request reporting"

echo "== Push origin develop =="
git push origin develop

echo "== Estado final =="
git status --short
git log --oneline --max-count=5 --decorate

echo "== F2-P09 cerrado y publicado en origin/develop =="
