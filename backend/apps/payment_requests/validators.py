from decimal import Decimal

from django.core.exceptions import ValidationError

from .services import calculate_payment_request_totals, quantize_money


class PaymentRequestApprovalValidationError(ValidationError):
    """Raised when an emission is not ready to enter the approval route."""


def assert_payment_request_ready_for_approval(payment_request) -> None:
    """Validate invoice items and totals before sending an emission to approval."""
    if not payment_request.pk:
        raise PaymentRequestApprovalValidationError(
            "La emision debe estar guardada antes de enviarse a aprobacion."
        )

    from .models import PaymentRequestItem

    items = list(PaymentRequestItem.objects.filter(payment_request_id=payment_request.pk))
    if not items:
        raise PaymentRequestApprovalValidationError(
            "La emision debe tener al menos un item de factura antes de enviarse a aprobacion."
        )

    for index, item in enumerate(items, start=1):
        if item.quantity <= 0:
            raise PaymentRequestApprovalValidationError(
                f"El item {index} debe tener cantidad mayor que cero."
            )
        if item.unit_price < Decimal("0.00"):
            raise PaymentRequestApprovalValidationError(
                f"El item {index} no puede tener precio unitario negativo."
            )
        if item.subtotal_amount <= Decimal("0.00"):
            raise PaymentRequestApprovalValidationError(
                f"El item {index} debe tener subtotal mayor que cero."
            )

    totals = calculate_payment_request_totals(items)
    if totals["amount"] <= Decimal("0.00"):
        raise PaymentRequestApprovalValidationError(
            "El total de la emision debe ser mayor que cero antes de enviarse a aprobacion."
        )

    current_subtotal = quantize_money(payment_request.subtotal_amount)
    current_tax = quantize_money(payment_request.tax_amount)
    current_total = quantize_money(payment_request.amount)

    if (
        current_subtotal != totals["subtotal_amount"]
        or current_tax != totals["tax_amount"]
        or current_total != totals["amount"]
    ):
        raise PaymentRequestApprovalValidationError(
            "Los totales de la emision no coinciden con los items de factura. Recalcule antes de enviar."
        )
