#!/usr/bin/env bash
set -euo pipefail

echo "== Fix F2-PILOT-BR02: restaurar contrato de navegacion Solicitudes + Listado =="

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== Ruta =="
pwd

echo "== Estado inicial =="
git status --short

BASE_TEMPLATE="backend/templates/base.html"

python - <<'PY'
from pathlib import Path

path = Path("backend/templates/base.html")
text = path.read_text(encoding="utf-8")
original = text

# Contrato historico esperado por tests integrados:
# - payment_requests:dashboard visible como "Solicitudes"
# - payment_requests:list visible como "Listado"
text = text.replace(
    '<a class="nav-link" href="{% url \'payment_requests:dashboard\' %}">Dashboard</a>',
    '<a class="nav-link" href="{% url \'payment_requests:dashboard\' %}">Solicitudes</a>',
)
text = text.replace(
    '<a class="nav-link" href="{% url \'payment_requests:list\' %}">Solicitudes</a>',
    '<a class="nav-link" href="{% url \'payment_requests:list\' %}">Listado</a>',
)

if text != original:
    path.write_text(text, encoding="utf-8")
    print("OK: etiquetas de navegacion restauradas: Solicitudes + Listado")
else:
    print("OK: etiquetas de navegacion ya estaban en contrato esperado o no hubo cambios aplicables")
PY

echo "== Confirmando etiquetas en navegacion =="
grep -n "payment_requests:dashboard\|payment_requests:list" "$BASE_TEMPLATE"
grep -n ">Solicitudes<\|>Listado<" "$BASE_TEMPLATE"

echo "== Validacion diff whitespace =="
git diff --check

echo "== Ruff focal =="
docker compose exec backend ruff check apps/accounts/tests/test_role_navigation_integrated_matrix.py

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== Test focal contrato navegacion integrado =="
docker compose exec backend python manage.py test apps.accounts.tests.test_role_navigation_integrated_matrix

echo "== Tests focales navegacion/template/dashboard =="
docker compose exec backend python manage.py test \
  apps.accounts.tests.test_role_navigation_context \
  apps.accounts.tests.test_role_navigation_template \
  apps.payment_requests.tests.test_dashboard

echo "== HTTP static/login debe seguir OK =="
curl -I --max-time 5 http://127.0.0.1:8001/static/css/oftalmi_branding.css || true
curl -I --max-time 5 http://127.0.0.1:8001/static/img/oftalmi-icon.png || true
curl -I --max-time 5 http://127.0.0.1:8001/static/img/favicon.ico || true
curl -I --max-time 5 http://127.0.0.1:8001/login/ || true

echo "== Estado final =="
git status --short

echo "== FIN Fix F2-PILOT-BR02 navegacion Solicitudes + Listado =="
