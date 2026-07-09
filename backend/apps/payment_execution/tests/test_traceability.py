from datetime import date
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
        self.assertNotContains(response, "Marcar emisión como pagada")

    def test_detail_shows_mark_paid_link_for_approved_request_and_cxp_user(self):
        payment_request = self.create_request(
            PaymentRequestStatus.APPROVED,
            "Solicitud aprobada pendiente",
        )

        self.client.force_login(self.cxp_user)
        response = self.client.get(reverse("payment_requests:detail", kwargs={"pk": payment_request.pk}))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "No hay ejecución de pago registrada.")
        self.assertContains(response, "Marcar emisión como pagada")
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
        self.assertNotContains(response, "Marcar emisión como pagada")

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
        self.assertNotContains(response, "Marcar emisión como pagada")
