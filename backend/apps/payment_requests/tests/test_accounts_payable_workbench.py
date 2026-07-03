from datetime import date
from decimal import Decimal

from django.apps import apps
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import UserRole
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


class AccountsPayablePendingViewTests(TestCase):
    def setUp(self):
        self.company = create_model("organization.Company")
        self.other_company = create_model("organization.Company")
        self.beneficiary = create_model("beneficiaries.Beneficiary", company=self.company)
        self.other_beneficiary = create_model("beneficiaries.Beneficiary", company=self.other_company)
        self.cxp_user = self.create_user("cxp@example.com", self.company, UserRole.CUENTAS_POR_PAGAR)
        self.finance_user = self.create_user("finanzas@example.com", self.company, UserRole.FINANZAS)
        self.other_cxp_user = self.create_user("otra-cxp@example.com", self.other_company, UserRole.CUENTAS_POR_PAGAR)
        self.url = reverse("payment_requests:accounts_payable")

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

    def create_request(self, company, beneficiary, user, status, concept):
        return PaymentRequest.objects.create(
            company=company,
            beneficiary=beneficiary,
            requested_by=user,
            amount=Decimal("150.00"),
            currency="VES",
            concept=concept,
            due_date=date.today(),
            status=status,
        )

    def test_requires_login(self):
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 302)

    def test_accounts_payable_user_can_access(self):
        self.client.force_login(self.cxp_user)
        payment_request = self.create_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            PaymentRequestStatus.APPROVED,
            "Pago aprobado visible",
        )

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(list(response.context["payment_requests"]), [payment_request])
        self.assertContains(response, "Pago aprobado visible")

    def test_non_accounts_payable_user_gets_403(self):
        self.client.force_login(self.finance_user)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 403)

    def test_only_lists_approved_requests(self):
        self.client.force_login(self.cxp_user)
        approved_request = self.create_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            PaymentRequestStatus.APPROVED,
            "Pago aprobado",
        )
        self.create_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            PaymentRequestStatus.FINANCE_REVIEW,
            "Pago no aprobado",
        )

        response = self.client.get(self.url)

        self.assertEqual(list(response.context["payment_requests"]), [approved_request])
        self.assertContains(response, "Pago aprobado")
        self.assertNotContains(response, "Pago no aprobado")

    def test_scopes_by_company(self):
        self.client.force_login(self.cxp_user)
        own_request = self.create_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            PaymentRequestStatus.APPROVED,
            "Pago empresa propia",
        )
        self.create_request(
            self.other_company,
            self.other_beneficiary,
            self.other_cxp_user,
            PaymentRequestStatus.APPROVED,
            "Pago otra empresa",
        )

        response = self.client.get(self.url)

        self.assertEqual(list(response.context["payment_requests"]), [own_request])
        self.assertContains(response, "Pago empresa propia")
        self.assertNotContains(response, "Pago otra empresa")
