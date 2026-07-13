from decimal import Decimal

from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary, BeneficiaryType
from apps.organization.models import Company
from apps.payment_requests.models import (
    Currency,
    PaymentRequest,
    PaymentRequestItem,
    PaymentRequestStatus,
    TaxRate,
)


class PaymentRequestItemsUpdateViewTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.owner = CustomUser.objects.create_user(
            email="owner.update@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.company,
        )
        self.other_user = CustomUser.objects.create_user(
            email="other.update@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.company,
        )
        self.admin = CustomUser.objects.create_user(
            email="admin.update@oftalmi.com",
            password="test-pass-123",
            role=UserRole.ADMINISTRADOR,
            primary_company=self.company,
        )
        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Edición C.A.",
            document_number="J-77777777-7",
        )
        self.tax_rate = TaxRate.objects.create(
            name="IVA edición 16%",
            percentage=Decimal("16.00"),
            is_active=True,
        )
        self.payment_request = PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.owner,
            amount=Decimal("1.00"),
            currency=Currency.VES,
            concept="Emisión editable",
        )
        self.item = PaymentRequestItem.objects.create(
            payment_request=self.payment_request,
            description="Ítem original",
            quantity=Decimal("1.000"),
            unit_price=Decimal("100.00"),
            tax_rate=self.tax_rate,
        )
        self.url = reverse("payment_requests:edit", args=[self.payment_request.pk])

    def update_payload(self, **overrides):
        data = {
            "company": str(self.company.pk),
            "beneficiary": str(self.beneficiary.pk),
            "currency": Currency.VES,
            "concept": "Emisión actualizada",
            "description": "Descripción actualizada",
            "due_date": "2026-12-31",
            "items-TOTAL_FORMS": "1",
            "items-INITIAL_FORMS": "1",
            "items-MIN_NUM_FORMS": "1",
            "items-MAX_NUM_FORMS": "1000",
            "items-0-id": str(self.item.pk),
            "items-0-payment_request": str(self.payment_request.pk),
            "items-0-description": "Ítem actualizado",
            "items-0-quantity": "2.000",
            "items-0-unit_price": "150.00",
            "items-0-tax_rate": str(self.tax_rate.pk),
        }
        data.update(overrides)
        return data

    def test_update_requires_login(self):
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response["Location"])

    def test_owner_can_open_draft_update_form(self):
        self.client.force_login(self.owner)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Editar emisión")
        self.assertContains(response, "Ítem original")
        self.assertContains(response, "Guardar cambios")

    def test_owner_can_update_item_and_recalculate_totals(self):
        self.client.force_login(self.owner)
        response = self.client.post(self.url, self.update_payload())
        self.assertRedirects(response, reverse("payment_requests:detail", args=[self.payment_request.pk]))
        self.payment_request.refresh_from_db()
        self.item.refresh_from_db()
        self.assertEqual(self.payment_request.concept, "Emisión actualizada")
        self.assertEqual(self.item.description, "Ítem actualizado")
        self.assertEqual(self.payment_request.subtotal_amount, Decimal("300.00"))
        self.assertEqual(self.payment_request.tax_amount, Decimal("48.00"))
        self.assertEqual(self.payment_request.amount, Decimal("348.00"))

    def test_non_owner_cannot_edit_same_company_draft(self):
        self.client.force_login(self.other_user)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 404)

    def test_administrator_can_edit_same_company_draft(self):
        self.client.force_login(self.admin)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 200)

    def test_non_draft_request_cannot_be_edited(self):
        self.payment_request.status = PaymentRequestStatus.UNIT_REVIEW
        self.payment_request.save(update_fields=["status", "updated_at"])
        self.client.force_login(self.owner)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 404)
