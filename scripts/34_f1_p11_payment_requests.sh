#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' '== F1-P11: Payment requests =='

if [ ! -f "backend/manage.py" ]; then
  printf '%s\n' 'ERROR: run this script from repository root: /home/dchirinos/oftalmiIA/emisiones/emisiones' >&2
  exit 1
fi

mkdir -p backend/apps/payment_requests/migrations backend/apps/payment_requests/tests docs/03-desarrollo docs/05-modelo-datos

touch backend/apps/payment_requests/__init__.py

touch backend/apps/payment_requests/migrations/__init__.py

touch backend/apps/payment_requests/tests/__init__.py

cat > backend/apps/payment_requests/apps.py <<'PY'
from django.apps import AppConfig


class PaymentRequestsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.payment_requests"
    label = "payment_requests"
    verbose_name = "Solicitudes de pago"
PY

cat > backend/apps/payment_requests/models.py <<'PY'
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
            models.Index(fields=["company", "status"]),
            models.Index(fields=["beneficiary", "status"]),
            models.Index(fields=["requested_by", "status"]),
            models.Index(fields=["created_at"]),
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
PY

cat > backend/apps/payment_requests/admin.py <<'PY'
from django.contrib import admin

from .models import PaymentRequest


@admin.register(PaymentRequest)
class PaymentRequestAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "company",
        "beneficiary",
        "requested_by",
        "amount",
        "currency",
        "status",
        "due_date",
        "created_at",
    )
    search_fields = (
        "concept",
        "description",
        "beneficiary__name",
        "beneficiary__document_number",
        "requested_by__email",
        "company__name",
    )
    list_filter = ("company", "currency", "status", "due_date", "created_at")
    readonly_fields = ("created_at", "updated_at")
    autocomplete_fields = ("company", "beneficiary", "requested_by")
PY

cat > backend/apps/payment_requests/migrations/0001_initial.py <<'PY'
# Generated for F1-P11
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        ("beneficiaries", "0001_initial"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("organization", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="PaymentRequest",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("amount", models.DecimalField(decimal_places=2, max_digits=18, verbose_name="monto")),
                ("currency", models.CharField(choices=[("VES", "Bolívares"), ("USD", "Dólares"), ("EUR", "Euros")], default="VES", max_length=3, verbose_name="moneda")),
                ("concept", models.CharField(max_length=220, verbose_name="concepto")),
                ("description", models.TextField(blank=True, verbose_name="descripción")),
                ("due_date", models.DateField(blank=True, null=True, verbose_name="fecha estimada de pago")),
                ("status", models.CharField(choices=[("DRAFT", "Borrador"), ("SUBMITTED", "Enviada"), ("CANCELLED", "Cancelada")], default="DRAFT", max_length=20, verbose_name="estado")),
                ("created_at", models.DateTimeField(auto_now_add=True, verbose_name="creado")),
                ("updated_at", models.DateTimeField(auto_now=True, verbose_name="actualizado")),
                ("beneficiary", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="payment_requests", to="beneficiaries.beneficiary", verbose_name="beneficiario")),
                ("company", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="payment_requests", to="organization.company", verbose_name="empresa")),
                ("requested_by", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="payment_requests", to=settings.AUTH_USER_MODEL, verbose_name="solicitado por")),
            ],
            options={
                "verbose_name": "solicitud de pago",
                "verbose_name_plural": "solicitudes de pago",
                "ordering": ["-created_at", "-id"],
                "indexes": [
                    models.Index(fields=["company", "status"], name="payment_req_company_status_idx"),
                    models.Index(fields=["beneficiary", "status"], name="payment_req_beneficiary_status_idx"),
                    models.Index(fields=["requested_by", "status"], name="payment_req_requested_status_idx"),
                    models.Index(fields=["created_at"], name="payment_req_created_at_idx"),
                ],
            },
        ),
    ]
PY

# Ensure payment_requests app is installed.
python3 - <<'PY'
from pathlib import Path
p = Path('backend/config/settings/base.py')
s = p.read_text()
if '"apps.payment_requests"' not in s and "'apps.payment_requests'" not in s:
    inserted = False
    for marker in ['"apps.beneficiaries",', "'apps.beneficiaries',"]:
        if marker in s:
            quote = '"' if marker.startswith('"') else "'"
            s = s.replace(marker, marker + f"\n    {quote}apps.payment_requests{quote},")
            inserted = True
            break
    if not inserted:
        raise SystemExit('ERROR: apps.beneficiaries not found in INSTALLED_APPS')
p.write_text(s)
PY

cat > backend/apps/payment_requests/tests/test_models.py <<'PY'
from decimal import Decimal

from django.core.exceptions import ValidationError
from django.test import TestCase

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary
from apps.organization.models import Company
from apps.payment_requests.models import Currency, PaymentRequest, PaymentRequestStatus


class PaymentRequestModelTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.user = CustomUser.objects.create_user(
            email="solicitante@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.company,
        )
        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            name="Proveedor Demo C.A.",
            document_number="J-12345678-9",
        )

    def test_create_payment_request_defaults_to_draft(self):
        request = PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.user,
            amount=Decimal("150.25"),
            currency=Currency.VES,
            concept="Pago de factura",
        )

        self.assertEqual(request.status, PaymentRequestStatus.DRAFT)
        self.assertEqual(request.amount, Decimal("150.25"))
        self.assertEqual(request.company, self.company)
        self.assertEqual(request.beneficiary, self.beneficiary)
        self.assertEqual(request.requested_by, self.user)

    def test_amount_must_be_greater_than_zero(self):
        request = PaymentRequest(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.user,
            amount=Decimal("0.00"),
            currency=Currency.VES,
            concept="Monto inválido",
        )

        with self.assertRaises(ValidationError):
            request.full_clean()

    def test_negative_amount_is_rejected_on_save(self):
        with self.assertRaises(ValidationError):
            PaymentRequest.objects.create(
                company=self.company,
                beneficiary=self.beneficiary,
                requested_by=self.user,
                amount=Decimal("-10.00"),
                currency=Currency.USD,
                concept="Monto negativo",
            )

    def test_beneficiary_must_match_company(self):
        other_company = Company.objects.create(name="Otra Empresa", code="OTR")
        other_beneficiary = Beneficiary.objects.create(
            company=other_company,
            name="Proveedor Otra Empresa",
            document_number="J-98765432-1",
        )
        request = PaymentRequest(
            company=self.company,
            beneficiary=other_beneficiary,
            requested_by=self.user,
            amount=Decimal("100.00"),
            concept="Empresa inconsistente",
        )

        with self.assertRaises(ValidationError):
            request.full_clean()

    def test_string_representation_contains_business_context(self):
        request = PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.user,
            amount=Decimal("250.00"),
            currency=Currency.USD,
            concept="Servicio técnico",
        )

        self.assertIn("Laboratorios Oftalmi", str(request))
        self.assertIn("Proveedor Demo", str(request))
        self.assertIn("250.00", str(request))
        self.assertIn("USD", str(request))
PY

cat > docs/03-desarrollo/f1_p11_solicitudes_pago.md <<'MD'
# F1-P11 - Solicitudes de pago

## Objetivo

Crear la base operativa mínima de solicitudes de pago del Sistema de Rutas de Pago Oftalmi.

Este punto no implementa todavía aprobación, documentos soporte, workflow ni bandejas por rol. Su alcance es dejar el modelo principal estable para construir encima.

## App creada

```text
apps.payment_requests
```

## Modelo creado

```text
PaymentRequest
```

## Campos principales

```text
company
beneficiary
requested_by
amount
currency
concept
description
due_date
status
created_at
updated_at
```

## Estados iniciales

```text
DRAFT      Borrador
SUBMITTED  Enviada
CANCELLED  Cancelada
```

## Reglas implementadas

```text
PAY-001 Toda solicitud debe pertenecer a una empresa.
PAY-002 Toda solicitud debe tener beneficiario.
PAY-003 Toda solicitud debe tener usuario solicitante.
PAY-004 El monto debe ser mayor que cero.
PAY-005 Toda solicitud nace en estado DRAFT.
PAY-006 El beneficiario debe pertenecer a la misma empresa de la solicitud.
```

## Validaciones esperadas

```bash
python manage.py check
python manage.py makemigrations --check --dry-run
python manage.py migrate
python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests
```

## Resultado esperado

```text
System check identified no issues
No changes detected
Applying payment_requests.0001_initial... OK
Tests OK
```
MD

cat > docs/05-modelo-datos/solicitudes_pago.md <<'MD'
# Modelo de datos - Solicitudes de pago

## Propósito

El modelo `PaymentRequest` representa la solicitud base que inicia una ruta de pago.

## Relaciones

```text
PaymentRequest.company        -> organization.Company
PaymentRequest.beneficiary    -> beneficiaries.Beneficiary
PaymentRequest.requested_by   -> accounts.CustomUser
```

## Decisiones de diseño

```text
1. La empresa es obligatoria para soportar operación multiempresa.
2. El beneficiario es obligatorio porque toda solicitud debe tener destino de pago.
3. El solicitante es obligatorio para trazabilidad y futura segregación por rol.
4. El monto se valida a nivel de modelo con full_clean() antes de guardar.
5. Los estados se mantienen mínimos para no adelantar el workflow de aprobación.
6. Se protege la eliminación física de empresa, beneficiario y usuario si existen solicitudes asociadas.
```

## Estados

```text
DRAFT      Solicitud creada pero no enviada.
SUBMITTED  Solicitud enviada para su procesamiento futuro.
CANCELLED  Solicitud cancelada.
```

## Próximos puntos relacionados

```text
F1-P12 Documentos soporte
F1-P13 Ruta básica de aprobación
F1-P14 Bandejas por rol
F1-P15 Auditoría de cambios de solicitud
```
MD

printf '%s\n' 'OK: F1-P11 payment request files generated.'
printf '%s\n' 'Next: docker compose exec backend python manage.py check && docker compose exec backend python manage.py migrate && docker compose exec backend python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests'
