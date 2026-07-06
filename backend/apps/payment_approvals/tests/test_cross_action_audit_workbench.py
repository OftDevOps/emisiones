from decimal import Decimal

from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary, BeneficiaryType
from apps.organization.models import Company
from apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction
from apps.payment_requests.models import Currency, PaymentRequest, PaymentRequestStatus


class CrossActionAuditWorkbenchTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.other_company = Company.objects.create(name="Otra Empresa", code="OTH")

        self.cxp_user = CustomUser.objects.create_user(
            email="auditor.audit@oftalmi.com",
            password="test-pass-123",
            role=UserRole.AUDITOR,
            primary_company=self.company,
        )
        self.other_user = CustomUser.objects.create_user(
            email="auditor.audit.otra@oftalmi.com",
            password="test-pass-123",
            role=UserRole.AUDITOR,
            primary_company=self.other_company,
        )
        self.superuser = CustomUser.objects.create_superuser(
            email="admin.audit@oftalmi.com",
            password="test-pass-123",
        )

        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Auditoría C.A.",
            document_number="J-44444444-4",
            email="proveedor.audit@example.com",
        )
        self.other_beneficiary = Beneficiary.objects.create(
            company=self.other_company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Otra Empresa C.A.",
            document_number="J-55555555-5",
            email="proveedor.otra.audit@example.com",
        )

        self.payment_request = PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.cxp_user,
            amount=Decimal("150.00"),
            currency=Currency.VES,
            concept="Pago auditado",
            status=PaymentRequestStatus.APPROVED,
        )
        self.other_payment_request = PaymentRequest.objects.create(
            company=self.other_company,
            beneficiary=self.other_beneficiary,
            requested_by=self.other_user,
            amount=Decimal("250.00"),
            currency=Currency.VES,
            concept="Pago auditado otra empresa",
            status=PaymentRequestStatus.APPROVED,
        )

        self.company_action = PaymentApprovalAction.objects.create(
            payment_request=self.payment_request,
            action=ApprovalActionType.PAYMENT_EXECUTED,
            performed_by=self.cxp_user,
            role=UserRole.AUDITOR,
            comment="Pago ejecutado REF-AUDIT-01",
        )
        self.other_company_action = PaymentApprovalAction.objects.create(
            payment_request=self.other_payment_request,
            action=ApprovalActionType.REJECT,
            performed_by=self.other_user,
            role=UserRole.AUDITOR,
            comment="Rechazo otra empresa",
        )

    def url(self):
        return reverse("payment_approvals:audit")

    def test_login_required(self):
        response = self.client.get(self.url())

        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response.url)

    def test_user_sees_only_primary_company_actions(self):
        self.client.force_login(self.cxp_user)

        response = self.client.get(self.url())

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Auditoría de acciones críticas")
        self.assertContains(response, "Pago ejecutado REF-AUDIT-01")
        self.assertNotContains(response, "Rechazo otra empresa")

    def test_superuser_sees_all_company_actions(self):
        self.client.force_login(self.superuser)

        response = self.client.get(self.url())

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Pago ejecutado REF-AUDIT-01")
        self.assertContains(response, "Rechazo otra empresa")

    def test_filter_by_action(self):
        self.client.force_login(self.superuser)

        response = self.client.get(self.url(), {"action": ApprovalActionType.REJECT})

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Rechazo otra empresa")
        self.assertNotContains(response, "Pago ejecutado REF-AUDIT-01")

    def test_filter_by_company(self):
        self.client.force_login(self.superuser)

        response = self.client.get(self.url(), {"company": str(self.company.pk)})

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Pago ejecutado REF-AUDIT-01")
        self.assertNotContains(response, "Rechazo otra empresa")
