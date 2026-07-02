from decimal import Decimal

from django.core.exceptions import ObjectDoesNotExist
from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary, BeneficiaryType
from apps.organization.models import Company
from apps.payment_approvals.models import ApprovalActionType, ApprovalStepStatus, PaymentApprovalAction
from apps.payment_requests.models import Currency, PaymentRequest, PaymentRequestStatus


class ApprovalStepActionViewTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.other_company = Company.objects.create(name="Otra Empresa", code="OTH")

        self.requester = CustomUser.objects.create_user(
            email="solicitante.aprobacion@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.company,
        )

        self.unit_approver = CustomUser.objects.create_user(
            email="responsable.unidad@oftalmi.com",
            password="test-pass-123",
            role=UserRole.RESPONSABLE_UNIDAD,
            primary_company=self.company,
        )

        self.finance_user = CustomUser.objects.create_user(
            email="finanzas.aprobacion@oftalmi.com",
            password="test-pass-123",
            role=UserRole.FINANZAS,
            primary_company=self.company,
        )

        self.other_company_approver = CustomUser.objects.create_user(
            email="responsable.otra@oftalmi.com",
            password="test-pass-123",
            role=UserRole.RESPONSABLE_UNIDAD,
            primary_company=self.other_company,
        )

        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Aprobación C.A.",
            document_number="J-33333333-3",
            email="proveedor.aprobacion@example.com",
        )

        self.payment_request = PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.requester,
            amount=Decimal("250.00"),
            currency=Currency.VES,
            concept="Pago para aprobar desde UI",
        )
        self.payment_request.submit_for_approval(self.requester)
        self.first_step = self.payment_request.approval_steps.order_by("sequence").first()

    def action_url(self, step=None):
        step = step or self.first_step
        return reverse("payment_approvals:step_action", args=[step.pk])

    def test_login_required_to_approve_step(self):
        response = self.client.post(
            self.action_url(),
            {"action": ApprovalActionType.APPROVE, "comment": "Aprobado."},
        )

        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response.url)

    def test_required_role_can_approve_pending_step(self):
        self.client.force_login(self.unit_approver)

        response = self.client.post(
            self.action_url(),
            {"action": ApprovalActionType.APPROVE, "comment": "Aprobado por responsable."},
        )

        self.assertEqual(response.status_code, 302)

        self.first_step.refresh_from_db()
        self.assertEqual(self.first_step.status, ApprovalStepStatus.APPROVED)
        self.assertEqual(self.first_step.acted_by, self.unit_approver)
        self.assertEqual(self.first_step.comment, "Aprobado por responsable.")

        self.assertTrue(
            PaymentApprovalAction.objects.filter(
                payment_request=self.payment_request,
                action=ApprovalActionType.APPROVE,
                performed_by=self.unit_approver,
            ).exists()
        )

    def test_reject_requires_comment(self):
        self.client.force_login(self.unit_approver)

        response = self.client.post(
            self.action_url(),
            {"action": ApprovalActionType.REJECT, "comment": ""},
        )

        self.assertEqual(response.status_code, 302)

        self.first_step.refresh_from_db()
        self.payment_request.refresh_from_db()

        self.assertEqual(self.first_step.status, ApprovalStepStatus.PENDING)
        self.assertNotEqual(self.payment_request.status, PaymentRequestStatus.REJECTED)

    def test_required_role_can_reject_pending_step_with_comment(self):
        self.client.force_login(self.unit_approver)

        response = self.client.post(
            self.action_url(),
            {"action": ApprovalActionType.REJECT, "comment": "Falta soporte."},
        )

        self.assertEqual(response.status_code, 302)

        self.first_step.refresh_from_db()
        self.payment_request.refresh_from_db()

        self.assertEqual(self.first_step.status, ApprovalStepStatus.REJECTED)
        self.assertEqual(self.first_step.acted_by, self.unit_approver)
        self.assertEqual(self.first_step.comment, "Falta soporte.")
        self.assertEqual(self.payment_request.status, PaymentRequestStatus.REJECTED)

    def test_wrong_role_cannot_approve_step(self):
        self.client.force_login(self.finance_user)

        response = self.client.post(
            self.action_url(),
            {"action": ApprovalActionType.APPROVE, "comment": "Intento no autorizado."},
        )

        self.assertEqual(response.status_code, 403)

        self.first_step.refresh_from_db()
        self.assertEqual(self.first_step.status, ApprovalStepStatus.PENDING)

    def test_user_from_other_company_cannot_act_on_step(self):
        self.client.force_login(self.other_company_approver)

        response = self.client.post(
            self.action_url(),
            {"action": ApprovalActionType.APPROVE, "comment": "Intento externo."},
        )

        self.assertEqual(response.status_code, 403)

        self.first_step.refresh_from_db()
        self.assertEqual(self.first_step.status, ApprovalStepStatus.PENDING)

    def test_non_existing_step_returns_404(self):
        self.client.force_login(self.unit_approver)

        with self.assertRaises(ObjectDoesNotExist):
            self.payment_request.approval_steps.get(pk=999999)

        response = self.client.post(
            reverse("payment_approvals:step_action", args=[999999]),
            {"action": ApprovalActionType.APPROVE, "comment": "No existe."},
        )

        self.assertEqual(response.status_code, 404)
