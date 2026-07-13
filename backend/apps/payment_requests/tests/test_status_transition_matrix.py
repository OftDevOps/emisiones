from datetime import date
from decimal import Decimal

from django.core.exceptions import ValidationError
from django.test import TestCase

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary, BeneficiaryType
from apps.organization.models import Company
from apps.payment_approvals.models import ApprovalActionType, ApprovalStepStatus, PaymentApprovalAction
from apps.payment_execution.models import PaymentExecution
from apps.payment_requests.models import Currency, PaymentRequest, PaymentRequestStatus, PaymentRequestItem


class PaymentRequestStatusTransitionMatrixTests(TestCase):

    def _add_valid_item(self, payment_request):
        item = PaymentRequestItem.objects.create(
            payment_request=payment_request,
            description="Item válido para transición",
            quantity=Decimal("1.00"),
            unit_price=Decimal("100.00"),
        )
        payment_request.recalculate_totals_from_items()
        payment_request.refresh_from_db()
        return item
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.requester = self.create_user("solicitante.transition@oftalmi.com", UserRole.SOLICITANTE)
        self.unit_manager = self.create_user("unidad.transition@oftalmi.com", UserRole.RESPONSABLE_UNIDAD)
        self.finance = self.create_user("finanzas.transition@oftalmi.com", UserRole.FINANZAS)
        self.management = self.create_user("gerencia.transition@oftalmi.com", UserRole.GERENCIA_GENERAL)
        self.accounts_payable = self.create_user("cxp.transition@oftalmi.com", UserRole.CUENTAS_POR_PAGAR)
        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Transiciones C.A.",
            document_number="J-77777777-7",
            email="proveedor.transiciones@example.com",
        )

    def create_user(self, email, role):
        return CustomUser.objects.create_user(
            email=email,
            password="test-pass-123",
            role=role,
            primary_company=self.company,
        )

    def create_payment_request(self, concept="Pago matriz de transiciones"):
        return PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.requester,
            amount=Decimal("750.00"),
            currency=Currency.VES,
            concept=concept,
            due_date=date.today(),
        )

    def test_full_happy_path_transitions_from_draft_to_paid(self):
        payment_request = self.create_payment_request()

        self.assertEqual(payment_request.status, PaymentRequestStatus.DRAFT)

        self._add_valid_item(payment_request)

        payment_request.submit_for_approval(self.requester)
        payment_request.refresh_from_db()
        self.assertEqual(payment_request.status, PaymentRequestStatus.UNIT_REVIEW)

        step1 = payment_request.approval_steps.get(sequence=1)
        step1.approve(self.unit_manager, "Unidad conforme")
        payment_request.refresh_from_db()
        self.assertEqual(payment_request.status, PaymentRequestStatus.FINANCE_REVIEW)

        step2 = payment_request.approval_steps.get(sequence=2)
        step2.approve(self.finance, "Finanzas conforme")
        payment_request.refresh_from_db()
        self.assertEqual(payment_request.status, PaymentRequestStatus.MANAGEMENT_REVIEW)

        step3 = payment_request.approval_steps.get(sequence=3)
        step3.approve(self.management, "Gerencia aprueba")
        payment_request.refresh_from_db()
        self.assertEqual(payment_request.status, PaymentRequestStatus.APPROVED)

        PaymentExecution.objects.create(
            payment_request=payment_request,
            executed_by=self.accounts_payable,
            paid_at=date.today(),
            paid_amount=Decimal("750.00"),
            bank_reference="TRANSITION-PAID-001",
        )
        payment_request.refresh_from_db()
        self.assertEqual(payment_request.status, PaymentRequestStatus.PAID)

    def test_draft_can_transition_to_cancelled_and_records_action(self):
        payment_request = self.create_payment_request("Pago cancelable")
        payment_request.status = PaymentRequestStatus.CANCELLED
        payment_request.save(update_fields=["status", "updated_at"])
        PaymentApprovalAction.objects.create(
            payment_request=payment_request,
            action=ApprovalActionType.CANCEL,
            performed_by=self.requester,
            role=self.requester.role,
            comment="Solicitud cancelada por prueba de matriz.",
        )

        self.assertEqual(payment_request.status, PaymentRequestStatus.CANCELLED)
        self.assertTrue(
            payment_request.approval_actions.filter(action=ApprovalActionType.CANCEL).exists()
        )

    def test_review_step_rejection_transitions_request_to_rejected(self):
        payment_request = self.create_payment_request("Pago rechazable")
        self._add_valid_item(payment_request)
        payment_request.submit_for_approval(self.requester)

        step1 = payment_request.approval_steps.get(sequence=1)
        step1.approve(self.unit_manager, "Unidad conforme")
        payment_request.refresh_from_db()
        self.assertEqual(payment_request.status, PaymentRequestStatus.FINANCE_REVIEW)

        step2 = payment_request.approval_steps.get(sequence=2)
        step2.reject(self.finance, "Falta soporte financiero")
        payment_request.refresh_from_db()
        step2.refresh_from_db()

        self.assertEqual(payment_request.status, PaymentRequestStatus.REJECTED)
        self.assertEqual(step2.status, ApprovalStepStatus.REJECTED)
        self.assertTrue(
            payment_request.approval_actions.filter(action=ApprovalActionType.REJECT).exists()
        )

    def test_request_cannot_be_submitted_outside_draft(self):
        payment_request = self.create_payment_request("Pago no reenviable")
        self._add_valid_item(payment_request)

        payment_request.submit_for_approval(self.requester)
        payment_request.refresh_from_db()

        with self.assertRaises(ValidationError):
            payment_request.submit_for_approval(self.requester)

    def test_payment_execution_requires_approved_request(self):
        payment_request = self.create_payment_request("Pago no aprobado")

        with self.assertRaises(ValidationError):
            PaymentExecution.objects.create(
                payment_request=payment_request,
                executed_by=self.accounts_payable,
                paid_at=date.today(),
                paid_amount=Decimal("750.00"),
                bank_reference="TRANSITION-BLOCKED-001",
            )

        payment_request.refresh_from_db()
        self.assertEqual(payment_request.status, PaymentRequestStatus.DRAFT)

    def test_submitted_state_is_not_used_by_current_transition_flow(self):
        payment_request = self.create_payment_request("Pago sin estado submitted")
        self._add_valid_item(payment_request)
        payment_request.submit_for_approval(self.requester)
        payment_request.refresh_from_db()

        self.assertNotEqual(payment_request.status, PaymentRequestStatus.SUBMITTED)
        self.assertEqual(payment_request.status, PaymentRequestStatus.UNIT_REVIEW)
