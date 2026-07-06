#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_ROOT"

echo "== Fix F2-P05: aplicar permiso backend en audit workbench =="

VIEW_FILE="backend/apps/payment_approvals/views.py"
TEST_FILE="backend/apps/accounts/tests/test_role_navigation_integrated_matrix.py"
DOC_FILE="docs/f2_p05_pruebas_integradas_navegacion_rol.md"

if [ ! -f "$VIEW_FILE" ]; then
  echo "ERROR: no existe $VIEW_FILE"
  exit 1
fi

if [ ! -f "$TEST_FILE" ]; then
  echo "ERROR: no existe $TEST_FILE. Ejecutar primero F2-P05."
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_approvals/views.py")
text = path.read_text(encoding="utf-8")

old_import = "from apps.accounts.role_permissions import (\n    user_has_permission,\n)"
new_import = "from apps.accounts.role_permissions import (\n    PERM_VIEW_AUDIT_WORKBENCH,\n    user_has_permission,\n)"
if old_import in text and "PERM_VIEW_AUDIT_WORKBENCH" not in text.split("from django.contrib", 1)[0]:
    text = text.replace(old_import, new_import)
elif "PERM_VIEW_AUDIT_WORKBENCH" not in text:
    raise SystemExit("ERROR: no se pudo insertar PERM_VIEW_AUDIT_WORKBENCH en imports.")

class_header = "class CrossActionAuditWorkbenchView(LoginRequiredMixin, ListView):\n"
dispatch_block = """class CrossActionAuditWorkbenchView(LoginRequiredMixin, ListView):
    def dispatch(self, request, *args, **kwargs):
        _require_operational_permission(
            request.user,
            PERM_VIEW_AUDIT_WORKBENCH,
            "Su rol no permite acceder a la auditoria de acciones criticas.",
        )
        return super().dispatch(request, *args, **kwargs)

"""

if "PERM_VIEW_AUDIT_WORKBENCH" in text and "Su rol no permite acceder a la auditoria de acciones criticas." not in text:
    if class_header not in text:
        raise SystemExit("ERROR: no se encontro CrossActionAuditWorkbenchView.")
    text = text.replace(class_header, dispatch_block)

path.write_text(text, encoding="utf-8")
PY

cat >> "$DOC_FILE" <<'MD'

## Ajuste derivado por prueba integrada

Durante F2-P05 se detecto que la vista `payment_approvals:audit` estaba visible/alcanzable para un rol sin permiso operativo de auditoria.

La matriz backend define `payment_approvals.view_audit` solo para:

- ADMINISTRADOR
- AUDITOR

Se corrigio `CrossActionAuditWorkbenchView` para aplicar `_require_operational_permission` en `dispatch`, manteniendo backend como fuente autoritativa de control de acceso.
MD

echo "== Verificacion de parche =="
grep -n "PERM_VIEW_AUDIT_WORKBENCH\|class CrossActionAuditWorkbenchView\|Su rol no permite acceder a la auditoria" "$VIEW_FILE"

echo "== Ruff focal =="
docker compose exec backend ruff check apps/accounts/tests/test_role_navigation_integrated_matrix.py apps/payment_approvals/views.py

echo "== Tests focales F2-P04B/F2-P05 =="
docker compose exec backend python manage.py test \
  apps.accounts.tests.test_role_navigation_template \
  apps.accounts.tests.test_role_navigation_integrated_matrix

echo "== Test focal audit workbench existente =="
docker compose exec backend python manage.py test apps.payment_approvals.tests.test_cross_action_audit_workbench

echo "== Validacion global rapida =="
docker compose exec backend ruff check .
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== Estado posterior =="
git status --short
