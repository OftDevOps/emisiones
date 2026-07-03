#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== Fix F1-P23: enum PAYMENT_EXECUTED y tests =="
echo "== Rama actual =="
git branch --show-current

echo "== Estado inicial =="
git status --short

APPROVAL_MODELS="backend/apps/payment_approvals/models.py"
EXEC_MODELS="backend/apps/payment_execution/models.py"
AUDIT_TEST="backend/apps/payment_execution/tests/test_cross_action_audit.py"
MIGRATION="backend/apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py"
DETAIL_TEMPLATE="backend/templates/payment_requests/paymentrequest_detail.html"

python - <<'PY'
from pathlib import Path

approval_models = Path("backend/apps/payment_approvals/models.py")
text = approval_models.read_text()

if "class ApprovalActionType" not in text:
    raise SystemExit("ERROR: no se encontro class ApprovalActionType en payment_approvals/models.py")

if "PAYMENT_EXECUTED" not in text:
    candidates = [
        '    REJECTED = "REJECTED", "Rechazado"\n',
        '    CANCELLED = "CANCELLED", "Cancelado"\n',
        '    SUBMITTED = "SUBMITTED", "Enviado a aprobacion"\n',
        '    SUBMITTED = "SUBMITTED", "Enviado a aprobación"\n',
    ]
    inserted = False
    for marker in candidates:
        if marker in text:
            text = text.replace(marker, marker + '    PAYMENT_EXECUTED = "PAYMENT_EXECUTED", "Pago ejecutado"\n', 1)
            inserted = True
            break
    if not inserted:
        lines = text.splitlines()
        out = []
        inside = False
        inserted_line = False
        for line in lines:
            out.append(line)
            if line.startswith("class ApprovalActionType"):
                inside = True
                continue
            if inside and not inserted_line and line.startswith("class "):
                out.insert(len(out)-1, '    PAYMENT_EXECUTED = "PAYMENT_EXECUTED", "Pago ejecutado"')
                inserted_line = True
                inside = False
        if inside and not inserted_line:
            out.append('    PAYMENT_EXECUTED = "PAYMENT_EXECUTED", "Pago ejecutado"')
            inserted_line = True
        if not inserted_line:
            raise SystemExit("ERROR: no se pudo insertar PAYMENT_EXECUTED")
        text = "\n".join(out) + "\n"
else:
    # Si existe fuera de lugar, asegurar que este dentro del enum.
    enum_start = text.index("class ApprovalActionType")
    next_class = text.find("\nclass ", enum_start + 1)
    enum_block = text[enum_start: next_class if next_class != -1 else len(text)]
    if "PAYMENT_EXECUTED" not in enum_block:
        text = text.replace('PAYMENT_EXECUTED = "PAYMENT_EXECUTED", "Pago ejecutado"\n', "")
        marker = 'class ApprovalActionType(models.TextChoices):\n'
        if marker not in text:
            raise SystemExit("ERROR: ApprovalActionType no parece heredar de models.TextChoices")
        text = text.replace(marker, marker + '    PAYMENT_EXECUTED = "PAYMENT_EXECUTED", "Pago ejecutado"\n', 1)

approval_models.write_text(text)
PY

python - <<'PY'
from pathlib import Path

exec_models = Path("backend/apps/payment_execution/models.py")
text = exec_models.read_text()

if "from apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction" not in text:
    lines = text.splitlines()
    insert_at = 0
    while insert_at < len(lines) and (lines[insert_at].startswith("from ") or lines[insert_at].startswith("import ") or not lines[insert_at].strip()):
        insert_at += 1
    lines.insert(insert_at, "from apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction")
    text = "\n".join(lines) + "\n"

if "PaymentApprovalAction.objects.create" not in text:
    raise SystemExit("ERROR: PaymentExecution.save no contiene creacion de PaymentApprovalAction")

exec_models.write_text(text)
PY

cat > "$MIGRATION" <<'PY'
# Generated manually for F1-P23 cross action audit.

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("payment_approvals", "0001_initial"),
    ]

    operations = [
        migrations.AlterField(
            model_name="paymentapprovalaction",
            name="action",
            field=models.CharField(
                choices=[
                    ("SUBMITTED", "Enviado a aprobación"),
                    ("APPROVED", "Aprobado"),
                    ("REJECTED", "Rechazado"),
                    ("CANCELLED", "Cancelado"),
                    ("PAYMENT_EXECUTED", "Pago ejecutado"),
                ],
                max_length=32,
            ),
        ),
    ]
PY

cat > "$AUDIT_TEST" <<'PY'
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from apps.accounts.models import UserRole
from apps.organization.models import Company
from apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction
from apps.payment_execution.models import PaymentExecution
from apps.payment_requests.models import PaymentRequest, PaymentRequestStatus


class CrossActionAuditTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Oftalmi", rif="J-00000000-0")
        self.user = get_user_model().objects.create_user(
            email="cxp.audit@example.com",
            password="testpass123",
            role=UserRole.CUENTAS_POR_PAGAR,
            company=self.company,
        )
        self.payment_request = PaymentRequest.objects.create(
            company=self.company,
            requested_by=self.user,
            beneficiary_name="Proveedor Auditado",
            concept="Pago auditado F1-P23",
            amount=Decimal("150.00"),
            status=PaymentRequestStatus.APPROVED,
        )

    def test_payment_execution_registers_cross_action_audit(self):
        PaymentExecution.objects.create(
            payment_request=self.payment_request,
            executed_by=self.user,
            paid_at=timezone.localdate(),
            paid_amount=Decimal("150.00"),
            bank_reference="REF-AUDIT-001",
            note="Pago auditado",
        )

        action = PaymentApprovalAction.objects.get(
            payment_request=self.payment_request,
            action=ApprovalActionType.PAYMENT_EXECUTED,
        )
        self.assertEqual(action.performed_by, self.user)
        self.assertEqual(action.role, self.user.role)
        self.assertIn("REF-AUDIT-001", action.comment)
        self.assertIn("150.00", action.comment)

    def test_detail_shows_cross_action_audit_history(self):
        PaymentApprovalAction.objects.create(
            payment_request=self.payment_request,
            action=ApprovalActionType.PAYMENT_EXECUTED,
            performed_by=self.user,
            role=self.user.role,
            comment="Pago ejecutado. Referencia bancaria: REF-AUDIT-002. Monto pagado: 150.00.",
        )

        self.client.force_login(self.user)
        response = self.client.get(reverse("payment_requests:detail", args=[self.payment_request.pk]))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Historial de acciones críticas")
        self.assertContains(response, "Pago ejecutado")
        self.assertContains(response, "REF-AUDIT-002")

    def test_detail_shows_empty_audit_history_message(self):
        self.client.force_login(self.user)
        response = self.client.get(reverse("payment_requests:detail", args=[self.payment_request.pk]))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Sin acciones críticas registradas")
PY

echo "== Fragmento ApprovalActionType =="
sed -n '/class ApprovalActionType/,/class /p' "$APPROVAL_MODELS" | sed -n '1,80p'

echo "== Fragmento PaymentExecution.save =="
grep -n "def save\|PaymentApprovalAction\|PAYMENT_EXECUTED" "$EXEC_MODELS"

echo "== Validacion sintactica =="
python -m py_compile "$APPROVAL_MODELS" "$EXEC_MODELS" "$AUDIT_TEST" "$MIGRATION"

echo "== Estado final =="
git status --short

echo "OK: fix F1-P23 aplicado. Ejecuta validacion Docker completa."
