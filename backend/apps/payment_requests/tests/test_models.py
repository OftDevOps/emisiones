from decimal import Decimal

from django.core.exceptions import ValidationError
from django.test import TestCase

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary
from apps.organization.models import Company
from apps.payment_requests.models import Currency, PaymentRequest, PaymentRequestStatus


class PaymentRequestModelTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.user = CustomUser.objects.create_user(
            email="solicitante@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.company,
        )
        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            legal_name="Proveedor Demo C.A.",
            document_number="J-12345678-9",
        )

    def test_create_payment_request_defaults_to_draft(self):
        request = PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.user,
            amount=Decimal("150.25"),
            currency=Currency.VES,
            concept="Pago de factura",
        )

        self.assertEqual(request.status, PaymentRequestStatus.DRAFT)
        self.assertEqual(request.amount, Decimal("150.25"))
        self.assertEqual(request.company, self.company)
        self.assertEqual(request.beneficiary, self.beneficiary)
        self.assertEqual(request.requested_by, self.user)

    def test_amount_must_be_greater_than_zero(self):
        request = PaymentRequest(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.user,
            amount=Decimal("0.00"),
            currency=Currency.VES,
            concept="Monto inválido",
        )

        with self.assertRaises(ValidationError):
            request.full_clean()

    def test_negative_amount_is_rejected_on_save(self):
        with self.assertRaises(ValidationError):
            PaymentRequest.objects.create(
                company=self.company,
                beneficiary=self.beneficiary,
                requested_by=self.user,
                amount=Decimal("-10.00"),
                currency=Currency.USD,
                concept="Monto negativo",
            )

    def test_beneficiary_must_match_company(self):
        other_company = Company.objects.create(name="Otra Empresa", code="OTR")
        other_beneficiary = Beneficiary.objects.create(
            company=other_company,
            legal_name="Proveedor Otra Empresa",
            document_number="J-98765432-1",
        )
        request = PaymentRequest(
            company=self.company,
            beneficiary=other_beneficiary,
            requested_by=self.user,
            amount=Decimal("100.00"),
            concept="Empresa inconsistente",
        )

        with self.assertRaises(ValidationError):
            request.full_clean()

    def test_string_representation_contains_business_context(self):
        request = PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.user,
            amount=Decimal("250.00"),
            currency=Currency.USD,
            concept="Servicio técnico",
        )

        self.assertIn("Laboratorios Oftalmi", str(request))
        self.assertIn("Proveedor Demo", str(request))
        self.assertIn("250.00", str(request))
        self.assertIn("USD", str(request))
