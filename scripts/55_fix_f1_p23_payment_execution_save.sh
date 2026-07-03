#!/usr/bin/env bash
set -euo pipefail

EXPECTED_BRANCH="feature/cross-action-audit"

echo "== Fix F1-P23: auditoría en PaymentExecution.save =="

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
import re

model_path = Path("backend/apps/payment_execution/models.py")
if not model_path.exists():
    raise SystemExit(f"ERROR: no existe {model_path}")

text = model_path.read_text()

if "from apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction" not in text:
    anchor = "from apps.payment_requests.models import PaymentRequest, PaymentRequestStatus\n"
    if anchor not in text:
        raise SystemExit("ERROR: no se encontró import de PaymentRequest/PaymentRequestStatus.")
    text = text.replace(
        anchor,
        "from apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction\n" + anchor,
        1,
    )

save_pattern = re.compile(
    r"    def save\(self, \*args, \*\*kwargs\):\n"
    r"(?:        .*\n)+?"
    r"        return result\n",
    re.MULTILINE,
)

new_save = """    def save(self, *args, **kwargs):
        is_new = self.pk is None
        self.full_clean()
        result = super().save(*args, **kwargs)

        if self.payment_request.status != PaymentRequestStatus.PAID:
            self.payment_request.status = PaymentRequestStatus.PAID
            self.payment_request.save(update_fields=["status", "updated_at"])

        if is_new:
            PaymentApprovalAction.objects.create(
                payment_request=self.payment_request,
                action=ApprovalActionType.PAYMENT_EXECUTED,
                performed_by=self.executed_by,
                role=self.executed_by.role,
                comment=(
                    f"Pago ejecutado. Referencia bancaria: {self.bank_reference}. "
                    f"Monto pagado: {self.paid_amount}."
                ),
            )

        return result
"""

if "class PaymentExecution" not in text:
    raise SystemExit("ERROR: no se encontró class PaymentExecution.")

if not save_pattern.search(text):
    raise SystemExit("ERROR: no se encontró método save en PaymentExecution.")

text = save_pattern.sub(new_save, text, count=1)

model_path.write_text(text)
print("OK: PaymentExecution.save normalizado con acción PAYMENT_EXECUTED.")
PY

echo "== Validación sintáctica Python de archivos F1-P23 =="
python3 -m py_compile \
  backend/apps/payment_approvals/models.py \
  backend/apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py \
  backend/apps/payment_execution/models.py \
  backend/apps/payment_execution/tests/test_cross_action_audit.py

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

git add backend/apps/payment_approvals/models.py \
  backend/apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py \
  backend/apps/payment_execution/models.py \
  backend/apps/payment_execution/tests/test_cross_action_audit.py \
  backend/templates/payment_requests/paymentrequest_detail.html \
  scripts/54_f1_p23_cross_action_audit.sh \
  scripts/55_fix_f1_p23_payment_execution_save.sh

git commit -m "feat: add cross action audit trail"
git push -u origin feature/cross-action-audit

NEXT
