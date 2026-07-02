from pathlib import Path

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models


class PaymentDocumentType(models.TextChoices):
    INVOICE = "INVOICE", "Factura"
    PURCHASE_ORDER = "PURCHASE_ORDER", "Orden de compra"
    DELIVERY_NOTE = "DELIVERY_NOTE", "Nota de entrega"
    TAX_DOCUMENT = "TAX_DOCUMENT", "Documento fiscal"
    SUPPORT = "SUPPORT", "Soporte general"
    OTHER = "OTHER", "Otro"


def payment_request_document_upload_to(instance, filename: str) -> str:
    suffix = Path(filename).suffix.lower()
    safe_name = f"document{suffix}" if suffix else "document"
    payment_request_id = instance.payment_request_id or "pending"
    return f"payment_requests/{payment_request_id}/documents/{safe_name}"


class PaymentRequestDocument(models.Model):
    payment_request = models.ForeignKey(
        "payment_requests.PaymentRequest",
        on_delete=models.PROTECT,
        related_name="documents",
        verbose_name="solicitud de pago",
    )
    document_type = models.CharField(
        max_length=30,
        choices=PaymentDocumentType.choices,
        default=PaymentDocumentType.SUPPORT,
        verbose_name="tipo de documento",
    )
    file = models.FileField(
        upload_to=payment_request_document_upload_to,
        verbose_name="archivo",
    )
    original_filename = models.CharField(
        max_length=255,
        verbose_name="nombre original",
    )
    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="uploaded_payment_documents",
        verbose_name="cargado por",
    )
    notes = models.TextField(blank=True, verbose_name="notas")
    is_required = models.BooleanField(default=False, verbose_name="requerido")
    is_active = models.BooleanField(default=True, verbose_name="activo")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="creado")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="actualizado")

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "documento soporte de pago"
        verbose_name_plural = "documentos soporte de pago"
        indexes = [
            models.Index(fields=["payment_request", "document_type"], name="paydoc_req_type_idx"),
            models.Index(fields=["uploaded_by", "created_at"], name="paydoc_user_created_idx"),
            models.Index(fields=["is_active", "created_at"], name="paydoc_active_created_idx"),
        ]

    def clean(self):
        super().clean()
        if not self.file:
            raise ValidationError({"file": "El archivo es obligatorio."})
        if not self.original_filename and self.file:
            self.original_filename = Path(self.file.name).name

    def save(self, *args, **kwargs):
        if self.file and not self.original_filename:
            self.original_filename = Path(self.file.name).name
        self.full_clean()
        super().save(*args, **kwargs)

    def deactivate(self):
        self.is_active = False
        self.save(update_fields=["is_active", "updated_at"])

    def __str__(self) -> str:
        return f"{self.payment_request_id} - {self.get_document_type_display()} - {self.original_filename}"
