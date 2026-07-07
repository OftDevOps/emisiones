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


class PendingApprovalStepsViewTests(TestCase):
    def setUp(self):
        self.company = create_model("organization.Company")
        self.other_company = create_model("organization.Company")
        self.beneficiary = create_model("beneficiaries.Beneficiary", company=self.company)
        self.other_beneficiary = create_model(
            "beneficiaries.Beneficiary",
            company=self.other_company,
        )
        self.finance_user = self.create_user(
            "finanzas@example.com",
            self.company,
            UserRole.FINANZAS,
        )
        self.management_user = self.create_user(
            "gerencia@example.com",
            self.company,
            UserRole.GERENCIA_GENERAL,
        )
        self.other_company_user = self.create_user(
            "otra-finanzas@example.com",
            self.other_company,
            UserRole.FINANZAS,
        )
        self.url = reverse("payment_approvals:pending")

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

    def create_payment_request(self, company, beneficiary, user, concept):
        return PaymentRequest.objects.create(
            company=company,
            beneficiary=beneficiary,
            requested_by=user,
            amount=Decimal("150.00"),
            currency="VES",
            concept=concept,
            status=PaymentRequestStatus.FINANCE_REVIEW,
        )

    def create_step(self, payment_request, role, status=ApprovalStepStatus.PENDING):
        return PaymentApprovalStep.objects.create(
            payment_request=payment_request,
            sequence=1,
            required_role=role,
            status=status,
        )

    def test_pending_workbench_requires_login(self):
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 302)

    def test_pending_workbench_lists_pending_steps_for_user_role_and_company(self):
        self.client.force_login(self.finance_user)
        payment_request = self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            "Pendiente visible finanzas",
        )
        expected_step = self.create_step(payment_request, UserRole.FINANZAS)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, "payment_approvals/pending_approval_steps.html")
        self.assertEqual(list(response.context["pending_steps"]), [expected_step])
        self.assertContains(response, "Pendiente visible finanzas")

    def test_pending_workbench_excludes_other_company_steps(self):
        self.client.force_login(self.finance_user)
        visible_request = self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            "Pendiente empresa propia",
        )
        expected_step = self.create_step(visible_request, UserRole.FINANZAS)

        other_request = self.create_payment_request(
            self.other_company,
            self.other_beneficiary,
            self.other_company_user,
            "Pendiente otra empresa",
        )
        self.create_step(other_request, UserRole.FINANZAS)

        response = self.client.get(self.url)

        self.assertEqual(list(response.context["pending_steps"]), [expected_step])
        self.assertContains(response, "Pendiente empresa propia")
        self.assertNotContains(response, "Pendiente otra empresa")

    def test_pending_workbench_excludes_other_role_steps(self):
        self.client.force_login(self.finance_user)
        visible_request = self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            "Pendiente rol finanzas",
        )
        expected_step = self.create_step(visible_request, UserRole.FINANZAS)

        management_request = self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            "Pendiente gerencia",
        )
        self.create_step(management_request, UserRole.GERENCIA_GENERAL)

        response = self.client.get(self.url)

        self.assertEqual(list(response.context["pending_steps"]), [expected_step])
        self.assertContains(response, "Pendiente rol finanzas")
        self.assertNotContains(response, "Pendiente gerencia")

    def test_pending_workbench_excludes_non_pending_steps(self):
        self.client.force_login(self.finance_user)
        pending_request = self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            "Pendiente real",
        )
        expected_step = self.create_step(pending_request, UserRole.FINANZAS)

        approved_request = self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            "Ya aprobado",
        )
        self.create_step(
            approved_request,
            UserRole.FINANZAS,
            status=ApprovalStepStatus.APPROVED,
        )

        response = self.client.get(self.url)

        self.assertEqual(list(response.context["pending_steps"]), [expected_step])
        self.assertContains(response, "Pendiente real")
        self.assertNotContains(response, "Ya aprobado")

    def test_user_without_company_gets_empty_workbench(self):
        user_model = get_user_model()
        try:
            no_company_user = user_model.objects.create_user(
                email="sin-empresa@example.com",
                password="test-pass-123",
                role=UserRole.FINANZAS,
            )
        except TypeError:
            no_company_user = user_model(
                email="sin-empresa@example.com",
                role=UserRole.FINANZAS,
            )
            no_company_user.set_password("test-pass-123")
            no_company_user.save()

        payment_request = self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            "No visible sin empresa",
        )
        self.create_step(payment_request, UserRole.FINANZAS)

        self.client.force_login(no_company_user)
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(list(response.context["pending_steps"]), [])
        self.assertContains(response, "No tienes emisiones pendientes por aprobar.")
        self.assertNotContains(response, "No visible sin empresa")
