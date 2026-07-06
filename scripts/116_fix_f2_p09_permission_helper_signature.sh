#!/usr/bin/env bash
set -euo pipefail

cd /home/dchirinos/oftalmiIA/emisiones/emisiones

echo "== Fix F2-P09: normalizar firma de helper de permisos =="

echo "== Estado inicial =="
git status --short

FILE="backend/apps/payment_requests/views.py"

python3 - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_requests/views.py")
text = path.read_text(encoding="utf-8")

candidates = [
    "def _require_operational_permission(user, permission: str, *, message: str) -> None:\n",
    "def _require_operational_permission(user, permission: str, *, message: str):\n",
]
replacement = "def _require_operational_permission(user, permission: str, message: str) -> None:\n"

for candidate in candidates:
    if candidate in text:
        text = text.replace(candidate, replacement, 1)
        path.write_text(text, encoding="utf-8")
        print("OK: firma actualizada para aceptar mensaje como argumento posicional.")
        break
else:
    if replacement in text:
        print("OK: firma ya estaba normalizada.")
    else:
        raise SystemExit("ERROR: no se encontro la firma esperada de _require_operational_permission.")
PY

echo "== Fragmento helper =="
grep -n "def _require_operational_permission\|raise PermissionDenied" "$FILE" | head -n 10

echo "== Validando diff whitespace =="
git diff --check

echo "== Ruff focal F2-P09 =="
docker compose exec backend ruff check \
  apps/payment_requests/views.py \
  apps/payment_requests/urls.py \
  apps/accounts/context_processors.py \
  apps/accounts/role_permissions.py \
  apps/payment_requests/tests/test_reports.py \
  apps/payment_requests/tests/test_dashboard.py \
  apps/payment_requests/tests/test_views.py

echo "== Tests focales de regresion F2-P09 =="
docker compose exec backend python manage.py test \
  apps.payment_requests.tests.test_reports \
  apps.payment_requests.tests.test_dashboard \
  apps.payment_requests.tests.test_views

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== Estado Git =="
git status --short

echo "== Fix F2-P09 helper signature OK =="
