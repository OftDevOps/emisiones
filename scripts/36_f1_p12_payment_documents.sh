#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' '== F1-P12: Payment support documents =='

if [ ! -f "backend/manage.py" ]; then
  printf '%s\n' 'ERROR: run this script from repository root: /home/dchirinos/oftalmiIA/emisiones/emisiones' >&2
  exit 1
fi

mkdir -p backend/apps/payment_documents/migrations backend/apps/payment_documents/tests docs/03-desarrollo docs/05-modelo-datos

touch backend/apps/payment_documents/__init__.py
touch backend/apps/payment_documents/migrations/__init__.py
touch backend/apps/payment_documents/tests/__init__.py

cat > backend/apps/payment_documents/apps.py <<'PY'
from django.apps import AppConfig


class PaymentDocumentsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.payment_documents"
    label = "payment_documents"
    verbose_name = "Documentos de pago"
PY

cat > backend/apps/payment_documents/models.py <<'PY'
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
PY

cat > backend/apps/payment_documents/admin.py <<'PY'
from django.contrib import admin

from .models import PaymentRequestDocument


@admin.register(PaymentRequestDocument)
class PaymentRequestDocumentAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "payment_request",
        "document_type",
        "original_filename",
        "uploaded_by",
        "is_required",
        "is_active",
        "created_at",
    )
    search_fields = (
        "original_filename",
        "payment_request__concept",
        "uploaded_by__email",
    )
    list_filter = (
        "document_type",
        "is_required",
        "is_active",
        "created_at",
    )
    readonly_fields = ("created_at", "updated_at")
PY

cat > backend/apps/payment_documents/migrations/0001_initial.py <<'PY'
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
PY

python3 - <<'PY'
from pathlib import Path
p = Path('backend/config/settings/base.py')
s = p.read_text()
if '"apps.payment_documents"' not in s and "'apps.payment_documents'" not in s:
    marker = '"apps.payment_requests",'
    if marker in s:
        s = s.replace(marker, '"apps.payment_requests",\n    "apps.payment_documents",')
    else:
        marker = "'apps.payment_requests',"
        if marker in s:
            s = s.replace(marker, "'apps.payment_requests',\n    'apps.payment_documents',")
        else:
            raise SystemExit('ERROR: apps.payment_requests not found in INSTALLED_APPS')

if 'MEDIA_URL' not in s:
    s += '\n\nMEDIA_URL = "/media/"\nMEDIA_ROOT = BASE_DIR / "media"\n'
p.write_text(s)
PY

python3 - <<'PY'
from pathlib import Path
p = Path('backend/config/urls.py')
s = p.read_text()
if 'settings.MEDIA_URL' not in s:
    if 'from django.conf import settings' not in s:
        s = 'from django.conf import settings\nfrom django.conf.urls.static import static\n' + s
    elif 'from django.conf.urls.static import static' not in s:
        s = s.replace('from django.conf import settings\n', 'from django.conf import settings\nfrom django.conf.urls.static import static\n')
    s = s.rstrip() + '\n\nif settings.DEBUG:\n    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)\n'
p.write_text(s)
PY

cat > backend/apps/payment_documents/tests/test_models.py <<'PY'
from decimal import Decimal
from tempfile import TemporaryDirectory

from django.core.exceptions import ValidationError
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary, BeneficiaryType
from apps.organization.models import Company
from apps.payment_documents.models import PaymentDocumentType, PaymentRequestDocument, payment_request_document_upload_to
from apps.payment_requests.models import Currency, PaymentRequest


class PaymentRequestDocumentModelTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.user = CustomUser.objects.create_user(
            email="solicitante.docs@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.company,
        )
        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Documentos C.A.",
            identification="J-22222222-2",
            email="proveedor.docs@example.com",
        )
        self.payment_request = PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.user,
            amount=Decimal("150.00"),
            currency=Currency.VES,
            concept="Pago con soporte",
        )

    def make_file(self, name="factura.pdf", content=b"PDF content"):
        return SimpleUploadedFile(name, content, content_type="application/pdf")

    @override_settings(MEDIA_ROOT=TemporaryDirectory().name)
    def test_create_payment_document(self):
        document = PaymentRequestDocument.objects.create(
            payment_request=self.payment_request,
            document_type=PaymentDocumentType.INVOICE,
            file=self.make_file(),
            uploaded_by=self.user,
            notes="Factura principal",
            is_required=True,
        )

        self.assertEqual(document.payment_request, self.payment_request)
        self.assertEqual(document.uploaded_by, self.user)
        self.assertEqual(document.original_filename, "factura.pdf")
        self.assertTrue(document.is_active)
        self.assertTrue(document.is_required)

    def test_file_is_required(self):
        document = PaymentRequestDocument(
            payment_request=self.payment_request,
            document_type=PaymentDocumentType.SUPPORT,
            uploaded_by=self.user,
            original_filename="sin_archivo.pdf",
        )

        with self.assertRaises(ValidationError):
            document.full_clean()

    @override_settings(MEDIA_ROOT=TemporaryDirectory().name)
    def test_deactivate_document(self):
        document = PaymentRequestDocument.objects.create(
            payment_request=self.payment_request,
            document_type=PaymentDocumentType.SUPPORT,
            file=self.make_file("soporte.pdf"),
            uploaded_by=self.user,
        )

        document.deactivate()
        document.refresh_from_db()
        self.assertFalse(document.is_active)

    def test_upload_path_uses_payment_request_id(self):
        document = PaymentRequestDocument(payment_request=self.payment_request)
        path = payment_request_document_upload_to(document, "Factura Original.PDF")

        self.assertEqual(path, f"payment_requests/{self.payment_request.id}/documents/document.pdf")

    @override_settings(MEDIA_ROOT=TemporaryDirectory().name)
    def test_related_documents_from_payment_request(self):
        PaymentRequestDocument.objects.create(
            payment_request=self.payment_request,
            document_type=PaymentDocumentType.PURCHASE_ORDER,
            file=self.make_file("orden.pdf"),
            uploaded_by=self.user,
        )

        self.assertEqual(self.payment_request.documents.count(), 1)
PY

cat > docs/03-desarrollo/f1_p12_documentos_soporte.md <<'MD'
# F1-P12 Documentos soporte

## Objetivo

Agregar documentos soporte a las solicitudes de pago sin adelantar todavía el flujo formal de aprobación.

## App creada

```text
payment_documents
```

## Modelo principal

```text
PaymentRequestDocument
```

## Campos clave

```text
payment_request
 document_type
 file
 original_filename
 uploaded_by
 notes
 is_required
 is_active
 created_at
 updated_at
```

## Tipos de documento

```text
INVOICE          Factura
PURCHASE_ORDER   Orden de compra
DELIVERY_NOTE    Nota de entrega
TAX_DOCUMENT     Documento fiscal
SUPPORT          Soporte general
OTHER            Otro
```

## Reglas

```text
DOC-001 Todo documento debe pertenecer a una solicitud de pago.
DOC-002 Todo documento debe tener usuario que lo cargó.
DOC-003 El archivo es obligatorio.
DOC-004 No se elimina físicamente: se desactiva con is_active=False.
DOC-005 La ruta de carga queda organizada por solicitud.
```

## Validaciones

```bash
python manage.py check
python manage.py makemigrations --check --dry-run
python manage.py migrate
python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests apps.payment_documents
```
MD

cat > docs/05-modelo-datos/documentos_soporte_pago.md <<'MD'
# Modelo de datos - Documentos soporte de pago

## Entidad

```text
PaymentRequestDocument
```

## Relación principal

```text
PaymentRequest 1 ─── N PaymentRequestDocument
CustomUser      1 ─── N PaymentRequestDocument(uploaded_by)
```

## Estrategia de eliminación

No se elimina físicamente el documento desde la lógica funcional. Se usa:

```text
is_active = False
```

Esto permite trazabilidad, auditoría y control posterior.

## Ruta de archivo

```text
payment_requests/<payment_request_id>/documents/document.<ext>
```

## Notas de diseño

Este módulo queda desacoplado de la aprobación. La ruta formal de aprobación se implementará en el siguiente bloque funcional.
MD

printf '%s\n' 'OK: F1-P12 payment documents files generated.'
printf '%s\n' 'Next: run check, makemigrations --check --dry-run, migrate and tests.'
