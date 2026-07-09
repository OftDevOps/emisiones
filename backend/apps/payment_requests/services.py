"""Calculation helpers for payment request invoice items and totals."""

from __future__ import annotations

from decimal import Decimal, ROUND_HALF_UP
from typing import Iterable, Mapping, Protocol


MONEY_QUANT = Decimal("0.01")


class PaymentRequestTotalItem(Protocol):
    subtotal_amount: Decimal
    tax_amount: Decimal


def quantize_money(value: Decimal | int | str) -> Decimal:
    """Round monetary values to two decimals using business rounding."""
    return Decimal(value).quantize(MONEY_QUANT, rounding=ROUND_HALF_UP)


def calculate_item_totals(
    quantity: Decimal | int | str,
    unit_price: Decimal | int | str,
    tax_percentage_snapshot: Decimal | int | str | None,
) -> Mapping[str, Decimal]:
    """Calculate subtotal, tax and final total for one invoice item."""
    subtotal = quantize_money(Decimal(quantity) * Decimal(unit_price))
    tax_percentage = Decimal("0.00") if tax_percentage_snapshot is None else Decimal(tax_percentage_snapshot)
    tax = quantize_money(subtotal * tax_percentage / Decimal("100.00"))
    total = quantize_money(subtotal + tax)
    return {
        "subtotal_amount": subtotal,
        "tax_amount": tax,
        "total_amount": total,
    }


def calculate_payment_request_totals(items: Iterable[PaymentRequestTotalItem]) -> Mapping[str, Decimal]:
    """Calculate subtotal, tax and final amount from persisted item totals."""
    subtotal = quantize_money(sum((item.subtotal_amount for item in items), Decimal("0.00")))
    tax_total = quantize_money(sum((item.tax_amount for item in items), Decimal("0.00")))
    total = quantize_money(subtotal + tax_total)
    return {
        "subtotal_amount": subtotal,
        "tax_amount": tax_total,
        "amount": total,
    }
