from decimal import Decimal

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models


class PaymentRequestStatus(models.TextChoices):
    DRAFT = "DRAFT", "Borrador"
    SUBMITTED = "SUBMITTED", "Enviada"
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

    def __str__(self) -> str:
        return f"{self.company} - {self.beneficiary} - {self.amount} {self.currency}"
