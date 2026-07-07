#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== F2-PILOT-BR04: terminologia visible Emisiones =="
echo "== Ruta =="
pwd

echo "== Estado inicial =="
git status --short

python3 - <<'PY'
from pathlib import Path

replacements = {
    # Login / base
    "backend/templates/registration/login.html": {
        "Gestión controlada de pagos": "Gestión controlada de emisiones",
        "Solicitudes, aprobaciones, Cuentas por Pagar y trazabilidad operativa en una sola plataforma.": "Emisiones, aprobaciones, Cuentas por Pagar y trazabilidad operativa en una sola plataforma.",
    },
    "backend/templates/base.html": {
        ">Solicitudes<": ">Emisiones<",
        ">Nueva solicitud<": ">Nueva emisión<",
    },

    # Payment request UI visible as Emisiones
    "backend/templates/payment_requests/paymentrequest_form.html": {
        "Nueva solicitud de pago": "Nueva emisión",
        "<h1>Nueva solicitud de pago</h1>": "<h1>Nueva emisión</h1>",
        "Crear solicitud": "Crear emisión",
    },
    "backend/templates/payment_requests/paymentrequest_list.html": {
        "Solicitudes de pago": "Emisiones",
        "<h1>Solicitudes de pago</h1>": "<h1>Emisiones</h1>",
        ">Nueva solicitud<": ">Nueva emisión<",
        "No hay solicitudes de pago registradas.": "No hay emisiones registradas.",
    },
    "backend/templates/payment_requests/accounts_payable_pending.html": {
        "Pagos aprobados pendientes por ejecutar": "Emisiones aprobadas pendientes por ejecutar",
        "<th>Solicitud</th>": "<th>Emisión</th>",
        "Ver solicitud": "Ver emisión",
        "Registrar pago": "Registrar pago en ERP",
        "No hay pagos aprobados pendientes por ejecutar.": "No hay emisiones aprobadas pendientes por ejecutar.",
    },
    "backend/templates/payment_requests/paymentrequest_detail.html": {
        "Solicitud de pago #{{ payment_request.id }}": "Emisión #{{ payment_request.id }}",
        "<h1>Solicitud de pago #{{ payment_request.id }}</h1>": "<h1>Emisión #{{ payment_request.id }}</h1>",
        "Cancelar solicitud": "Cancelar emisión",
        "La solicitud todavía no tiene ruta de aprobación generada.": "La emisión todavía no tiene ruta de aprobación generada.",
        "Registrar pago": "Registrar pago en ERP",
    },
    "backend/templates/payment_requests/paymentrequest_dashboard.html": {
        "Dashboard operativo de solicitudes": "Dashboard operativo de emisiones",
        "Total de solicitudes": "Total de emisiones",
        "Solicitudes aprobadas pendientes de pago": "Emisiones aprobadas pendientes de ejecución",
        "Total pendiente de pago:": "Total pendiente de ejecución:",
        "No hay solicitudes aprobadas pendientes de pago.": "No hay emisiones aprobadas pendientes de ejecución.",
        "<th>Solicitud</th>": "<th>Emisión</th>",
        "Ver solicitud": "Ver emisión",
        "Últimas solicitudes": "Últimas emisiones",
        "No hay solicitudes registradas.": "No hay emisiones registradas.",
    },
    "backend/templates/payment_requests/paymentrequest_report.html": {
        "Reporte operativo de solicitudes": "Reporte operativo de emisiones",
        "Total solicitudes": "Total emisiones",
        "Sin solicitudes para los filtros seleccionados.": "Sin emisiones para los filtros seleccionados.",
    },

    # Approval / audit UI
    "backend/templates/payment_approvals/pending_approval_steps.html": {
        "<th>Solicitud</th>": "<th>Emisión</th>",
        "Estado solicitud": "Estado emisión",
        "Ver solicitud": "Ver emisión",
        "No tienes solicitudes pendientes por aprobar.": "No tienes emisiones pendientes por aprobar.",
    },
    "backend/templates/payment_approvals/cross_action_audit_workbench.html": {
        "Trazabilidad transversal de solicitudes de pago.": "Trazabilidad transversal de emisiones.",
        ">Solicitud<": ">Emisión<",
        "placeholder=\"concepto solicitud\"": "placeholder=\"concepto emisión\"",
    },
    "backend/templates/payment_execution/paymentexecution_form.html": {
        "<h1>Registrar ejecucion de pago</h1>": "<h1>Registrar ejecución de pago en ERP</h1>",
        "<h2>Solicitud #{{ payment_request.id }}</h2>": "<h2>Emisión #{{ payment_request.id }}</h2>",
        "Registrar pago": "Registrar pago en ERP",
    },

    # Tests que validan navegación visible
    "backend/apps/accounts/tests/test_role_navigation_template.py": {
        '"Solicitudes"': '"Emisiones"',
    },
    "backend/apps/accounts/tests/test_role_navigation_integrated_matrix.py": {
        '("Solicitudes", "payment_requests:dashboard", PERM_VIEW_PAYMENT_REQUEST_DASHBOARD)': '("Emisiones", "payment_requests:dashboard", PERM_VIEW_PAYMENT_REQUEST_DASHBOARD)',
        '("Nueva solicitud", "payment_requests:create", PERM_CREATE_PAYMENT_REQUEST)': '("Nueva emisión", "payment_requests:create", PERM_CREATE_PAYMENT_REQUEST)',
    },

    # Bajo riesgo: textos de identidad del modulo accounts
    "backend/apps/accounts/README.md": {
        "Sistema de Rutas de Pago Oftalmi": "Sistema de Rutas de Emisión Oftalmi",
    },
    "backend/apps/accounts/views.py": {
        "Vista inicial autenticada del Sistema de Rutas de Pago.": "Vista inicial autenticada del Sistema de Rutas de Emisión.",
    },
}

changed_files = []

for file_name, mapping in replacements.items():
    path = Path(file_name)
    if not path.exists():
        print(f"WARN: no existe {file_name}")
        continue

    text = path.read_text(encoding="utf-8")
    original = text

    for old, new in mapping.items():
        text = text.replace(old, new)

    if text != original:
        path.write_text(text, encoding="utf-8")
        changed_files.append(file_name)
        print(f"OK: actualizado {file_name}")
    else:
        print(f"INFO: sin cambios {file_name}")

print("\nArchivos modificados:")
for item in changed_files:
    print(f"- {item}")
PY

echo "== Validacion diff whitespace =="
git diff --check

echo "== Busqueda de textos visibles pendientes en templates/accounts =="
grep -RniI \
  "Sistema de Rutas de Pago\|Rutas de Pago\|Ruta de Pago\|Nueva solicitud\|Solicitudes de pago\|Solicitud de pago\|Dashboard operativo de solicitudes\|Reporte operativo de solicitudes" \
  backend/templates backend/apps/accounts \
  || true

echo "== Ruff =="
docker compose exec backend ruff check .

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== Tests focales BR04 =="
docker compose exec backend python manage.py test \
  apps.accounts.tests.test_authentication_flow \
  apps.accounts.tests.test_role_navigation_template \
  apps.accounts.tests.test_role_navigation_integrated_matrix \
  apps.payment_requests.tests.test_dashboard \
  apps.payment_requests.tests.test_reports \
  apps.payment_approvals.tests.test_pending_workbench

echo "== Diff resumido =="
git diff --stat

echo "== Estado final =="
git status --short

echo "== FIN F2-PILOT-BR04 terminologia visible Emisiones =="
