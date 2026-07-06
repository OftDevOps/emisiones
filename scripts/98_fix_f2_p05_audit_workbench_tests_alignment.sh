#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_ROOT"

echo "== Fix F2-P05: alinear audit workbench con LoginRequiredMixin y matriz de permisos =="

VIEW_FILE="backend/apps/payment_approvals/views.py"
TEST_FILE="backend/apps/payment_approvals/tests/test_cross_action_audit_workbench.py"
INTEGRATED_TEST="backend/apps/accounts/tests/test_role_navigation_integrated_matrix.py"

for file in "$VIEW_FILE" "$TEST_FILE" "$INTEGRATED_TEST"; do
  if [ ! -f "$file" ]; then
    echo "ERROR: no existe $file"
    exit 1
  fi
done

python3 - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_approvals/views.py")
text = path.read_text(encoding="utf-8")

old = '''    def dispatch(self, request, *args, **kwargs):
        _require_operational_permission(
            request.user,
            PERM_VIEW_AUDIT_WORKBENCH,
            "Su rol no permite acceder a la auditoria de acciones criticas.",
        )
        return super().dispatch(request, *args, **kwargs)
'''
new = '''    def dispatch(self, request, *args, **kwargs):
        if request.user.is_authenticated:
            _require_operational_permission(
                request.user,
                PERM_VIEW_AUDIT_WORKBENCH,
                "Su rol no permite acceder a la auditoria de acciones criticas.",
            )
        return super().dispatch(request, *args, **kwargs)
'''

if old not in text:
    if "def dispatch(self, request, *args, **kwargs):" not in text:
        raise SystemExit("ERROR: no se encontro dispatch de CrossActionAuditWorkbenchView para ajustar.")
    print("WARN: el bloque exacto de dispatch no coincide; se asume que ya fue ajustado o requiere revision manual.")
else:
    text = text.replace(old, new)
    path.write_text(text, encoding="utf-8")
    print("OK: dispatch ajustado para preservar redireccion login de usuarios anonimos.")
PY

python3 - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_approvals/tests/test_cross_action_audit_workbench.py")
text = path.read_text(encoding="utf-8")
original = text

# El workbench de auditoria pertenece a ADMINISTRADOR/AUDITOR segun PERM_VIEW_AUDIT_WORKBENCH.
# Las pruebas historicas usaban Cuentas por Pagar para un acceso que ahora debe ser 403.
text = text.replace("UserRole.CUENTAS_POR_PAGAR", "UserRole.AUDITOR")
text = text.replace('email="cxp.audit@oftalmi.com"', 'email="auditor.audit@oftalmi.com"')
text = text.replace('email="cxp.audit.otra@oftalmi.com"', 'email="auditor.audit.otra@oftalmi.com"')
text = text.replace('cxp.audit@oftalmi.com', 'auditor.audit@oftalmi.com')
text = text.replace('cxp.audit.otra@oftalmi.com', 'auditor.audit.otra@oftalmi.com')

if text != original:
    path.write_text(text, encoding="utf-8")
    print("OK: pruebas existentes de audit workbench alineadas a rol AUDITOR.")
else:
    print("WARN: no se realizaron reemplazos en pruebas existentes; validar manualmente si vuelve a fallar.")
PY

echo "== Verificacion de cambios clave =="
grep -Rni "PERM_VIEW_AUDIT_WORKBENCH\|def dispatch\|UserRole.AUDITOR\|UserRole.CUENTAS_POR_PAGAR" "$VIEW_FILE" "$TEST_FILE" | sed -n '1,120p'

echo "== Ruff focal =="
docker compose exec backend ruff check \
  apps/payment_approvals/views.py \
  apps/payment_approvals/tests/test_cross_action_audit_workbench.py \
  apps/accounts/tests/test_role_navigation_integrated_matrix.py

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
