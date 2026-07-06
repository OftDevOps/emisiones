#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_ROOT"

echo "== Fix F2-P05: remover import no usado en prueba integrada =="

TEST_FILE="backend/apps/accounts/tests/test_role_navigation_integrated_matrix.py"

if [ ! -f "$TEST_FILE" ]; then
  echo "ERROR: no existe $TEST_FILE. Ejecutar primero scripts/95_f2_p05_integrated_navigation_role_matrix.sh"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

path = Path("backend/apps/accounts/tests/test_role_navigation_integrated_matrix.py")
text = path.read_text(encoding="utf-8")
text = text.replace("from django.core.exceptions import PermissionDenied\n", "")
path.write_text(text, encoding="utf-8")
PY

echo "== Ruff focal =="
docker compose exec backend ruff check apps/accounts/tests/test_role_navigation_integrated_matrix.py

echo "== Tests focales F2-P04B/F2-P05 =="
docker compose exec backend python manage.py test \
  apps.accounts.tests.test_role_navigation_template \
  apps.accounts.tests.test_role_navigation_integrated_matrix

echo "== Validacion global rapida =="
docker compose exec backend ruff check .
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== Estado posterior =="
git status --short
