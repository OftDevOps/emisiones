from decimal import Decimal, ROUND_HALF_UP

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
from django.utils import timezone
from .services import calculate_item_totals, calculate_payment_request_totals



MONEY_QUANTIZER = Decimal("0.01")


def quantize_money(value: Decimal | int | str | None) -> Decimal:
    """Normalize monetary values to two decimals using commercial rounding."""
    if value is None:
        value = Decimal("0.00")
    if not isinstance(value, Decimal):
        value = Decimal(str(value))
    return value.quantize(MONEY_QUANTIZER, rounding=ROUND_HALF_UP)


class TaxRate(models.Model):
    """Configurable tax/VAT rate used by emission items."""

    name = models.CharField("nombre", max_length=80)
    percentage = models.DecimalField("porcentaje", max_digits=5, decimal_places=2)
    is_active = models.BooleanField("activo", default=True)
    valid_from = models.DateField("vigente desde", default=timezone.localdate)
    valid_to = models.DateField("vigente hasta", null=True, blank=True)
    created_at = models.DateTimeField("creado", auto_now_add=True)
    updated_at = models.DateTimeField("actualizado", auto_now=True)

    class Meta:
        ordering = ["-is_active", "-valid_from", "name"]
        verbose_name = "tasa de impuesto"
        verbose_name_plural = "tasas de impuesto"

    def clean(self):
        super().clean()
        if self.percentage < Decimal("0.00"):
            raise ValidationError("El porcentaje de impuesto no puede ser negativo.")
        if self.percentage > Decimal("100.00"):
            raise ValidationError("El porcentaje de impuesto no puede ser mayor a 100%.")
        if self.valid_to and self.valid_to < self.valid_from:
            raise ValidationError("La fecha final de vigencia no puede ser anterior a la inicial.")

    def is_valid_for(self, target_date=None) -> bool:
        target_date = target_date or timezone.localdate()
        if self.valid_from and target_date < self.valid_from:
            return False
        if self.valid_to and target_date > self.valid_to:
            return False
        return self.is_active

    def __str__(self) -> str:
        return f"{self.name} ({self.percentage}%)"


class PaymentRequestStatus(models.TextChoices):
    DRAFT = "DRAFT", "Borrador"
    SUBMITTED = "SUBMITTED", "Enviada"
    UNIT_REVIEW = "UNIT_REVIEW", "Revisión unidad"
    FINANCE_REVIEW = "FINANCE_REVIEW", "Revisión finanzas"
    MANAGEMENT_REVIEW = "MANAGEMENT_REVIEW", "Revisión gerencia"
    APPROVED = "APPROVED", "Aprobada"
    PAID = "PAID", "Pagada"
    REJECTED = "REJECTED", "Rechazada"
    CANCELLED = "CANCELLED", "Cancelada"


class Currency(models.TextChoices):
    VES = "VES", "Bolívares"
    USD = "USD", "Dólares"
    EUR = "EUR", "Euros"


class PaymentRequest(models.Model):
    company = models.ForeignKey(
        "organization.Company",
        on_delete=models.PROTECT,
        related_name="payment_requests",
        verbose_name="empresa",
    )
    beneficiary = models.ForeignKey(
        "beneficiaries.Beneficiary",
        on_delete=models.PROTECT,
        related_name="payment_requests",
        verbose_name="beneficiario",
    )
    requested_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="payment_requests",
        verbose_name="solicitado por",
    )
    amount = models.DecimalField(max_digits=18, decimal_places=2, verbose_name="monto")
    subtotal_amount = models.DecimalField(
        "subtotal",
        max_digits=14,
        decimal_places=2,
        default=Decimal("0.00"),
    )
    tax_amount = models.DecimalField(
        "monto de impuesto",
        max_digits=14,
        decimal_places=2,
        default=Decimal("0.00"),
    )
    currency = models.CharField(
        max_length=3,
        choices=Currency.choices,
        default=Currency.VES,
        verbose_name="moneda",
    )
    concept = models.CharField(max_length=220, verbose_name="concepto")
    description = models.TextField(blank=True, verbose_name="descripción")
    due_date = models.DateField(null=True, blank=True, verbose_name="fecha estimada de pago")
    status = models.CharField(
        max_length=20,
        choices=PaymentRequestStatus.choices,
        default=PaymentRequestStatus.DRAFT,
        verbose_name="estado",
    )
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="creado")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="actualizado")

    class Meta:
        ordering = ["-created_at", "-id"]
        verbose_name = "solicitud de pago"
        verbose_name_plural = "solicitudes de pago"
        indexes = [
            models.Index(fields=["company", "status"], name="payreq_comp_st_idx"),
            models.Index(fields=["beneficiary", "status"], name="payreq_ben_st_idx"),
            models.Index(fields=["requested_by", "status"], name="payreq_req_st_idx"),
            models.Index(fields=["created_at"], name="payreq_created_idx"),
        ]

    def clean(self):
        super().clean()
        if self.amount is not None and self.amount <= Decimal("0"):
            raise ValidationError({"amount": "El monto debe ser mayor que cero."})

        if self.company_id and self.beneficiary_id:
            beneficiary_company_id = getattr(self.beneficiary, "company_id", None)
            if beneficiary_company_id and beneficiary_company_id != self.company_id:
                raise ValidationError(
                    {"beneficiary": "El beneficiario debe pertenecer a la misma empresa de la solicitud."}
                )

    def save(self, *args, **kwargs):
        self.full_clean()
        return super().save(*args, **kwargs)

    def submit_for_approval(self, user):
        if self.status != PaymentRequestStatus.DRAFT:
            from django.core.exceptions import ValidationError
            raise ValidationError("Solo solicitudes en borrador pueden enviarse a aprobación.")
        self.status = PaymentRequestStatus.UNIT_REVIEW
        self.save(update_fields=["status", "updated_at"])

        from apps.accounts.models import UserRole
        from apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction, PaymentApprovalStep

        default_steps = [
            (1, UserRole.RESPONSABLE_UNIDAD),
            (2, UserRole.FINANZAS),
            (3, UserRole.GERENCIA_GENERAL),
        ]
        for sequence, required_role in default_steps:
            PaymentApprovalStep.objects.get_or_create(
                payment_request=self,
                sequence=sequence,
                defaults={"required_role": required_role},
            )
        PaymentApprovalAction.objects.create(
            payment_request=self,
            action=ApprovalActionType.SUBMIT,
            performed_by=user,
            role=user.role,
            comment="Solicitud enviada a aprobación.",
        )

    def refresh_approval_status(self):
        steps = list(self.approval_steps.order_by("sequence"))
        if not steps:
            return

        from apps.payment_approvals.models import ApprovalStepStatus

        if any(step.status == ApprovalStepStatus.REJECTED for step in steps):
            self.status = PaymentRequestStatus.REJECTED
        elif all(step.status == ApprovalStepStatus.APPROVED for step in steps):
            self.status = PaymentRequestStatus.APPROVED
        else:
            pending = next((step for step in steps if step.status == ApprovalStepStatus.PENDING), None)
            if pending and pending.required_role == "FINANZAS":
                self.status = PaymentRequestStatus.FINANCE_REVIEW
            elif pending and pending.required_role == "GERENCIA_GENERAL":
                self.status = PaymentRequestStatus.MANAGEMENT_REVIEW
            else:
                self.status = PaymentRequestStatus.UNIT_REVIEW
        self.save(update_fields=["status", "updated_at"])


    def recalculate_totals_from_items(self, save: bool = True):
        if not self.pk:
            return

        items = PaymentRequestItem.objects.filter(payment_request_id=self.pk)
        totals = calculate_payment_request_totals(items)

        self.subtotal_amount = totals["subtotal_amount"]
        self.tax_amount = totals["tax_amount"]
        self.amount = totals["amount"]

        if save:
            PaymentRequest.objects.filter(pk=self.pk).update(
                subtotal_amount=self.subtotal_amount,
                tax_amount=self.tax_amount,
                amount=self.amount,
                updated_at=timezone.now(),
            )

    def __str__(self) -> str:
        return f"{self.company} - {self.beneficiary} - {self.amount} {self.currency}"

class PaymentRequestItem(models.Model):
    """Invoice/emission line used to calculate subtotal, VAT and final total."""

    payment_request = models.ForeignKey(
        PaymentRequest,
        on_delete=models.CASCADE,
        related_name="items",
        verbose_name="emisión",
    )
    description = models.CharField("descripción", max_length=255)
    quantity = models.DecimalField("cantidad", max_digits=12, decimal_places=3)
    unit_price = models.DecimalField("precio unitario", max_digits=14, decimal_places=2)
    tax_rate = models.ForeignKey(
        TaxRate,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="payment_request_items",
        verbose_name="tasa de impuesto",
    )
    tax_percentage_snapshot = models.DecimalField(
        "porcentaje de impuesto aplicado",
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
    )
    subtotal_amount = models.DecimalField("subtotal", max_digits=14, decimal_places=2, default=Decimal("0.00"))
    tax_amount = models.DecimalField("monto de impuesto", max_digits=14, decimal_places=2, default=Decimal("0.00"))
    total_amount = models.DecimalField("total", max_digits=14, decimal_places=2, default=Decimal("0.00"))
    created_at = models.DateTimeField("creado", auto_now_add=True)
    updated_at = models.DateTimeField("actualizado", auto_now=True)

    class Meta:
        ordering = ["id"]
        verbose_name = "ítem de emisión"
        verbose_name_plural = "ítems de emisión"

    def clean(self):
        super().clean()
        if self.quantity <= Decimal("0.000"):
            raise ValidationError("La cantidad del ítem debe ser mayor que cero.")
        if self.unit_price < Decimal("0.00"):
            raise ValidationError("El precio unitario no puede ser negativo.")
        if self.tax_percentage_snapshot is not None:
            if self.tax_percentage_snapshot < Decimal("0.00"):
                raise ValidationError("El porcentaje de impuesto no puede ser negativo.")
            if self.tax_percentage_snapshot > Decimal("100.00"):
                raise ValidationError("El porcentaje de impuesto no puede ser mayor a 100%.")

    def recalculate_amounts(self):
        if self.tax_percentage_snapshot is None:
            self.tax_percentage_snapshot = (
                self.tax_rate.percentage if self.tax_rate_id and self.tax_rate else Decimal("0.00")
            )

        subtotal = quantize_money(self.quantity * self.unit_price)
        tax = quantize_money(subtotal * self.tax_percentage_snapshot / Decimal("100.00"))
        total = quantize_money(subtotal + tax)

        self.subtotal_amount = subtotal
        self.tax_amount = tax
        self.total_amount = total
        return self

    def save(self, *args, **kwargs):
        if self.tax_percentage_snapshot is None and self.tax_rate_id:
            self.tax_percentage_snapshot = self.tax_rate.percentage

        totals = calculate_item_totals(
            quantity=self.quantity,
            unit_price=self.unit_price,
            tax_percentage_snapshot=self.tax_percentage_snapshot,
        )
        self.subtotal_amount = totals["subtotal_amount"]
        self.tax_amount = totals["tax_amount"]
        self.total_amount = totals["total_amount"]

        self.full_clean()
        super().save(*args, **kwargs)
        self.payment_request.recalculate_totals_from_items(save=True)

    def delete(self, *args, **kwargs):
        payment_request_id = self.payment_request_id
        result = super().delete(*args, **kwargs)
        if payment_request_id:
            payment_request = PaymentRequest.objects.filter(pk=payment_request_id).first()
            if payment_request is not None:
                payment_request.recalculate_totals_from_items(save=True)
        return result

    def __str__(self) -> str:
        return f"{self.description} - {self.total_amount}"
