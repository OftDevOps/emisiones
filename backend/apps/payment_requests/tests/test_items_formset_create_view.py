
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from apps.payment_requests.forms import PaymentRequestItemFormSet
from apps.payment_requests.models import TaxRate


class PaymentRequestItemFormSetTests(TestCase):
    def test_formset_requires_at_least_one_item(self):
        formset = PaymentRequestItemFormSet(
            data={
                "items-TOTAL_FORMS": "0",
                "items-INITIAL_FORMS": "0",
                "items-MIN_NUM_FORMS": "1",
                "items-MAX_NUM_FORMS": "1000",
            }
        )

        self.assertFalse(formset.is_valid())

    def test_formset_accepts_valid_item(self):
        tax_rate = TaxRate.objects.create(name="IVA 16%", percentage=Decimal("16.00"), is_active=True)
        formset = PaymentRequestItemFormSet(
            data={
                "items-TOTAL_FORMS": "1",
                "items-INITIAL_FORMS": "0",
                "items-MIN_NUM_FORMS": "1",
                "items-MAX_NUM_FORMS": "1000",
                "items-0-description": "Servicio técnico",
                "items-0-quantity": "2",
                "items-0-unit_price": "100.00",
                "items-0-tax_rate": str(tax_rate.pk),
            }
        )

        self.assertTrue(formset.is_valid(), formset.errors)


class PaymentRequestCreateItemsViewTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(
            email="solicitante.items@example.com",
            password="testpass123",
        )
        self.client.force_login(self.user)
        self.tax_rate = TaxRate.objects.create(name="IVA 16%", percentage=Decimal("16.00"), is_active=True)

    def test_create_view_exposes_items_formset(self):
        url = reverse("payment_requests:create")
        response = self.client.get(url)

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Ítems de factura")
        self.assertContains(response, "items-TOTAL_FORMS")
