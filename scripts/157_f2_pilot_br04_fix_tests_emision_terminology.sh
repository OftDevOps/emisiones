#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== F2-PILOT-BR04B: ajustar tests a terminologia Emisiones =="
echo "== Ruta =="
pwd

echo "== Estado inicial =="
git status --short

python3 - <<'PY'
from pathlib import Path

replacements = {
    "backend/apps/payment_requests/tests/test_dashboard.py": {
        '"Solicitudes aprobadas pendientes de pago"': '"Emisiones aprobadas pendientes de ejecución"',
        '"Total pendiente de pago:"': '"Total pendiente de ejecución:"',
        '"Ver solicitud"': '"Ver emisión"',
        '"No hay solicitudes aprobadas pendientes de pago."': '"No hay emisiones aprobadas pendientes de ejecución."',
        '"Total de solicitudes"': '"Total de emisiones"',
        '"Últimas solicitudes"': '"Últimas emisiones"',
        '"No hay solicitudes registradas."': '"No hay emisiones registradas."',
    },
    "backend/apps/payment_requests/tests/test_reports.py": {
        '"Reporte operativo de solicitudes"': '"Reporte operativo de emisiones"',
        '"Total solicitudes"': '"Total emisiones"',
        '"Sin solicitudes para los filtros seleccionados."': '"Sin emisiones para los filtros seleccionados."',
    },
    "backend/apps/payment_approvals/tests/test_pending_workbench.py": {
        '"No tienes solicitudes pendientes por aprobar."': '"No tienes emisiones pendientes por aprobar."',
        '"Solicitud"': '"Emisión"',
        '"Estado solicitud"': '"Estado emisión"',
        '"Ver solicitud"': '"Ver emisión"',
    },
}

changed_files = []
for file_name, mapping in replacements.items():
    path = Path(file_name)
    if not path.exists():
        print(f"ERROR: no existe {file_name}")
        raise SystemExit(1)
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

echo "== Busqueda de asserts pendientes con terminologia anterior en tests focales =="
grep -RniI \
  "Solicitudes aprobadas pendientes de pago\|Reporte operativo de solicitudes\|No tienes solicitudes pendientes por aprobar\|Total solicitudes\|Estado solicitud\|Ver solicitud" \
  backend/apps/payment_requests/tests/test_dashboard.py \
  backend/apps/payment_requests/tests/test_reports.py \
  backend/apps/payment_approvals/tests/test_pending_workbench.py \
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

echo "== Estado final =="
git status --short

echo "== FIN F2-PILOT-BR04B =="
