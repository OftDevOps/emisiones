from datetime import date
from decimal import Decimal

from django.core.exceptions import ValidationError
from django.test import TestCase

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary, BeneficiaryType
from apps.organization.models import Company
from apps.payment_requests.validators import assert_payment_request_ready_for_approval
from apps.payment_requests.models import Currency, PaymentRequest, PaymentRequestItem, TaxRate


class PaymentRequestItemTaxModelTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.user = CustomUser.objects.create_user(
            email="solicitante.items@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.company,
        )
        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Items C.A.",
            document_number="J-55555555-5",
        )
        self.payment_request = PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.user,
            amount=Decimal("1.00"),
            currency=Currency.VES,
            concept="Emisión con ítems",
            due_date=date.today(),
        )
        self.tax_rate = TaxRate.objects.create(
            name="IVA general",
            percentage=Decimal("16.00"),
            valid_from=date.today(),
        )

    def test_tax_rate_rejects_invalid_percentage(self):
        tax_rate = TaxRate(name="IVA inválido", percentage=Decimal("101.00"), valid_from=date.today())

        with self.assertRaises(ValidationError):
            tax_rate.full_clean()

    def test_item_calculates_snapshot_subtotal_tax_and_total(self):
        item = PaymentRequestItem.objects.create(
            payment_request=self.payment_request,
            description="Lente intraocular",
            quantity=Decimal("2.000"),
            unit_price=Decimal("100.00"),
            tax_rate=self.tax_rate,
        )

        self.assertEqual(item.tax_percentage_snapshot, Decimal("16.00"))
        self.assertEqual(item.subtotal_amount, Decimal("200.00"))
        self.assertEqual(item.tax_amount, Decimal("32.00"))
        self.assertEqual(item.total_amount, Decimal("232.00"))

    def test_items_recalculate_payment_request_totals(self):
        PaymentRequestItem.objects.create(
            payment_request=self.payment_request,
            description="Servicio gravado",
            quantity=Decimal("1.000"),
            unit_price=Decimal("100.00"),
            tax_rate=self.tax_rate,
        )
        PaymentRequestItem.objects.create(
            payment_request=self.payment_request,
            description="Servicio exento",
            quantity=Decimal("2.000"),
            unit_price=Decimal("50.00"),
            tax_percentage_snapshot=Decimal("0.00"),
        )

        self.payment_request.refresh_from_db()
        self.assertEqual(self.payment_request.subtotal_amount, Decimal("200.00"))
        self.assertEqual(self.payment_request.tax_amount, Decimal("16.00"))
        self.assertEqual(self.payment_request.amount, Decimal("216.00"))

    def test_item_rejects_invalid_quantity(self):
        item = PaymentRequestItem(
            payment_request=self.payment_request,
            description="Cantidad inválida",
            quantity=Decimal("0.000"),
            unit_price=Decimal("100.00"),
            tax_rate=self.tax_rate,
        )

        with self.assertRaises(ValidationError):
            item.full_clean()

    def test_deleting_item_recalculates_parent_totals(self):
        item = PaymentRequestItem.objects.create(
            payment_request=self.payment_request,
            description="Servicio gravado",
            quantity=Decimal("1.000"),
            unit_price=Decimal("100.00"),
            tax_rate=self.tax_rate,
        )
        self.payment_request.refresh_from_db()
        self.assertEqual(self.payment_request.amount, Decimal("116.00"))

        item.delete()

        self.payment_request.refresh_from_db()
        self.assertEqual(self.payment_request.subtotal_amount, Decimal("0.00"))
        self.assertEqual(self.payment_request.tax_amount, Decimal("0.00"))
        self.assertEqual(self.payment_request.amount, Decimal("0.00"))
        persisted = type(self.payment_request).objects.get(pk=self.payment_request.pk)
        self.assertEqual(persisted.subtotal_amount, Decimal("0.00"))
        self.assertEqual(persisted.tax_amount, Decimal("0.00"))
        self.assertEqual(persisted.amount, Decimal("0.00"))

    def test_approval_validation_rejects_request_without_items(self):
        with self.assertRaises(ValidationError):
            assert_payment_request_ready_for_approval(self.payment_request)

    def test_approval_validation_rejects_inconsistent_totals(self):
        PaymentRequestItem.objects.create(
            payment_request=self.payment_request,
            description="Servicio con total inconsistente",
            quantity=Decimal("1"),
            unit_price=Decimal("100.00"),
            tax_rate=self.tax_rate,
        )
        type(self.payment_request).objects.filter(pk=self.payment_request.pk).update(amount=Decimal("999.99"))
        self.payment_request.refresh_from_db()

        with self.assertRaises(ValidationError):
            assert_payment_request_ready_for_approval(self.payment_request)

    def test_approval_validation_accepts_valid_items_and_totals(self):
        PaymentRequestItem.objects.create(
            payment_request=self.payment_request,
            description="Servicio listo para aprobacion",
            quantity=Decimal("1"),
            unit_price=Decimal("100.00"),
            tax_rate=self.tax_rate,
        )
        self.payment_request.refresh_from_db()

        assert_payment_request_ready_for_approval(self.payment_request)

    def test_send_to_approval_rejects_request_without_items(self):
        with self.assertRaises(ValidationError):
            self.payment_request.submit_for_approval(self.user)
