#!/usr/bin/env bash
set -euo pipefail

# Fix F1-P22 - Formato decimal del monto pagado en trazabilidad.
# Problema:
#   El test espera "250.00", pero el template renderiza el Decimal como "250".
# Solución:
#   Usar floatformat:2 en payment_execution.paid_amount.
#
# No crea modelos.
# No crea migraciones.
# No hace commit.

EXPECTED_BRANCH="feature/payment-execution-traceability"

echo "== Fix F1-P22: formato decimal en trazabilidad de pago =="

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

path = Path("backend/templates/payment_requests/paymentrequest_detail.html")
text = path.read_text()

text = text.replace(
    "{{ payment_execution.paid_amount }} {{ payment_request.currency }}",
    "{{ payment_execution.paid_amount|floatformat:2 }} {{ payment_request.currency }}",
)

path.write_text(text)

print("OK: monto pagado formateado con dos decimales.")
PY

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
  scripts/52_fix_f1_p22_decimal_format.sh

git commit -m "feat: show payment execution traceability"
git push -u origin feature/payment-execution-traceability

NEXT
