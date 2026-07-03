#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== F1-P23: saneamiento auditoría transversal =="
echo "== Rama y estado inicial =="
git branch --show-current
git status --short
git log --oneline --max-count=8 --decorate

CURRENT_BRANCH="$(git branch --show-current)"
if [ "$CURRENT_BRANCH" = "develop" ] || [ "$CURRENT_BRANCH" = "main" ]; then
  echo "ERROR: no ejecutar saneamiento sobre $CURRENT_BRANCH. Cambia o crea feature/cross-action-audit."
  exit 1
fi

MODELS_FILE="backend/apps/payment_execution/models.py"
APPROVAL_MODELS_FILE="backend/apps/payment_approvals/models.py"
DETAIL_TEMPLATE="backend/templates/payment_requests/paymentrequest_detail.html"
TEST_FILE="backend/apps/payment_execution/tests/test_cross_action_audit.py"
MIGRATION_FILE="backend/apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py"

for path in "$MODELS_FILE" "$APPROVAL_MODELS_FILE" "$DETAIL_TEMPLATE"; do
  if [ ! -f "$path" ]; then
    echo "ERROR: archivo requerido no existe: $path"
    exit 1
  fi
done

mkdir -p backend/apps/payment_execution/tests
mkdir -p backend/apps/payment_approvals/migrations

python - <<'PY'
from pathlib import Path
import re

models_path = Path("backend/apps/payment_execution/models.py")
text = models_path.read_text()

# Normalizar imports requeridos.
if "from apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction" not in text:
    text = "from apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction\n" + text

# Reemplazar import de payment_requests para asegurar PaymentRequestStatus.
if "from apps.payment_requests.models import" in text:
    text = re.sub(
        r"from apps\.payment_requests\.models import .*",
        "from apps.payment_requests.models import PaymentRequest, PaymentRequestStatus",
        text,
        count=1,
    )
else:
    text = "from apps.payment_requests.models import PaymentRequest, PaymentRequestStatus\n" + text

save_method = '''    def save(self, *args, **kwargs):
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
'''

# Eliminar todos los def save dentro de la clase, hasta el próximo método de clase o fin de clase.
pattern = re.compile(
    r"\n    def save\(self, \*args, \*\*kwargs\):\n(?:        .*\n|\n)*?(?=\n    def |\nclass |\Z)",
    re.MULTILINE,
)
text = pattern.sub("\n", text)

# Insertar save antes del class Meta si existe; si no, al final de la clase/archivo.
if "\n    class Meta:" in text:
    text = text.replace("\n    class Meta:", "\n" + save_method + "\n    class Meta:", 1)
else:
    text = text.rstrip() + "\n\n" + save_method

# Limpieza de múltiples líneas en blanco excesivas.
text = re.sub(r"\n{3,}", "\n\n", text)
models_path.write_text(text)
PY

python - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_approvals/models.py")
text = path.read_text()

if "PAYMENT_EXECUTED" not in text:
    marker = "REJECTED = \"REJECTED\", \"Rechazado\""
    if marker in text:
        text = text.replace(
            marker,
            marker + "\n    PAYMENT_EXECUTED = \"PAYMENT_EXECUTED\", \"Pago ejecutado\"",
            1,
        )
    else:
        marker = "APPROVED = \"APPROVED\", \"Aprobado\""
        if marker not in text:
            raise SystemExit("ERROR: no se pudo ubicar ApprovalActionType para insertar PAYMENT_EXECUTED")
        text = text.replace(
            marker,
            marker + "\n    PAYMENT_EXECUTED = \"PAYMENT_EXECUTED\", \"Pago ejecutado\"",
            1,
        )

path.write_text(text)
PY

cat > "$MIGRATION_FILE" <<'PY'
# Generated manually for F1-P23 cross-action audit.

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
                    ("CANCELED", "Cancelado"),
                    ("PAYMENT_EXECUTED", "Pago ejecutado"),
                ],
                max_length=32,
            ),
        ),
    ]
PY

python - <<'PY'
from pathlib import Path

path = Path("backend/templates/payment_requests/paymentrequest_detail.html")
text = path.read_text()

if "Historial de acciones críticas" not in text:
    block = '''
<section class="card mt-4">
  <div class="card-header">
    <h2 class="h5 mb-0">Historial de acciones críticas</h2>
  </div>
  <div class="card-body">
    {% if approval_actions %}
      <div class="table-responsive">
        <table class="table table-sm table-striped align-middle">
          <thead>
            <tr>
              <th>Fecha</th>
              <th>Acción</th>
              <th>Usuario</th>
              <th>Rol</th>
              <th>Comentario</th>
            </tr>
          </thead>
          <tbody>
            {% for action in approval_actions %}
              <tr>
                <td>{{ action.created_at|date:"d/m/Y H:i" }}</td>
                <td>{{ action.get_action_display }}</td>
                <td>{{ action.performed_by }}</td>
                <td>{{ action.get_role_display }}</td>
                <td>{{ action.comment|default:"-" }}</td>
              </tr>
            {% endfor %}
          </tbody>
        </table>
      </div>
    {% else %}
      <p class="text-muted mb-0">Sin acciones críticas registradas.</p>
    {% endif %}
  </div>
</section>
'''
    if "{% endblock" in text:
        text = text.replace("{% endblock", block + "\n{% endblock", 1)
    else:
        text = text.rstrip() + "\n" + block

path.write_text(text)
PY

cat > "$TEST_FILE" <<'PY'
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import UserRole
from apps.beneficiaries.models import Beneficiary
from apps.organization.models import Company
from apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction
from apps.payment_execution.models import PaymentExecution
from apps.payment_requests.models import PaymentRequest, PaymentRequestStatus


class CrossActionAuditTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi")
        self.user = get_user_model().objects.create_user(
            username="ap@example.com",
            email="ap@example.com",
            password="testpass123",
            role=UserRole.CUENTAS_POR_PAGAR,
            company=self.company,
        )
        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            name="Proveedor F1-P23",
            tax_id="J-12345678-9",
        )
        self.payment_request = PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.user,
            status=PaymentRequestStatus.APPROVED,
            amount=Decimal("100.00"),
            description="Solicitud aprobada F1-P23",
        )

    def test_payment_execution_registers_cross_action_audit(self):
        PaymentExecution.objects.create(
            payment_request=self.payment_request,
            executed_by=self.user,
            paid_amount=Decimal("100.00"),
            bank_reference="REF-F1-P23",
            note="Pago validado",
        )

        action = PaymentApprovalAction.objects.get(
            payment_request=self.payment_request,
            action=ApprovalActionType.PAYMENT_EXECUTED,
        )
        self.assertEqual(action.performed_by, self.user)
        self.assertEqual(action.role, self.user.role)
        self.assertIn("REF-F1-P23", action.comment)
        self.assertIn("100.00", action.comment)

    def test_detail_shows_cross_action_audit_history(self):
        PaymentApprovalAction.objects.create(
            payment_request=self.payment_request,
            action=ApprovalActionType.PAYMENT_EXECUTED,
            performed_by=self.user,
            role=self.user.role,
            comment="Pago ejecutado. Referencia bancaria: REF-VISIBLE.",
        )

        self.client.force_login(self.user)
        response = self.client.get(
            reverse("payment_requests:detail", args=[self.payment_request.pk])
        )

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Historial de acciones críticas")
        self.assertContains(response, "Pago ejecutado")
        self.assertContains(response, "REF-VISIBLE")

    def test_detail_shows_empty_audit_history_message(self):
        self.client.force_login(self.user)
        response = self.client.get(
            reverse("payment_requests:detail", args=[self.payment_request.pk])
        )

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Sin acciones críticas registradas.")
PY

echo "== Validación sintáctica Python =="
python -m py_compile "$MODELS_FILE" "$APPROVAL_MODELS_FILE" "$TEST_FILE" "$MIGRATION_FILE"

echo "== Verificación save duplicado =="
SAVE_COUNT="$(grep -n "def save(self" "$MODELS_FILE" | wc -l | tr -d ' ')"
grep -n "def save(self\|PAYMENT_EXECUTED\|PaymentApprovalAction" "$MODELS_FILE" || true
if [ "$SAVE_COUNT" != "1" ]; then
  echo "ERROR: PaymentExecution.save debe existir una sola vez. Actual: $SAVE_COUNT"
  exit 1
fi

echo "== Verificación archivos F1-P23 =="
grep -n "PAYMENT_EXECUTED" "$APPROVAL_MODELS_FILE" "$MIGRATION_FILE" "$TEST_FILE" "$MODELS_FILE"
grep -n "Historial de acciones críticas\|Sin acciones críticas registradas" "$DETAIL_TEMPLATE"

echo "== Estado final del saneamiento =="
git status --short

echo "OK: saneamiento F1-P23 aplicado. Ejecuta validación Docker completa antes de commit."
