from decimal import Decimal

from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary, BeneficiaryType
from apps.organization.models import Company
from apps.payment_approvals.models import ApprovalActionType
from apps.payment_requests.models import Currency, PaymentRequest, PaymentRequestStatus


class PaymentRequestActionsTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.other_company = Company.objects.create(name="Otra Empresa", code="OTH")
        self.user = CustomUser.objects.create_user(
            email="solicitante.actions@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.company,
        )
        self.other_user = CustomUser.objects.create_user(
            email="otro.actions@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.other_company,
        )
        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Acciones C.A.",
            document_number="J-55555555-5",
            email="proveedor.acciones@example.com",
        )
        self.other_beneficiary = Beneficiary.objects.create(
            company=self.other_company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Externo C.A.",
            document_number="J-66666666-6",
            email="proveedor.externo@example.com",
        )
        self.payment_request = PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.user,
            amount=Decimal("500.00"),
            currency=Currency.VES,
            concept="Pago acciones básicas",
        )
        self.other_payment_request = PaymentRequest.objects.create(
            company=self.other_company,
            beneficiary=self.other_beneficiary,
            requested_by=self.other_user,
            amount=Decimal("900.00"),
            currency=Currency.VES,
            concept="Pago externo acciones",
        )

    def test_submit_requires_login(self):
        response = self.client.post(
            reverse("payment_requests:submit", args=[self.payment_request.pk])
        )

        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response.url)

    def test_authenticated_user_can_submit_draft_request(self):
        self.client.login(email="solicitante.actions@oftalmi.com", password="test-pass-123")
        response = self.client.post(
            reverse("payment_requests:submit", args=[self.payment_request.pk])
        )
        self.payment_request.refresh_from_db()

        self.assertEqual(response.status_code, 302)
        self.assertEqual(self.payment_request.status, PaymentRequestStatus.UNIT_REVIEW)
        self.assertEqual(self.payment_request.approval_steps.count(), 3)
        self.assertTrue(
            self.payment_request.approval_actions.filter(
                action=ApprovalActionType.SUBMIT,
                performed_by=self.user,
            ).exists()
        )

    def test_user_cannot_submit_other_company_request(self):
        self.client.login(email="solicitante.actions@oftalmi.com", password="test-pass-123")
        response = self.client.post(
            reverse("payment_requests:submit", args=[self.other_payment_request.pk])
        )
        self.other_payment_request.refresh_from_db()

        self.assertEqual(response.status_code, 404)
        self.assertEqual(self.other_payment_request.status, PaymentRequestStatus.DRAFT)

    def test_authenticated_user_can_cancel_draft_request(self):
        self.client.login(email="solicitante.actions@oftalmi.com", password="test-pass-123")
        response = self.client.post(
            reverse("payment_requests:cancel", args=[self.payment_request.pk])
        )
        self.payment_request.refresh_from_db()

        self.assertEqual(response.status_code, 302)
        self.assertEqual(self.payment_request.status, PaymentRequestStatus.CANCELLED)
        self.assertTrue(
            self.payment_request.approval_actions.filter(
                action=ApprovalActionType.CANCEL,
                performed_by=self.user,
            ).exists()
        )

    def test_cancel_does_not_affect_non_draft_request(self):
        self.payment_request.submit_for_approval(self.user)
        self.client.login(email="solicitante.actions@oftalmi.com", password="test-pass-123")
        response = self.client.post(
            reverse("payment_requests:cancel", args=[self.payment_request.pk])
        )
        self.payment_request.refresh_from_db()

        self.assertEqual(response.status_code, 302)
        self.assertEqual(self.payment_request.status, PaymentRequestStatus.UNIT_REVIEW)
        self.assertFalse(
            self.payment_request.approval_actions.filter(action=ApprovalActionType.CANCEL).exists()
        )

    def test_detail_shows_approval_route_after_submit(self):
        self.payment_request.submit_for_approval(self.user)
        self.client.login(email="solicitante.actions@oftalmi.com", password="test-pass-123")
        response = self.client.get(
            reverse("payment_requests:detail", args=[self.payment_request.pk])
        )

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Ruta de aprobación")
        self.assertContains(response, "Responsable de unidad")
        self.assertContains(response, "Historial de acciones")
