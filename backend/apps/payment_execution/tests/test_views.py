from datetime import date
from decimal import Decimal

from django.apps import apps
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import UserRole
from apps.payment_execution.models import PaymentExecution
from apps.payment_requests.models import PaymentRequest, PaymentRequestStatus


_counter = 0


def unique(prefix):
    global _counter
    _counter += 1
    return f"{prefix}-{_counter}"


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


class PaymentExecutionCreateViewTests(TestCase):
    def setUp(self):
        self.company = create_model("organization.Company")
        self.other_company = create_model("organization.Company")
        self.beneficiary = create_model("beneficiaries.Beneficiary", company=self.company)
        self.other_beneficiary = create_model("beneficiaries.Beneficiary", company=self.other_company)
        self.cxp_user = self.create_user("cxp@example.com", self.company, UserRole.CUENTAS_POR_PAGAR)
        self.finance_user = self.create_user("finanzas@example.com", self.company, UserRole.FINANZAS)
        self.other_cxp_user = self.create_user("otra-cxp@example.com", self.other_company, UserRole.CUENTAS_POR_PAGAR)
        self.payment_request = self.create_request(self.company, self.beneficiary, self.finance_user, PaymentRequestStatus.APPROVED, "Pago listo para ejecutar")
        self.url = reverse("payment_requests:execute_payment", kwargs={"pk": self.payment_request.pk})

    def create_user(self, email, company, role):
        user_model = get_user_model()
        try:
            return user_model.objects.create_user(email=email, password="test-pass-123", primary_company=company, role=role)
        except TypeError:
            user = user_model(email=email, primary_company=company, role=role)
            user.set_password("test-pass-123")
            user.save()
            return user

    def create_request(self, company, beneficiary, user, status, concept):
        return PaymentRequest.objects.create(company=company, beneficiary=beneficiary, requested_by=user, amount=Decimal("150.00"), currency="VES", concept=concept, due_date=date.today(), status=status)

    def post_data(self):
        return {"paid_at": date.today().isoformat(), "paid_amount": "150.00", "bank_reference": "REF-12345", "note": "Pago ejecutado desde prueba."}

    def test_requires_login(self):
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 302)

    def test_accounts_payable_user_can_register_payment_execution(self):
        self.client.force_login(self.cxp_user)
        response = self.client.post(self.url, self.post_data())
        self.assertEqual(response.status_code, 302)
        execution = PaymentExecution.objects.get(payment_request=self.payment_request)
        self.assertEqual(execution.executed_by, self.cxp_user)
        self.payment_request.refresh_from_db()
        self.assertEqual(self.payment_request.status, PaymentRequestStatus.PAID)

    def test_non_accounts_payable_user_cannot_register_payment_execution(self):
        self.client.force_login(self.finance_user)
        response = self.client.post(self.url, self.post_data())
        self.assertEqual(response.status_code, 403)
        self.assertFalse(PaymentExecution.objects.filter(payment_request=self.payment_request).exists())

    def test_cannot_execute_request_from_other_company(self):
        other_request = self.create_request(self.other_company, self.other_beneficiary, self.other_cxp_user, PaymentRequestStatus.APPROVED, "Pago otra empresa")
        url = reverse("payment_requests:execute_payment", kwargs={"pk": other_request.pk})
        self.client.force_login(self.cxp_user)
        response = self.client.post(url, self.post_data())
        self.assertEqual(response.status_code, 404)

    def test_cannot_execute_non_approved_request(self):
        draft_request = self.create_request(self.company, self.beneficiary, self.finance_user, PaymentRequestStatus.DRAFT, "Borrador no ejecutable")
        url = reverse("payment_requests:execute_payment", kwargs={"pk": draft_request.pk})
        self.client.force_login(self.cxp_user)
        response = self.client.post(url, self.post_data())
        self.assertEqual(response.status_code, 404)

    def test_accounts_payable_workbench_excludes_executed_requests(self):
        PaymentExecution.objects.create(payment_request=self.payment_request, executed_by=self.cxp_user, paid_at=date.today(), paid_amount=Decimal("150.00"), bank_reference="REF-EXECUTED")
        visible = self.create_request(self.company, self.beneficiary, self.finance_user, PaymentRequestStatus.APPROVED, "Pago todavia pendiente")
        self.client.force_login(self.cxp_user)
        response = self.client.get(reverse("payment_requests:accounts_payable"))
        self.assertEqual(list(response.context["payment_requests"]), [visible])
        self.assertContains(response, "Pago todavia pendiente")
        self.assertNotContains(response, "Pago listo para ejecutar")
