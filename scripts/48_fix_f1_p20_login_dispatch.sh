#!/usr/bin/env bash
set -euo pipefail

# Fix F1-P20 - Corrige dispatch para usuario anónimo en AccountsPayablePendingView.
# Problema:
#   AnonymousUser no tiene atributo role cuando dispatch valida rol antes del LoginRequiredMixin.
# Solución:
#   En dispatch, si el usuario no está autenticado, delegar primero a super().dispatch().
#
# No crea modelos.
# No crea migraciones.
# No hace commit.

EXPECTED_BRANCH="feature/accounts-payable-workbench"

echo "== Fix F1-P20: dispatch login/role en Cuentas por Pagar =="

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "ERROR: este directorio no parece ser un repositorio Git."
  exit 1
fi

cd "$(git rev-parse --show-toplevel)"

CURRENT_BRANCH="$(git branch --show-current)"
if [ "$CURRENT_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ERROR: rama incorrecta."
  echo "Actual:   $CURRENT_BRANCH"
  echo "Esperada: $EXPECTED_BRANCH"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_requests/views.py")
text = path.read_text()

old = '''    def dispatch(self, request, *args, **kwargs):
        user = request.user
        if not user.is_superuser and user.role != UserRole.CUENTAS_POR_PAGAR:
            raise PermissionDenied("Su rol no permite acceder a Cuentas por Pagar.")
        return super().dispatch(request, *args, **kwargs)
'''

new = '''    def dispatch(self, request, *args, **kwargs):
        user = request.user
        if not user.is_authenticated:
            return super().dispatch(request, *args, **kwargs)

        if not user.is_superuser and user.role != UserRole.CUENTAS_POR_PAGAR:
            raise PermissionDenied("Su rol no permite acceder a Cuentas por Pagar.")

        return super().dispatch(request, *args, **kwargs)
'''

if old not in text:
    print("ERROR: no se encontró el bloque dispatch esperado.")
    print("Bloques cercanos a AccountsPayablePendingView:")
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if "class AccountsPayablePendingView" in line:
            start = max(0, index)
            end = min(len(lines), index + 35)
            for number in range(start, end):
                print(f"{number + 1}: {lines[number]}")
            break
    raise SystemExit(1)

text = text.replace(old, new, 1)
path.write_text(text)
print("OK: dispatch corregido para usuario anónimo.")
PY

echo "== Validación sintáctica Python =="
python3 -m py_compile \
  backend/apps/payment_requests/views.py \
  backend/apps/payment_requests/urls.py \
  backend/apps/payment_requests/tests/test_accounts_payable_workbench.py

echo "== Estado de archivos =="
git status --short

cat <<'NEXT'

Repite validación completa:

nordvpn disconnect
sleep 3

git status
git log --oneline --max-count=5

docker compose exec backend ruff check .
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests apps.payment_documents apps.payment_approvals

nordvpn connect United_States
nordvpn status

Si todo queda OK:

git add backend/apps/payment_requests/views.py \
  backend/apps/payment_requests/urls.py \
  backend/templates/payment_requests/accounts_payable_pending.html \
  backend/apps/payment_requests/tests/test_accounts_payable_workbench.py \
  scripts/46_f1_p20_accounts_payable_workbench.sh \
  scripts/47_fix_f1_p20_views_imports.sh \
  scripts/48_fix_f1_p20_login_dispatch.sh

git commit -m "feat: add accounts payable workbench"
git push -u origin feature/accounts-payable-workbench

NEXT
