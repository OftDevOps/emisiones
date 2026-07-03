#!/usr/bin/env bash
set -euo pipefail

# F1-P22 - Trazabilidad básica de ejecución de pago
# Proyecto: OftDevOps/emisiones
#
# Alcance:
# - Mostrar ejecución de pago en el detalle de la solicitud.
# - Mostrar fecha, monto pagado, referencia bancaria, observación y usuario ejecutor.
# - Mostrar botón "Registrar pago" solo si:
#     * la solicitud está APPROVED,
#     * no tiene ejecución registrada,
#     * el usuario es CUENTAS_POR_PAGAR o superuser.
# - Ocultar botón si la solicitud ya está PAID.
# - Agregar pruebas de visualización.
# - No crear modelos.
# - No crear migraciones.
# - No hacer commit ni push.

EXPECTED_BRANCH="feature/payment-execution-traceability"

echo "== F1-P22: Trazabilidad básica de ejecución de pago =="

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
  echo
  echo "Crea la rama con:"
  echo "  git switch develop"
  echo "  git pull origin develop"
  echo "  git switch -c $EXPECTED_BRANCH"
  exit 1
fi

echo "== Git status antes de aplicar cambios =="
git status --short

python3 - <<'PY'
from pathlib import Path
import re

views_path = Path("backend/apps/payment_requests/views.py")
detail_template_path = Path("backend/templates/payment_requests/paymentrequest_detail.html")
tests_dir = Path("backend/apps/payment_execution/tests")
tests_path = tests_dir / "test_traceability.py"

for path in [views_path, detail_template_path]:
    if not path.exists():
        raise SystemExit(f"ERROR: archivo requerido no existe: {path}")

tests_dir.mkdir(parents=True, exist_ok=True)
(tests_dir / "__init__.py").touch(exist_ok=True)

# ----------------------------------------------------------------------
# Update PaymentRequestDetailView context.
# ----------------------------------------------------------------------

views = views_path.read_text()

old = '''        context["approval_steps"] = approval_steps
        context["approval_actions"] = payment_request.approval_actions.all().order_by("-created_at")
        return context
'''

new = '''        payment_execution = getattr(payment_request, "payment_execution", None)
        can_execute_payment = (
            payment_execution is None
            and payment_request.status == PaymentRequestStatus.APPROVED
            and (
                user.is_superuser
                or user.role == UserRole.CUENTAS_POR_PAGAR
            )
        )

        context["approval_steps"] = approval_steps
        context["approval_actions"] = payment_request.approval_actions.all().order_by("-created_at")
        context["payment_execution"] = payment_execution
        context["can_execute_payment"] = can_execute_payment
        return context
'''

if old not in views:
    if "context[\"payment_execution\"]" not in views:
        raise SystemExit("ERROR: no se encontró bloque de contexto esperado en PaymentRequestDetailView.")
else:
    views = views.replace(old, new, 1)

views_path.write_text(views)

# ----------------------------------------------------------------------
# Update detail template.
# ----------------------------------------------------------------------

template = detail_template_path.read_text()

traceability_block = '''
<section>
  <h2>Ejecución de pago</h2>

  {% if payment_execution %}
    <table>
      <tbody>
        <tr>
          <th>Fecha de pago</th>
          <td>{{ payment_execution.paid_at }}</td>
        </tr>
        <tr>
          <th>Monto pagado</th>
          <td>{{ payment_execution.paid_amount }} {{ payment_request.currency }}</td>
        </tr>
        <tr>
          <th>Referencia bancaria</th>
          <td>{{ payment_execution.bank_reference }}</td>
        </tr>
        <tr>
          <th>Observación</th>
          <td>{{ payment_execution.note|default:"Sin observación" }}</td>
        </tr>
        <tr>
          <th>Ejecutado por</th>
          <td>{{ payment_execution.executed_by }}</td>
        </tr>
        <tr>
          <th>Registrado</th>
          <td>{{ payment_execution.created_at }}</td>
        </tr>
      </tbody>
    </table>
  {% else %}
    <p>No hay ejecución de pago registrada.</p>

    {% if can_execute_payment %}
      <p>
        <a href="{% url 'payment_requests:execute_payment' payment_request.pk %}">
          Registrar pago
        </a>
      </p>
    {% endif %}
  {% endif %}
</section>
'''

if "Ejecución de pago" not in template:
    if "{% endblock %}" in template:
        template = template.replace("{% endblock %}", traceability_block + "\n{% endblock %}", 1)
    else:
        template = template + "\n" + traceability_block + "\n"

detail_template_path.write_text(template)

# ----------------------------------------------------------------------
# Tests.
# ----------------------------------------------------------------------

tests_path.write_text('''from datetime import date
from decimal import Decimal

from django.apps import apps
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import UserRole
from apps.payment_execution.models import PaymentExecution
from apps.payment_requests.models import PaymentRequest, PaymentRequestStatus


_COUNTER = 0


def unique(prefix):
    global _COUNTER
    _COUNTER += 1
    return f"{prefix}-{_COUNTER}"


def required_data(model, **overrides):
    data = dict(overrides)

    for field in model._meta.concrete_fields:
        if field.name in data or field.primary_key or field.auto_created:
            continue
        if getattr(field, "auto_now", False) or getattr(field, "auto_now_add", False):
            continue
        if field.has_default() or field.null or field.blank:
            continue

        kind = field.get_internal_type()
        if kind in {"CharField", "TextField", "SlugField"}:
            value = unique(field.name)
            data[field.name] = value[: field.max_length] if getattr(field, "max_length", None) else value
        elif kind == "EmailField":
            data[field.name] = f"{unique('user')}@example.com"
        elif kind == "DecimalField":
            data[field.name] = Decimal("100.00")
        elif kind in {"IntegerField", "PositiveIntegerField", "PositiveSmallIntegerField"}:
            data[field.name] = 1
        elif kind == "BooleanField":
            data[field.name] = False
        elif kind == "DateField":
            data[field.name] = date.today()

    return data


def create_model(label, **overrides):
    app_label, model_name = label.split(".")
    model = apps.get_model(app_label, model_name)
    return model.objects.create(**required_data(model, **overrides))


class PaymentExecutionTraceabilityTests(TestCase):
    def setUp(self):
        self.company = create_model("organization.Company")
        self.beneficiary = create_model("beneficiaries.Beneficiary", company=self.company)
        self.cxp_user = self.create_user("cxp-trace@example.com", self.company, UserRole.CUENTAS_POR_PAGAR)
        self.finance_user = self.create_user("finanzas-trace@example.com", self.company, UserRole.FINANZAS)

    def create_user(self, email, company, role):
        user_model = get_user_model()
        try:
            return user_model.objects.create_user(
                email=email,
                password="test-pass-123",
                primary_company=company,
                role=role,
            )
        except TypeError:
            user = user_model(email=email, primary_company=company, role=role)
            user.set_password("test-pass-123")
            user.save()
            return user

    def create_request(self, status, concept):
        return PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.finance_user,
            amount=Decimal("250.00"),
            currency="VES",
            concept=concept,
            due_date=date.today(),
            status=status,
        )

    def test_detail_shows_payment_execution_traceability(self):
        payment_request = self.create_request(
            PaymentRequestStatus.APPROVED,
            "Solicitud con pago ejecutado",
        )
        PaymentExecution.objects.create(
            payment_request=payment_request,
            executed_by=self.cxp_user,
            paid_at=date.today(),
            paid_amount=Decimal("250.00"),
            bank_reference="TRACE-REF-001",
            note="Pago confirmado por banco.",
        )

        payment_request.refresh_from_db()
        self.assertEqual(payment_request.status, PaymentRequestStatus.PAID)

        self.client.force_login(self.cxp_user)
        response = self.client.get(reverse("payment_requests:detail", kwargs={"pk": payment_request.pk}))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Ejecución de pago")
        self.assertContains(response, "TRACE-REF-001")
        self.assertContains(response, "250.00")
        self.assertContains(response, "Pago confirmado por banco.")
        self.assertContains(response, self.cxp_user.email)
        self.assertNotContains(response, "Registrar pago")

    def test_detail_shows_register_payment_link_for_approved_request_and_cxp_user(self):
        payment_request = self.create_request(
            PaymentRequestStatus.APPROVED,
            "Solicitud aprobada pendiente",
        )

        self.client.force_login(self.cxp_user)
        response = self.client.get(reverse("payment_requests:detail", kwargs={"pk": payment_request.pk}))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "No hay ejecución de pago registrada.")
        self.assertContains(response, "Registrar pago")
        self.assertContains(
            response,
            reverse("payment_requests:execute_payment", kwargs={"pk": payment_request.pk}),
        )

    def test_detail_hides_register_payment_link_for_non_cxp_user(self):
        payment_request = self.create_request(
            PaymentRequestStatus.APPROVED,
            "Solicitud aprobada vista por finanzas",
        )

        self.client.force_login(self.finance_user)
        response = self.client.get(reverse("payment_requests:detail", kwargs={"pk": payment_request.pk}))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "No hay ejecución de pago registrada.")
        self.assertNotContains(response, "Registrar pago")

    def test_detail_hides_register_payment_link_when_request_is_paid(self):
        payment_request = self.create_request(
            PaymentRequestStatus.APPROVED,
            "Solicitud ya pagada",
        )
        PaymentExecution.objects.create(
            payment_request=payment_request,
            executed_by=self.cxp_user,
            paid_at=date.today(),
            paid_amount=Decimal("250.00"),
            bank_reference="TRACE-REF-PAID",
        )

        self.client.force_login(self.cxp_user)
        response = self.client.get(reverse("payment_requests:detail", kwargs={"pk": payment_request.pk}))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "TRACE-REF-PAID")
        self.assertNotContains(response, "No hay ejecución de pago registrada.")
        self.assertNotContains(response, "Registrar pago")
''')

print("OK: F1-P22 trazabilidad básica de ejecución de pago aplicada correctamente.")
PY

echo "== Validación sintáctica Python de archivos tocados =="
python3 -m py_compile \
  backend/apps/payment_requests/views.py \
  backend/apps/payment_execution/tests/test_traceability.py

echo "== Archivos modificados/creados =="
git status --short

cat <<'NEXT'

Siguiente paso obligatorio:

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

Si todo está correcto:

git add backend/apps/payment_requests/views.py \
  backend/templates/payment_requests/paymentrequest_detail.html \
  backend/apps/payment_execution/tests/test_traceability.py \
  scripts/51_f1_p22_payment_execution_traceability.sh

git commit -m "feat: show payment execution traceability"
git push -u origin feature/payment-execution-traceability

NEXT
