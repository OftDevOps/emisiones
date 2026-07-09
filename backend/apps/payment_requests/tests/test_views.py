from decimal import Decimal

from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary, BeneficiaryType
from apps.organization.models import Company
from apps.payment_requests.models import Currency, PaymentRequest, PaymentRequestStatus


class PaymentRequestViewsTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.other_company = Company.objects.create(name="Otra Empresa", code="OTH")
        self.user = CustomUser.objects.create_user(
            email="solicitante.views@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.company,
        )
        self.other_user = CustomUser.objects.create_user(
            email="otro.views@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.other_company,
        )
        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Vistas C.A.",
            document_number="J-33333333-3",
            email="proveedor.views@example.com",
        )
        self.other_beneficiary = Beneficiary.objects.create(
            company=self.other_company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Otra Empresa C.A.",
            document_number="J-44444444-4",
            email="proveedor.otra@example.com",
        )
        self.payment_request = PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.user,
            amount=Decimal("250.00"),
            currency=Currency.VES,
            concept="Pago desde vistas",
        )
        self.other_payment_request = PaymentRequest.objects.create(
            company=self.other_company,
            beneficiary=self.other_beneficiary,
            requested_by=self.other_user,
            amount=Decimal("300.00"),
            currency=Currency.VES,
            concept="Pago de otra empresa",
        )

    def test_list_requires_login(self):
        response = self.client.get(reverse("payment_requests:list"))
        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response["Location"])

    def test_create_requires_login(self):
        response = self.client.get(reverse("payment_requests:create"))
        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response["Location"])

    def test_detail_requires_login(self):
        response = self.client.get(reverse("payment_requests:detail", args=[self.payment_request.pk]))
        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response["Location"])

    def test_authenticated_user_can_list_own_company_requests(self):
        self.client.force_login(self.user)
        response = self.client.get(reverse("payment_requests:list"))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Pago desde vistas")
        self.assertNotContains(response, "Pago de otra empresa")

    def test_authenticated_user_can_view_own_company_request_detail(self):
        self.client.force_login(self.user)
        response = self.client.get(reverse("payment_requests:detail", args=[self.payment_request.pk]))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Pago desde vistas")

    def test_authenticated_user_cannot_view_other_company_request_detail(self):
        self.client.force_login(self.user)
        response = self.client.get(reverse("payment_requests:detail", args=[self.other_payment_request.pk]))

        self.assertEqual(response.status_code, 404)

    def test_authenticated_user_can_create_payment_request(self):
        self.client.force_login(self.user)
        response = self.client.post(
            reverse("payment_requests:create"),
            data={
                "company": self.company.pk,
                "beneficiary": self.beneficiary.pk,
                "amount": "500.00",
                "currency": Currency.VES,
                "concept": "Nueva solicitud desde formulario",
                "description": "Soporte pendiente",
                "due_date": "2026-12-31",
            "items-TOTAL_FORMS": "1",
            "items-INITIAL_FORMS": "0",
            "items-MIN_NUM_FORMS": "1",
            "items-MAX_NUM_FORMS": "1000",
            "items-0-description": "Item de prueba",
            "items-0-quantity": "1",
            "items-0-unit_price": "100.00",
            "items-0-tax_rate": "",
            "items-0-tax_percentage_snapshot": "0.00",
            },
        )

        self.assertEqual(response.status_code, 302)
        created = PaymentRequest.objects.get(concept="Nueva solicitud desde formulario")
        self.assertEqual(created.requested_by, self.user)
        self.assertEqual(created.status, PaymentRequestStatus.DRAFT)
        self.assertEqual(created.company, self.company)

    def test_create_rejects_beneficiary_from_another_company(self):
        self.client.force_login(self.user)
        response = self.client.post(
            reverse("payment_requests:create"),
            data={
                "company": self.company.pk,
                "beneficiary": self.other_beneficiary.pk,
                "amount": "500.00",
                "currency": Currency.VES,
                "concept": "Solicitud cruzada inválida",
                "description": "Debe fallar",
                "due_date": "2026-12-31",
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.status_code, 200)
        self.assertFalse(
            PaymentRequest.objects.filter(
                beneficiary=self.other_beneficiary,
                concept="Pago beneficiario externo",
            ).exists()
        )
        self.assertFalse(PaymentRequest.objects.filter(concept="Solicitud cruzada inválida").exists())
