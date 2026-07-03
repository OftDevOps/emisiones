#!/usr/bin/env bash
set -euo pipefail

echo "== Fix F1-P23: regenerar migracion real y alinear test con modelos existentes =="

ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$ROOT"

echo "== Rama actual =="
git branch --show-current

echo "== Estado inicial =="
git status --short

MIG="backend/apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py"
TEST="backend/apps/payment_execution/tests/test_cross_action_audit.py"

if [[ ! -f backend/manage.py ]]; then
  echo "ERROR: no se encontro backend/manage.py. Ejecuta desde el repo correcto." >&2
  exit 1
fi

mkdir -p backend/apps/payment_execution/tests

echo "== Limpiar backups y migraciones 0003 no versionables =="
rm -f backend/apps/payment_approvals/models.py.bak_f1_p23_*
rm -f backend/apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py.bak_f1_p23_*
rm -f backend/apps/payment_approvals/migrations/0003_alter_paymentapprovalaction_action.py
rm -f backend/apps/payment_approvals/migrations/0003_*.py

# La migracion 0002 aun no esta versionada, se regenera desde el estado real del modelo.
echo "== Regenerar migracion 0002 desde Django para evitar drift de choices =="
rm -f "$MIG"
docker compose exec backend python manage.py makemigrations payment_approvals --name paymentapprovalaction_payment_executed

if [[ ! -f "$MIG" ]]; then
  echo "ERROR: Django no genero $MIG" >&2
  exit 1
fi

echo "== Regenerar test_cross_action_audit.py usando factories del modelo real =="
cat > "$TEST" <<'PY'
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from apps.accounts.models import UserRole
from apps.beneficiaries.models import Beneficiary
from apps.organization.models import Company
from apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction
from apps.payment_execution.models import PaymentExecution
from apps.payment_requests.models import PaymentRequest, PaymentRequestStatus


class CrossActionAuditTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Empresa F1-P23")
        self.user = get_user_model().objects.create_user(
            email="cxp.f1p23@example.com",
            password="testpass123",
            role=UserRole.CUENTAS_POR_PAGAR,
        )
        self.user.companies.add(self.company)

        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            name="Proveedor F1-P23",
            identification="J-F1P23",
        )
        self.payment_request = PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.user,
            amount=Decimal("150.00"),
            concept="Pago F1-P23",
            due_date=timezone.localdate(),
            status=PaymentRequestStatus.APPROVED,
        )

    def test_payment_execution_registers_cross_action_audit(self):
        PaymentExecution.objects.create(
            payment_request=self.payment_request,
            executed_by=self.user,
            paid_at=timezone.localdate(),
            paid_amount=Decimal("150.00"),
            bank_reference="REF-F1P23",
            note="Pago validado por CxP",
        )

        action = PaymentApprovalAction.objects.get(
            payment_request=self.payment_request,
            action=ApprovalActionType.PAYMENT_EXECUTED,
        )
        self.assertEqual(action.performed_by, self.user)
        self.assertEqual(action.role, UserRole.CUENTAS_POR_PAGAR)
        self.assertIn("REF-F1P23", action.comment)
        self.assertIn("150.00", action.comment)

    def test_detail_shows_cross_action_audit_history(self):
        PaymentApprovalAction.objects.create(
            payment_request=self.payment_request,
            action=ApprovalActionType.PAYMENT_EXECUTED,
            performed_by=self.user,
            role=UserRole.CUENTAS_POR_PAGAR,
            comment="Pago ejecutado. Referencia bancaria: REF-F1P23. Monto pagado: 150.00.",
        )
        self.client.force_login(self.user)

        response = self.client.get(
            reverse("payment_requests:detail", kwargs={"pk": self.payment_request.pk})
        )

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Historial de acciones críticas")
        self.assertContains(response, "Pago ejecutado")
        self.assertContains(response, "REF-F1P23")

    def test_detail_shows_empty_audit_history_message(self):
        self.client.force_login(self.user)

        response = self.client.get(
            reverse("payment_requests:detail", kwargs={"pk": self.payment_request.pk})
        )

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "No hay acciones críticas registradas")
PY

echo "== Validacion focalizada =="
docker compose exec backend ruff check \
  apps/payment_approvals/models.py \
  apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py \
  apps/payment_execution/models.py \
  apps/payment_execution/tests/test_cross_action_audit.py

docker compose exec backend python manage.py check

echo "== makemigrations check =="
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== Test focalizado F1-P23 =="
docker compose exec backend python manage.py test apps.payment_execution.tests.test_cross_action_audit

echo "== Estado final =="
git status --short
