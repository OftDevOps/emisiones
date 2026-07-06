#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_ROOT"

echo "== Fix F2-P04B: corregir reverse del dashboard en test de navegacion =="

TEST_FILE="backend/apps/accounts/tests/test_role_navigation_template.py"

if [ ! -f "$TEST_FILE" ]; then
  echo "ERROR: no existe $TEST_FILE"
  exit 1
fi

echo "== Aplicando reverse correcto: payment_requests:dashboard =="
python3 - <<'PY'
from pathlib import Path

path = Path("backend/apps/accounts/tests/test_role_navigation_template.py")
text = path.read_text(encoding="utf-8")

text = text.replace('reverse("dashboard")', 'reverse("payment_requests:dashboard")')
text = text.replace("reverse('dashboard')", "reverse('payment_requests:dashboard')")

if "reverse(\"dashboard\")" in text or "reverse('dashboard')" in text:
    raise SystemExit("ERROR: aun queda reverse('dashboard') sin corregir")

path.write_text(text, encoding="utf-8")
PY

echo "== Verificando cambios =="
grep -n "reverse" "$TEST_FILE"

echo "== Ruff focal =="
docker compose exec backend ruff check apps/accounts/tests/test_role_navigation_template.py

echo "== Test focal F2-P04B =="
docker compose exec backend python manage.py test apps.accounts.tests.test_role_navigation_template

echo "== Estado posterior =="
git status --short
