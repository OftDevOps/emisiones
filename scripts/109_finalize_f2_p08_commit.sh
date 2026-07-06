#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
COMMIT_MESSAGE="feat: improve role based operational dashboard"

cd "$PROJECT_DIR"

echo "== Finalizar F2-P08: Dashboard operativo mejorado por rol =="

echo "== Estado inicial =="
git status --short

echo "== Validando diff whitespace =="
git diff --check

echo "== Ruff focal previo al commit =="
docker compose exec backend ruff check \
  apps/payment_requests/views.py \
  apps/payment_requests/tests/test_dashboard.py \
  apps/payment_requests/tests/test_accounts_payable_workbench.py

echo "== Tests focales F2-P08 previo al commit =="
docker compose exec backend python manage.py test \
  apps.payment_requests.tests.test_dashboard \
  apps.payment_requests.tests.test_accounts_payable_workbench

echo "== Agregando archivos F2-P08 =="
git add \
  backend/apps/payment_requests/views.py \
  backend/templates/payment_requests/paymentrequest_dashboard.html \
  backend/apps/payment_requests/tests/test_dashboard.py \
  backend/apps/payment_requests/tests/test_accounts_payable_workbench.py \
  docs/roadmap_fase2.md \
  docs/f2_p08_dashboard_operativo_por_rol.md \
  docs/matriz_dashboard_operativo_por_rol_fase2.md \
  scripts/106_f2_p08_role_dashboard_improvements.sh \
  scripts/107_fix_f2_p08_import_permission_denied.sh \
  scripts/108_fix_f2_p08_accounts_payable_test_matrix.sh \
  scripts/109_finalize_f2_p08_commit.sh

echo "== Estado staged =="
git status --short

echo "== Commit =="
if git diff --cached --quiet; then
  echo "ERROR: no hay cambios staged para commitear."
  exit 1
fi

git commit -m "$COMMIT_MESSAGE"

echo "== Push origin develop =="
git push origin develop

echo "== Estado final =="
git status --short
git log --oneline --max-count=5 --decorate

echo "== F2-P08 cerrado y publicado en origin/develop =="
