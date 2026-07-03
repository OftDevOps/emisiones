from decimal import Decimal

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models

from apps.payment_requests.models import PaymentRequest, PaymentRequestStatus


class PaymentExecution(models.Model):
    payment_request = models.OneToOneField(
        PaymentRequest,
        on_delete=models.PROTECT,
        related_name="payment_execution",
        verbose_name="solicitud de pago",
    )
    executed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="payment_executions",
        verbose_name="ejecutado por",
    )
    paid_at = models.DateField(verbose_name="fecha de pago")
    paid_amount = models.DecimalField(max_digits=18, decimal_places=2, verbose_name="monto pagado")
    bank_reference = models.CharField(max_length=120, verbose_name="referencia bancaria")
    note = models.TextField(blank=True, verbose_name="observacion")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="creado")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="actualizado")

    class Meta:
        ordering = ["-paid_at", "-created_at", "-id"]
        verbose_name = "ejecucion de pago"
        verbose_name_plural = "ejecuciones de pago"
        indexes = [
            models.Index(fields=["paid_at"], name="payexec_paid_at_idx"),
            models.Index(fields=["bank_reference"], name="payexec_bank_ref_idx"),
        ]

    def clean(self):
        super().clean()
        if self.paid_amount is not None and self.paid_amount <= Decimal("0"):
            raise ValidationError({"paid_amount": "El monto pagado debe ser mayor que cero."})
        if not self.pk and self.payment_request_id and self.payment_request.status != PaymentRequestStatus.APPROVED:
            raise ValidationError("Solo solicitudes aprobadas pueden registrarse como pagadas.")

    def save(self, *args, **kwargs):
        self.full_clean()
        result = super().save(*args, **kwargs)
        if self.payment_request.status != PaymentRequestStatus.PAID:
            self.payment_request.status = PaymentRequestStatus.PAID
            self.payment_request.save(update_fields=["status", "updated_at"])
        return result

    def __str__(self) -> str:
        return f"{self.payment_request_id} - {self.paid_amount} - {self.bank_reference}"
