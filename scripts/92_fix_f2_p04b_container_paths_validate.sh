#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_ROOT"

echo "== Fix F2-P04B: validar navegacion con rutas correctas dentro del contenedor =="

BASE_TEMPLATE="backend/templates/base.html"
TEST_FILE_HOST="backend/apps/accounts/tests/test_role_navigation_template.py"
TEST_FILE_CONTAINER="apps/accounts/tests/test_role_navigation_template.py"

if [ ! -f "$BASE_TEMPLATE" ]; then
  echo "ERROR: no existe $BASE_TEMPLATE"
  exit 1
fi

if [ ! -f "$TEST_FILE_HOST" ]; then
  echo "ERROR: no existe $TEST_FILE_HOST"
  exit 1
fi

echo "== Validando que base.html use role_nav =="
grep -q "role_nav.can_view_payment_dashboard" "$BASE_TEMPLATE"
grep -q "role_nav.can_view_accounts_payable" "$BASE_TEMPLATE"
grep -q "role_nav.can_view_audit_workbench" "$BASE_TEMPLATE"

echo "== Validando que el test no pase username duplicado =="
if grep -q "username=email" "$TEST_FILE_HOST"; then
  echo "ERROR: el test aun contiene username=email"
  exit 1
fi

echo "== Ruff focal con ruta interna del contenedor =="
docker compose exec backend ruff check "$TEST_FILE_CONTAINER"

echo "== Test focal F2-P04B =="
docker compose exec backend python manage.py test apps.accounts.tests.test_role_navigation_template

echo "== Inspeccion rapida de navegacion aplicada =="
grep -n "oftalmi-nav\|role_nav.can_view\|Cuentas por pagar\|Auditoria" "$BASE_TEMPLATE" || true

echo "== Estado posterior =="
git status --short
