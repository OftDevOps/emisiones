#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== Fix F2-PILOT-BR02: restaurar contrato de navegacion Listado =="
echo "== Ruta =="
pwd

echo "== Estado inicial =="
git status --short

python3 - <<'PY'
from pathlib import Path

path = Path("backend/templates/base.html")
text = path.read_text(encoding="utf-8")
original = text

replacements = [
    ('>Solicitudes</a>', '>Listado</a>'),
    ('> Solicitudes </a>', '>Listado</a>'),
    ('>Solicitudes </a>', '>Listado</a>'),
    ('> Solicitudes</a>', '>Listado</a>'),
]

for old, new in replacements:
    text = text.replace(old, new)

if text == original:
    print("WARN: no se encontro etiqueta exacta Solicitudes para reemplazar en base.html")
else:
    path.write_text(text, encoding="utf-8")
    print("OK: etiqueta de navegacion restaurada a Listado en base.html")
PY

echo "== Confirmando etiqueta Listado en navegacion =="
grep -n "Listado\|Solicitudes\|payment-requests" backend/templates/base.html || true

echo "== Validacion diff whitespace =="
git diff --check

echo "== Ruff focal =="
docker compose exec backend ruff check apps/accounts/tests/test_role_navigation_integrated_matrix.py >/dev/null || true
docker compose exec backend ruff check .

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== Test focal contrato navegacion integrado =="
docker compose exec backend python manage.py test apps.accounts.tests.test_role_navigation_integrated_matrix

echo "== Tests focales branding/navegacion/dashboard =="
docker compose exec backend python manage.py test \
  apps.accounts.tests.test_role_navigation_context \
  apps.accounts.tests.test_role_navigation_template \
  apps.accounts.tests.test_authentication_flow \
  apps.accounts.tests.test_role_navigation_integrated_matrix \
  apps.payment_requests.tests.test_dashboard

echo "== HTTP static/login smoke =="
curl -I --max-time 5 http://127.0.0.1:8001/static/css/oftalmi_branding.css || true
curl -I --max-time 5 http://127.0.0.1:8001/static/img/oftalmi-icon.png || true
curl -I --max-time 5 http://127.0.0.1:8001/static/img/favicon.ico || true
curl -I --max-time 5 http://127.0.0.1:8001/login/ || true

echo "== Estado final =="
git status --short

echo "== FIN Fix F2-PILOT-BR02 navegacion Listado =="
