from decimal import Decimal
from types import SimpleNamespace

from django.test import SimpleTestCase

from apps.payment_requests.services import (
    calculate_item_totals,
    calculate_payment_request_totals,
    quantize_money,
)


class PaymentTotalsServiceTests(SimpleTestCase):
    def test_quantize_money_uses_half_up_rounding(self):
        self.assertEqual(quantize_money(Decimal("10.005")), Decimal("10.01"))

    def test_calculate_item_totals_with_tax(self):
        totals = calculate_item_totals(
            quantity=Decimal("2"),
            unit_price=Decimal("100.00"),
            tax_percentage_snapshot=Decimal("16.00"),
        )

        self.assertEqual(totals["subtotal_amount"], Decimal("200.00"))
        self.assertEqual(totals["tax_amount"], Decimal("32.00"))
        self.assertEqual(totals["total_amount"], Decimal("232.00"))

    def test_calculate_item_totals_without_tax(self):
        totals = calculate_item_totals(
            quantity=Decimal("3"),
            unit_price=Decimal("25.50"),
            tax_percentage_snapshot=None,
        )

        self.assertEqual(totals["subtotal_amount"], Decimal("76.50"))
        self.assertEqual(totals["tax_amount"], Decimal("0.00"))
        self.assertEqual(totals["total_amount"], Decimal("76.50"))

    def test_calculate_payment_request_totals(self):
        items = [
            SimpleNamespace(subtotal_amount=Decimal("100.00"), tax_amount=Decimal("16.00")),
            SimpleNamespace(subtotal_amount=Decimal("50.00"), tax_amount=Decimal("8.00")),
        ]

        totals = calculate_payment_request_totals(items)

        self.assertEqual(totals["subtotal_amount"], Decimal("150.00"))
        self.assertEqual(totals["tax_amount"], Decimal("24.00"))
        self.assertEqual(totals["amount"], Decimal("174.00"))

    def test_calculate_payment_request_totals_empty_items(self):
        totals = calculate_payment_request_totals([])

        self.assertEqual(totals["subtotal_amount"], Decimal("0.00"))
        self.assertEqual(totals["tax_amount"], Decimal("0.00"))
        self.assertEqual(totals["amount"], Decimal("0.00"))
