#!/usr/bin/env bash
set -euo pipefail

# Fix F1-P21 - materializa migración pendiente de status detectada por makemigrations.
# Contexto:
#   makemigrations --check --dry-run detectó:
#   payment_requests/migrations/0005_alter_paymentrequest_status.py
#
# Este fix:
# - Genera la migración faltante usando manage.py makemigrations payment_requests.
# - Verifica que la migración quede creada.
# - No crea modelos adicionales.
# - No hace commit.
# - No hace push.

EXPECTED_BRANCH="feature/payment-execution-basic"

echo "== Fix F1-P21: generar migración pendiente de PaymentRequest.status =="

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

if [ -f backend/apps/payment_requests/migrations/0005_alter_paymentrequest_status.py ]; then
  echo "OK: la migración 0005 ya existe."
else
  echo "== Generando migración pendiente =="
  docker compose exec backend python manage.py makemigrations payment_requests
fi

if [ ! -f backend/apps/payment_requests/migrations/0005_alter_paymentrequest_status.py ]; then
  echo "ERROR: no se generó backend/apps/payment_requests/migrations/0005_alter_paymentrequest_status.py"
  exit 1
fi

echo "== Migración generada =="
sed -n '1,220p' backend/apps/payment_requests/migrations/0005_alter_paymentrequest_status.py

echo "== Validación sintáctica Python =="
python3 -m py_compile \
  backend/apps/payment_requests/models.py \
  backend/apps/payment_requests/views.py \
  backend/apps/payment_requests/urls.py \
  backend/apps/payment_requests/migrations/0004_paymentrequest_paid_status.py \
  backend/apps/payment_requests/migrations/0005_alter_paymentrequest_status.py \
  backend/apps/payment_execution/apps.py \
  backend/apps/payment_execution/models.py \
  backend/apps/payment_execution/forms.py \
  backend/apps/payment_execution/views.py \
  backend/apps/payment_execution/admin.py \
  backend/apps/payment_execution/migrations/0001_initial.py \
  backend/apps/payment_execution/tests/test_views.py

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

git add backend/config/settings/base.py \
  backend/apps/payment_requests/models.py \
  backend/apps/payment_requests/views.py \
  backend/apps/payment_requests/urls.py \
  backend/apps/payment_requests/migrations/0004_paymentrequest_paid_status.py \
  backend/apps/payment_requests/migrations/0005_alter_paymentrequest_status.py \
  backend/templates/payment_requests/accounts_payable_pending.html \
  backend/apps/payment_execution \
  backend/templates/payment_execution \
  scripts/49_f1_p21_payment_execution_basic.sh \
  scripts/50_fix_f1_p21_pending_status_migration.sh

git commit -m "feat: add basic payment execution registration"
git push -u origin feature/payment-execution-basic

NEXT
