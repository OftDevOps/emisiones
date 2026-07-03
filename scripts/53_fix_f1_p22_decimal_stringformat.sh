#!/usr/bin/env bash
set -euo pipefail

# Fix F1-P22 - Formato determinístico del monto pagado.
# Problema:
#   El test espera "250.00", pero el HTML sigue sin contener ese literal.
# Solución:
#   Usar stringformat:".2f" para evitar render sin ceros o localización.
#
# No crea modelos.
# No crea migraciones.
# No hace commit.

EXPECTED_BRANCH="feature/payment-execution-traceability"

echo "== Fix F1-P22: formato determinístico 250.00 en monto pagado =="

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

TEMPLATE="backend/templates/payment_requests/paymentrequest_detail.html"

if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: no existe $TEMPLATE"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re

path = Path("backend/templates/payment_requests/paymentrequest_detail.html")
text = path.read_text()

# Normaliza cualquier variante previa del render del monto pagado.
patterns = [
    r"\{\{\s*payment_execution\.paid_amount\s*\}\}\s*\{\{\s*payment_request\.currency\s*\}\}",
    r"\{\{\s*payment_execution\.paid_amount\|floatformat:2\s*\}\}\s*\{\{\s*payment_request\.currency\s*\}\}",
    r"\{\{\s*payment_execution\.paid_amount\|floatformat:'2'\s*\}\}\s*\{\{\s*payment_request\.currency\s*\}\}",
    r'\{\{\s*payment_execution\.paid_amount\|floatformat:"2"\s*\}\}\s*\{\{\s*payment_request\.currency\s*\}\}',
]

replacement = '{{ payment_execution.paid_amount|stringformat:".2f" }} {{ payment_request.currency }}'

changed = False
for pattern in patterns:
    text, count = re.subn(pattern, replacement, text)
    changed = changed or bool(count)

if replacement not in text:
    raise SystemExit("ERROR: no se pudo normalizar el render de payment_execution.paid_amount.")

path.write_text(text)

print("OK: monto pagado usa stringformat:.2f.")
PY

echo "== Verificación del fragmento en template =="
grep -n "paid_amount" "$TEMPLATE" || true

echo "== Validación sintáctica Python de tests tocados =="
python3 -m py_compile backend/apps/payment_execution/tests/test_traceability.py

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
docker compose exec backend python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests apps.payment_documents apps.payment_approvals apps.payment_execution

nordvpn connect United_States
nordvpn status

Si todo queda OK:

git add backend/apps/payment_requests/views.py \
  backend/templates/payment_requests/paymentrequest_detail.html \
  backend/apps/payment_execution/tests/test_traceability.py \
  scripts/51_f1_p22_payment_execution_traceability.sh \
  scripts/52_fix_f1_p22_decimal_format.sh \
  scripts/53_fix_f1_p22_decimal_stringformat.sh

git commit -m "feat: show payment execution traceability"
git push -u origin feature/payment-execution-traceability

NEXT
