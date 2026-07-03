#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== Fix F1-P23: migracion pendiente y test_cross_action_audit =="
echo "== Rama actual =="
git branch --show-current

echo "== Estado inicial =="
git status --short

MIGRATION="backend/apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py"
TEST_FILE="backend/apps/payment_execution/tests/test_cross_action_audit.py"

echo "== Limpiar backups no versionables =="
rm -f backend/apps/payment_approvals/models.py.bak_f1_p23_*
rm -f backend/apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py.bak_f1_p23_*

if [ ! -f "$MIGRATION" ]; then
  echo "ERROR: no existe $MIGRATION" >&2
  exit 1
fi

if [ ! -f "$TEST_FILE" ]; then
  echo "ERROR: no existe $TEST_FILE" >&2
  exit 1
fi

echo "== Normalizar migracion 0002 segun modelo actual =="
python - <<'PY'
from pathlib import Path
path = Path("backend/apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py")
path.write_text('''# Generated manually for F1-P23.\nfrom django.db import migrations, models\n\n\nclass Migration(migrations.Migration):\n\n    dependencies = [\n        ("payment_approvals", "0001_initial"),\n    ]\n\n    operations = [\n        migrations.AlterField(\n            model_name="paymentapprovalaction",\n            name="action",\n            field=models.CharField(\n                choices=[\n                    ("SUBMIT", "Enviar"),\n                    ("APPROVE", "Aprobar"),\n                    ("REJECT", "Rechazar"),\n                    ("CANCEL", "Cancelar"),\n                    ("COMMENT", "Comentario"),\n                    ("PAYMENT_EXECUTED", "Pago ejecutado"),\n                ],\n                max_length=40,\n                verbose_name="acción",\n            ),\n        ),\n    ]\n''', encoding="utf-8")
PY

echo "== Regenerar test_cross_action_audit.py sin campos inexistentes en CustomUser =="
python - <<'PY'
from pathlib import Path
path = Path("backend/apps/payment_execution/tests/test_cross_action_audit.py")
path.write_text('''from datetime import date\nfrom decimal import Decimal\n\nfrom django.contrib.auth import get_user_model\nfrom django.test import TestCase\nfrom django.urls import reverse\n\nfrom apps.accounts.models import UserRole\nfrom apps.beneficiaries.models import Beneficiary\nfrom apps.organization.models import Company\nfrom apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction\nfrom apps.payment_execution.models import PaymentExecution\nfrom apps.payment_requests.models import PaymentRequest, PaymentRequestStatus\n\n\nclass CrossActionAuditTests(TestCase):\n    def setUp(self):\n        self.company = Company.objects.create(name="Empresa F1-P23", tax_id="J-F1P23")\n        self.user = get_user_model().objects.create_user(\n            email="cxp.f1p23@example.com",\n            password="testpass123",\n            role=UserRole.CUENTAS_POR_PAGAR,\n        )\n        self.user.companies.add(self.company)\n        self.beneficiary = Beneficiary.objects.create(\n            company=self.company,\n            name="Proveedor F1-P23",\n            document_number="V-F1P23",\n        )\n        self.payment_request = PaymentRequest.objects.create(\n            company=self.company,\n            beneficiary=self.beneficiary,\n            requested_by=self.user,\n            amount=Decimal("150.00"),\n            status=PaymentRequestStatus.APPROVED,\n            description="Solicitud aprobada para auditoría transversal",\n        )\n\n    def test_payment_execution_registers_cross_action_audit(self):\n        PaymentExecution.objects.create(\n            payment_request=self.payment_request,\n            executed_by=self.user,\n            paid_at=date.today(),\n            paid_amount=Decimal("150.00"),\n            bank_reference="REF-F1-P23",\n            note="Pago validado",\n        )\n\n        action = PaymentApprovalAction.objects.get(\n            payment_request=self.payment_request,\n            action=ApprovalActionType.PAYMENT_EXECUTED,\n        )\n        self.assertEqual(action.performed_by, self.user)\n        self.assertEqual(action.role, UserRole.CUENTAS_POR_PAGAR)\n        self.assertIn("REF-F1-P23", action.comment)\n        self.assertIn("150.00", action.comment)\n\n    def test_detail_shows_cross_action_audit_history(self):\n        PaymentApprovalAction.objects.create(\n            payment_request=self.payment_request,\n            action=ApprovalActionType.PAYMENT_EXECUTED,\n            performed_by=self.user,\n            role=UserRole.CUENTAS_POR_PAGAR,\n            comment="Pago ejecutado. Referencia bancaria: REF-F1-P23.",\n        )\n\n        self.client.force_login(self.user)\n        response = self.client.get(\n            reverse("payment_requests:detail", kwargs={"pk": self.payment_request.pk})\n        )\n\n        self.assertEqual(response.status_code, 200)\n        self.assertContains(response, "Historial de acciones críticas")\n        self.assertContains(response, "Pago ejecutado")\n        self.assertContains(response, "REF-F1-P23")\n\n    def test_detail_shows_empty_audit_history_message(self):\n        self.client.force_login(self.user)\n        response = self.client.get(\n            reverse("payment_requests:detail", kwargs={"pk": self.payment_request.pk})\n        )\n\n        self.assertEqual(response.status_code, 200)\n        self.assertContains(response, "Sin acciones críticas registradas")\n''', encoding="utf-8")
PY

echo "== Eliminar migraciones 0003 no deseadas si quedaron generadas =="
rm -f backend/apps/payment_approvals/migrations/0003_alter_paymentapprovalaction_action.py
rm -f backend/apps/payment_approvals/migrations/0003_alter_paymentapprovalaction_action_and_more.py

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

echo "OK: Fix F1-P23 aplicado. Ejecuta validacion completa antes de commit."
