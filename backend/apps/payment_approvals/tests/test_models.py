from decimal import Decimal

from django.core.exceptions import ValidationError
from django.test import TestCase

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary, BeneficiaryType
from apps.organization.models import Company
from apps.payment_approvals.models import ApprovalActionType, ApprovalStepStatus, PaymentApprovalAction
from apps.payment_requests.models import Currency, PaymentRequest, PaymentRequestStatus


class PaymentApprovalRouteTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.requester = CustomUser.objects.create_user(
            email="solicitante.aprobacion@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.company,
        )
        self.unit_manager = CustomUser.objects.create_user(
            email="unidad.aprobacion@oftalmi.com",
            password="test-pass-123",
            role=UserRole.RESPONSABLE_UNIDAD,
            primary_company=self.company,
        )
        self.finance = CustomUser.objects.create_user(
            email="finanzas.aprobacion@oftalmi.com",
            password="test-pass-123",
            role=UserRole.FINANZAS,
            primary_company=self.company,
        )
        self.management = CustomUser.objects.create_user(
            email="gerencia.aprobacion@oftalmi.com",
            password="test-pass-123",
            role=UserRole.GERENCIA_GENERAL,
            primary_company=self.company,
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
            concept="Pago para aprobación",
        )

    def test_submit_creates_default_approval_route(self):
        self.payment_request.submit_for_approval(self.requester)
        self.payment_request.refresh_from_db()

        self.assertEqual(self.payment_request.status, PaymentRequestStatus.UNIT_REVIEW)
        self.assertEqual(self.payment_request.approval_steps.count(), 3)
        self.assertEqual(self.payment_request.approval_actions.count(), 1)
        self.assertEqual(self.payment_request.approval_actions.first().action, ApprovalActionType.SUBMIT)

    def test_submit_only_from_draft(self):
        self.payment_request.status = PaymentRequestStatus.CANCELLED
        self.payment_request.save(update_fields=["status", "updated_at"])

        with self.assertRaises(ValidationError):
            self.payment_request.submit_for_approval(self.requester)

    def test_approval_advances_status_by_role(self):
        self.payment_request.submit_for_approval(self.requester)

        step1 = self.payment_request.approval_steps.get(sequence=1)
        step1.approve(self.unit_manager, "Unidad conforme")
        self.payment_request.refresh_from_db()
        self.assertEqual(self.payment_request.status, PaymentRequestStatus.FINANCE_REVIEW)

        step2 = self.payment_request.approval_steps.get(sequence=2)
        step2.approve(self.finance, "Finanzas conforme")
        self.payment_request.refresh_from_db()
        self.assertEqual(self.payment_request.status, PaymentRequestStatus.MANAGEMENT_REVIEW)

        step3 = self.payment_request.approval_steps.get(sequence=3)
        step3.approve(self.management, "Gerencia aprueba")
        self.payment_request.refresh_from_db()
        self.assertEqual(self.payment_request.status, PaymentRequestStatus.APPROVED)

    def test_wrong_role_cannot_approve_step(self):
        self.payment_request.submit_for_approval(self.requester)
        step1 = self.payment_request.approval_steps.get(sequence=1)

        with self.assertRaises(ValidationError):
            step1.approve(self.finance, "Intento inválido")

    def test_reject_requires_comment(self):
        self.payment_request.submit_for_approval(self.requester)
        step1 = self.payment_request.approval_steps.get(sequence=1)

        with self.assertRaises(ValidationError):
            step1.reject(self.unit_manager, "")

    def test_rejection_marks_request_as_rejected(self):
        self.payment_request.submit_for_approval(self.requester)
        step1 = self.payment_request.approval_steps.get(sequence=1)
        step1.reject(self.unit_manager, "Falta soporte")
        self.payment_request.refresh_from_db()

        self.assertEqual(self.payment_request.status, PaymentRequestStatus.REJECTED)
        self.assertEqual(step1.status, ApprovalStepStatus.REJECTED)
        self.assertEqual(
            PaymentApprovalAction.objects.filter(
                payment_request=self.payment_request,
                action=ApprovalActionType.REJECT,
            ).count(),
            1,
        )
