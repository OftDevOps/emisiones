from datetime import date
from decimal import Decimal

from django.apps import apps
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from apps.accounts.models import UserRole
from apps.payment_approvals.models import ApprovalStepStatus, PaymentApprovalStep
from apps.payment_requests.models import PaymentRequest, PaymentRequestStatus


_COUNTER = 0


def next_value(prefix):
    global _COUNTER
    _COUNTER += 1
    return f"{prefix}-{_COUNTER}"


def build_required_data(model, **overrides):
    data = dict(overrides)

    for field in model._meta.concrete_fields:
        if field.name in data:
            continue
        if field.primary_key or field.auto_created:
            continue
        if getattr(field, "auto_now", False) or getattr(field, "auto_now_add", False):
            continue
        if field.has_default() or field.null or field.blank:
            continue

        internal_type = field.get_internal_type()

        if internal_type in {"CharField", "TextField", "SlugField"}:
            max_length = getattr(field, "max_length", None)
            value = next_value(field.name)
            data[field.name] = value[:max_length] if max_length else value
        elif internal_type == "EmailField":
            data[field.name] = f"{next_value('user')}@example.com"
        elif internal_type == "DecimalField":
            data[field.name] = Decimal("100.00")
        elif internal_type in {"IntegerField", "PositiveIntegerField", "PositiveSmallIntegerField"}:
            data[field.name] = 1
        elif internal_type == "BooleanField":
            data[field.name] = False
        elif internal_type == "DateField":
            data[field.name] = date.today()
        elif internal_type == "DateTimeField":
            data[field.name] = timezone.now()

    return data


def create_model(model_label, **overrides):
    app_label, model_name = model_label.split(".")
    model = apps.get_model(app_label, model_name)
    return model.objects.create(**build_required_data(model, **overrides))


class PaymentRequestDashboardViewTests(TestCase):
    def setUp(self):
        self.company = create_model("organization.Company")
        self.other_company = create_model("organization.Company")
        self.beneficiary = create_model("beneficiaries.Beneficiary", company=self.company)
        self.other_beneficiary = create_model(
            "beneficiaries.Beneficiary",
            company=self.other_company,
        )
        self.user = self.create_user(
            "finanzas@example.com",
            self.company,
            UserRole.FINANZAS,
        )
        self.other_user = self.create_user(
            "otra@example.com",
            self.other_company,
            UserRole.FINANZAS,
        )
        self.url = reverse("payment_requests:dashboard")

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
            user = user_model(
                email=email,
                primary_company=company,
                role=role,
            )
            user.set_password("test-pass-123")
            user.save()
            return user

    def create_payment_request(self, company, beneficiary, user, status, concept):
        return PaymentRequest.objects.create(
            company=company,
            beneficiary=beneficiary,
            requested_by=user,
            amount=Decimal("150.00"),
            currency="VES",
            concept=concept,
            status=status,
        )

    def test_dashboard_requires_login(self):
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 302)

    def test_authenticated_user_can_access_dashboard(self):
        self.client.force_login(self.user)
        self.create_payment_request(
            self.company,
            self.beneficiary,
            self.user,
            PaymentRequestStatus.DRAFT,
            "Solicitud visible",
        )

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(
            response,
            "payment_requests/paymentrequest_dashboard.html",
        )

    def test_dashboard_counts_only_user_company_requests(self):
        self.client.force_login(self.user)
        self.create_payment_request(
            self.company,
            self.beneficiary,
            self.user,
            PaymentRequestStatus.DRAFT,
            "Borrador empresa propia",
        )
        self.create_payment_request(
            self.company,
            self.beneficiary,
            self.user,
            PaymentRequestStatus.APPROVED,
            "Aprobada empresa propia",
        )
        self.create_payment_request(
            self.other_company,
            self.other_beneficiary,
            self.other_user,
            PaymentRequestStatus.REJECTED,
            "Solicitud otra empresa",
        )

        response = self.client.get(self.url)

        self.assertEqual(response.context["total_requests"], 2)
        status_totals = {
            card["code"]: card["total"]
            for card in response.context["status_cards"]
        }
        self.assertEqual(status_totals[PaymentRequestStatus.DRAFT], 1)
        self.assertEqual(status_totals[PaymentRequestStatus.APPROVED], 1)
        self.assertEqual(status_totals[PaymentRequestStatus.REJECTED], 0)

    def test_dashboard_shows_latest_requests_scoped_to_user_company(self):
        self.client.force_login(self.user)
        self.create_payment_request(
            self.company,
            self.beneficiary,
            self.user,
            PaymentRequestStatus.DRAFT,
            "Visible en dashboard",
        )
        self.create_payment_request(
            self.other_company,
            self.other_beneficiary,
            self.other_user,
            PaymentRequestStatus.DRAFT,
            "No visible en dashboard",
        )

        response = self.client.get(self.url)

        self.assertContains(response, "Visible en dashboard")
        self.assertNotContains(response, "No visible en dashboard")

    def test_dashboard_shows_pending_approval_steps_for_user_role(self):
        self.client.force_login(self.user)
        payment_request = self.create_payment_request(
            self.company,
            self.beneficiary,
            self.user,
            PaymentRequestStatus.FINANCE_REVIEW,
            "Pendiente finanzas",
        )
        expected_step = PaymentApprovalStep.objects.create(
            payment_request=payment_request,
            sequence=1,
            required_role=UserRole.FINANZAS,
            status=ApprovalStepStatus.PENDING,
        )

        other_request = self.create_payment_request(
            self.other_company,
            self.other_beneficiary,
            self.other_user,
            PaymentRequestStatus.FINANCE_REVIEW,
            "Pendiente otra empresa",
        )
        PaymentApprovalStep.objects.create(
            payment_request=other_request,
            sequence=1,
            required_role=UserRole.FINANZAS,
            status=ApprovalStepStatus.PENDING,
        )

        response = self.client.get(self.url)

        pending_steps = list(response.context["pending_approval_steps"])
        self.assertEqual(pending_steps, [expected_step])
        self.assertContains(response, "Pendiente finanzas")
        self.assertNotContains(response, "Pendiente otra empresa")
