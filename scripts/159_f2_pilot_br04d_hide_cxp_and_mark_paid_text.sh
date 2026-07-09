#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== F2-PILOT-BR04D: ocultar Cuentas por Pagar visible y ajustar accion final =="
echo "== Ruta =="
pwd

echo "== Estado inicial =="
git status --short

python3 - <<'PY'
from pathlib import Path

changes = []


def replace_in_file(file_name: str, replacements: dict[str, str]) -> None:
    path = Path(file_name)
    if not path.exists():
        print(f"WARN: no existe {file_name}")
        return
    text = path.read_text(encoding="utf-8")
    original = text
    for old, new in replacements.items():
        if old in text:
            text = text.replace(old, new)
        else:
            print(f"WARN: patron no encontrado en {file_name}: {old[:90]!r}")
    if text != original:
        path.write_text(text, encoding="utf-8")
        changes.append(file_name)
        print(f"OK: actualizado {file_name}")
    else:
        print(f"INFO: sin cambios {file_name}")

replace_in_file(
    "backend/templates/registration/login.html",
    {
        "Emisiones, aprobaciones, Cuentas por Pagar y trazabilidad operativa en una sola plataforma.":
        "Emisiones, aprobaciones y trazabilidad operativa en una sola plataforma.",
    },
)

replace_in_file(
    "backend/templates/base.html",
    {
        "    {% if role_nav.can_view_accounts_payable %}\n        <a class=\"nav-link\" href=\"{% url 'payment_requests:accounts_payable' %}\">Cuentas por pagar</a>\n    {% endif %}\n": "",
    },
)

replace_in_file(
    "backend/templates/payment_requests/paymentrequest_dashboard.html",
    {
        "  {% if role_nav.can_view_accounts_payable %}\n    <a class=\"quick-action\" href=\"{% url 'payment_requests:accounts_payable' %}\">Cuentas por Pagar</a>\n  {% endif %}\n": "",
        " and not role_nav.can_view_accounts_payable": "",
        "Emisiones aprobadas pendientes de ejecución": "Emisiones aprobadas pendientes de confirmación de pago",
        "Total pendiente de ejecución:": "Total pendiente por confirmar:",
        "No hay emisiones aprobadas pendientes de ejecución.": "No hay emisiones aprobadas pendientes de confirmación de pago.",
    },
)

replace_in_file(
    "backend/templates/payment_requests/accounts_payable_pending.html",
    {
        "<h1>Cuentas por Pagar</h1>": "<h1>Confirmación de pago de emisiones</h1>",
        "Emisiones aprobadas pendientes por ejecutar": "Emisiones aprobadas pendientes de confirmación de pago",
        "Registrar pago en ERP": "Marcar emisión como pagada",
        "No hay emisiones aprobadas pendientes por ejecutar.": "No hay emisiones aprobadas pendientes de confirmación de pago.",
    },
)

replace_in_file(
    "backend/templates/payment_requests/paymentrequest_detail.html",
    {
        "Registrar pago en ERP": "Marcar emisión como pagada",
    },
)

replace_in_file(
    "backend/templates/payment_execution/paymentexecution_form.html",
    {
        "<h1>Registrar ejecución de pago en ERP</h1>": "<h1>Marcar emisión como pagada</h1>",
        "Registrar pago en ERP": "Marcar emisión como pagada",
        "<p><a href=\"{% url 'payment_requests:accounts_payable' %}\">Volver a Cuentas por Pagar</a></p>":
        "<p><a href=\"{% url 'payment_requests:dashboard' %}\">Volver al dashboard operativo</a></p>",
    },
)

# Tests de navegacion: el acceso visible de Cuentas por Pagar se retira del header/menu.
replace_in_file(
    "backend/apps/accounts/tests/test_role_navigation_template.py",
    {
        "    def test_cuentas_por_pagar_sees_accounts_payable_link(self):":
        "    def test_cuentas_por_pagar_does_not_see_accounts_payable_link(self):",
        "        self.assertIn(\"Cuentas por pagar\", content)":
        "        self.assertNotIn(\"Cuentas por pagar\", content)",
    },
)

replace_in_file(
    "backend/apps/accounts/tests/test_role_navigation_integrated_matrix.py",
    {
        "    (\"Cuentas por pagar\", \"payment_requests:accounts_payable\", PERM_VIEW_ACCOUNTS_PAYABLE),\n": "",
    },
)

replace_in_file(
    "backend/apps/payment_requests/tests/test_dashboard.py",
    {
        "        self.assertContains(response, \"Cuentas por Pagar\")":
        "        self.assertNotContains(response, \"Cuentas por Pagar\")",
        "        self.assertContains(response, reverse(\"payment_requests:accounts_payable\"))":
        "        self.assertNotContains(response, reverse(\"payment_requests:accounts_payable\"))",
        "Emisiones aprobadas pendientes de ejecución": "Emisiones aprobadas pendientes de confirmación de pago",
        "Total pendiente de ejecución:": "Total pendiente por confirmar:",
    },
)

print("\nArchivos modificados:")
for file_name in changes:
    print(f"- {file_name}")
PY

echo "== Validacion diff whitespace =="
git diff --check

echo "== Busqueda de Cuentas por Pagar visible pendiente en templates principales =="
grep -RniI \
  "Cuentas por Pagar\|Cuentas por pagar\|Registrar pago en ERP\|Volver a Cuentas por Pagar" \
  backend/templates/registration/login.html \
  backend/templates/base.html \
  backend/templates/payment_requests \
  backend/templates/payment_execution \
  || true

echo "== Ruff =="
docker compose exec backend ruff check .

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== Tests focales BR04D =="
docker compose exec backend python manage.py test \
  apps.accounts.tests.test_role_navigation_template \
  apps.accounts.tests.test_role_navigation_integrated_matrix \
  apps.accounts.tests.test_role_navigation_context \
  apps.payment_requests.tests.test_dashboard \
  apps.payment_requests.tests.test_accounts_payable_workbench \
  apps.payment_execution.tests.test_views \
  apps.payment_execution.tests.test_traceability

echo "== collectstatic =="
docker compose exec backend python manage.py collectstatic --noinput

echo "== Reinicio backend =="
docker compose up -d backend

echo "== HTTP smoke =="
for url in \
  http://127.0.0.1:8001/login/ \
  http://127.0.0.1:8001/payment-requests/dashboard/ \
  http://127.0.0.1:8001/static/css/oftalmi_branding.css; do
  code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 5 "$url" || true)
  echo "$url -> HTTP $code"
done

echo "== Estado final =="
git status --short

echo "== FIN F2-PILOT-BR04D =="
