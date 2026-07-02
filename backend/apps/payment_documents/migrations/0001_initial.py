# Generated for F1-P12
import apps.payment_documents.models
import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("payment_requests", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="PaymentRequestDocument",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("document_type", models.CharField(choices=[("INVOICE", "Factura"), ("PURCHASE_ORDER", "Orden de compra"), ("DELIVERY_NOTE", "Nota de entrega"), ("TAX_DOCUMENT", "Documento fiscal"), ("SUPPORT", "Soporte general"), ("OTHER", "Otro")], default="SUPPORT", max_length=30, verbose_name="tipo de documento")),
                ("file", models.FileField(upload_to=apps.payment_documents.models.payment_request_document_upload_to, verbose_name="archivo")),
                ("original_filename", models.CharField(max_length=255, verbose_name="nombre original")),
                ("notes", models.TextField(blank=True, verbose_name="notas")),
                ("is_required", models.BooleanField(default=False, verbose_name="requerido")),
                ("is_active", models.BooleanField(default=True, verbose_name="activo")),
                ("created_at", models.DateTimeField(auto_now_add=True, verbose_name="creado")),
                ("updated_at", models.DateTimeField(auto_now=True, verbose_name="actualizado")),
                ("payment_request", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="documents", to="payment_requests.paymentrequest", verbose_name="solicitud de pago")),
                ("uploaded_by", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="uploaded_payment_documents", to=settings.AUTH_USER_MODEL, verbose_name="cargado por")),
            ],
            options={
                "verbose_name": "documento soporte de pago",
                "verbose_name_plural": "documentos soporte de pago",
                "ordering": ["-created_at"],
                "indexes": [
                    models.Index(fields=["payment_request", "document_type"], name="paydoc_req_type_idx"),
                    models.Index(fields=["uploaded_by", "created_at"], name="paydoc_user_created_idx"),
                    models.Index(fields=["is_active", "created_at"], name="paydoc_active_created_idx"),
                ],
            },
        ),
    ]
