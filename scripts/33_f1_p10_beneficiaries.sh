#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' '== F1-P10: Beneficiarios / proveedores =='

if [ ! -f "backend/manage.py" ]; then
  printf '%s\n' 'ERROR: run this script from repository root: /home/dchirinos/oftalmiIA/emisiones/emisiones' >&2
  exit 1
fi

mkdir -p backend/apps/beneficiaries/migrations backend/apps/beneficiaries/tests docs/05-modelo-datos docs/03-desarrollo

touch backend/apps/beneficiaries/__init__.py
touch backend/apps/beneficiaries/migrations/__init__.py
touch backend/apps/beneficiaries/tests/__init__.py

cat > backend/apps/beneficiaries/apps.py <<'PY'
from django.apps import AppConfig


class BeneficiariesConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.beneficiaries"
    label = "beneficiaries"
    verbose_name = "Beneficiarios y proveedores"
PY

cat > backend/apps/beneficiaries/models.py <<'PY'
from django.core.exceptions import ValidationError
from django.db import models


class ActiveModel(models.Model):
    is_active = models.BooleanField(default=True, verbose_name="activo")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="creado")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="actualizado")

    class Meta:
        abstract = True


class BeneficiaryType(models.TextChoices):
    SUPPLIER = "SUPPLIER", "Proveedor"
    EMPLOYEE = "EMPLOYEE", "Empleado"
    THIRD_PARTY = "THIRD_PARTY", "Tercero"
    GOVERNMENT = "GOVERNMENT", "Ente gubernamental"
    OTHER = "OTHER", "Otro"


class DocumentType(models.TextChoices):
    RIF = "RIF", "RIF"
    V = "V", "Cédula venezolano"
    E = "E", "Cédula extranjero"
    PASSPORT = "PASSPORT", "Pasaporte"
    OTHER = "OTHER", "Otro"


class Currency(models.TextChoices):
    VES = "VES", "Bolívar digital"
    USD = "USD", "Dólar estadounidense"
    EUR = "EUR", "Euro"


class AccountType(models.TextChoices):
    CHECKING = "CHECKING", "Corriente"
    SAVINGS = "SAVINGS", "Ahorro"
    INTERNATIONAL = "INTERNATIONAL", "Internacional"
    MOBILE_PAYMENT = "MOBILE_PAYMENT", "Pago móvil"
    OTHER = "OTHER", "Otro"


class Beneficiary(ActiveModel):
    company = models.ForeignKey(
        "organization.Company",
        on_delete=models.PROTECT,
        related_name="beneficiaries",
        verbose_name="empresa",
    )
    beneficiary_type = models.CharField(
        max_length=30,
        choices=BeneficiaryType.choices,
        default=BeneficiaryType.SUPPLIER,
        verbose_name="tipo de beneficiario",
    )
    document_type = models.CharField(
        max_length=20,
        choices=DocumentType.choices,
        default=DocumentType.RIF,
        verbose_name="tipo de documento",
    )
    document_number = models.CharField(max_length=40, verbose_name="número de documento")
    legal_name = models.CharField(max_length=220, verbose_name="nombre o razón social")
    trade_name = models.CharField(max_length=220, blank=True, verbose_name="nombre comercial")
    email = models.EmailField(blank=True, verbose_name="correo electrónico")
    phone = models.CharField(max_length=40, blank=True, verbose_name="teléfono")
    address = models.TextField(blank=True, verbose_name="dirección")
    notes = models.TextField(blank=True, verbose_name="observaciones")

    class Meta:
        ordering = ["company__name", "legal_name"]
        verbose_name = "beneficiario"
        verbose_name_plural = "beneficiarios"
        constraints = [
            models.UniqueConstraint(
                fields=["company", "document_type", "document_number"],
                name="uniq_beneficiary_document_by_company",
            )
        ]
        indexes = [
            models.Index(fields=["company", "beneficiary_type"], name="idx_beneficiary_company_type"),
            models.Index(fields=["document_number"], name="idx_beneficiary_document"),
        ]

    def clean(self):
        super().clean()
        if self.document_number:
            self.document_number = self.document_number.strip().upper()
        if self.legal_name:
            self.legal_name = " ".join(self.legal_name.split())
        if not self.document_number:
            raise ValidationError({"document_number": "El número de documento es obligatorio."})
        if not self.legal_name:
            raise ValidationError({"legal_name": "El nombre o razón social es obligatorio."})

    def save(self, *args, **kwargs):
        self.full_clean()
        super().save(*args, **kwargs)

    def __str__(self) -> str:
        return f"{self.legal_name} ({self.document_number})"


class BeneficiaryBankAccount(ActiveModel):
    beneficiary = models.ForeignKey(
        Beneficiary,
        on_delete=models.PROTECT,
        related_name="bank_accounts",
        verbose_name="beneficiario",
    )
    bank_name = models.CharField(max_length=160, verbose_name="banco")
    account_number = models.CharField(max_length=80, verbose_name="número de cuenta")
    account_holder = models.CharField(max_length=220, verbose_name="titular")
    account_type = models.CharField(
        max_length=30,
        choices=AccountType.choices,
        default=AccountType.CHECKING,
        verbose_name="tipo de cuenta",
    )
    currency = models.CharField(
        max_length=3,
        choices=Currency.choices,
        default=Currency.VES,
        verbose_name="moneda",
    )
    is_primary = models.BooleanField(default=False, verbose_name="principal")
    swift_code = models.CharField(max_length=40, blank=True, verbose_name="SWIFT")
    intermediary_bank = models.CharField(max_length=160, blank=True, verbose_name="banco intermediario")
    notes = models.TextField(blank=True, verbose_name="observaciones")

    class Meta:
        ordering = ["beneficiary__legal_name", "-is_primary", "bank_name"]
        verbose_name = "cuenta bancaria de beneficiario"
        verbose_name_plural = "cuentas bancarias de beneficiarios"
        constraints = [
            models.UniqueConstraint(
                fields=["beneficiary", "account_number", "currency"],
                name="uniq_bank_account_by_beneficiary_currency",
            )
        ]
        indexes = [
            models.Index(fields=["bank_name"], name="idx_bank_account_bank"),
            models.Index(fields=["account_number"], name="idx_bank_account_number"),
        ]

    def clean(self):
        super().clean()
        if self.bank_name:
            self.bank_name = " ".join(self.bank_name.split())
        if self.account_number:
            self.account_number = self.account_number.replace(" ", "").strip().upper()
        if self.account_holder:
            self.account_holder = " ".join(self.account_holder.split())
        if not self.bank_name:
            raise ValidationError({"bank_name": "El banco es obligatorio."})
        if not self.account_number:
            raise ValidationError({"account_number": "El número de cuenta es obligatorio."})
        if not self.account_holder:
            raise ValidationError({"account_holder": "El titular de la cuenta es obligatorio."})

    def save(self, *args, **kwargs):
        self.full_clean()
        super().save(*args, **kwargs)

    def __str__(self) -> str:
        return f"{self.beneficiary} - {self.bank_name} - {self.currency}"
PY

cat > backend/apps/beneficiaries/admin.py <<'PY'
from django.contrib import admin

from .models import Beneficiary, BeneficiaryBankAccount


class BeneficiaryBankAccountInline(admin.TabularInline):
    model = BeneficiaryBankAccount
    extra = 0
    fields = (
        "bank_name",
        "account_number",
        "account_holder",
        "account_type",
        "currency",
        "is_primary",
        "is_active",
    )


@admin.register(Beneficiary)
class BeneficiaryAdmin(admin.ModelAdmin):
    list_display = (
        "legal_name",
        "document_type",
        "document_number",
        "beneficiary_type",
        "company",
        "is_active",
    )
    search_fields = ("legal_name", "trade_name", "document_number", "email", "company__name")
    list_filter = ("company", "beneficiary_type", "document_type", "is_active")
    inlines = [BeneficiaryBankAccountInline]


@admin.register(BeneficiaryBankAccount)
class BeneficiaryBankAccountAdmin(admin.ModelAdmin):
    list_display = (
        "beneficiary",
        "bank_name",
        "account_number",
        "account_type",
        "currency",
        "is_primary",
        "is_active",
    )
    search_fields = (
        "beneficiary__legal_name",
        "beneficiary__document_number",
        "bank_name",
        "account_number",
        "account_holder",
    )
    list_filter = ("currency", "account_type", "bank_name", "is_primary", "is_active")
PY

cat > backend/apps/beneficiaries/migrations/0001_initial.py <<'PY'
# Generated for F1-P10 Beneficiaries
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        ("organization", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="Beneficiary",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("is_active", models.BooleanField(default=True, verbose_name="activo")),
                ("created_at", models.DateTimeField(auto_now_add=True, verbose_name="creado")),
                ("updated_at", models.DateTimeField(auto_now=True, verbose_name="actualizado")),
                ("beneficiary_type", models.CharField(choices=[("SUPPLIER", "Proveedor"), ("EMPLOYEE", "Empleado"), ("THIRD_PARTY", "Tercero"), ("GOVERNMENT", "Ente gubernamental"), ("OTHER", "Otro")], default="SUPPLIER", max_length=30, verbose_name="tipo de beneficiario")),
                ("document_type", models.CharField(choices=[("RIF", "RIF"), ("V", "Cédula venezolano"), ("E", "Cédula extranjero"), ("PASSPORT", "Pasaporte"), ("OTHER", "Otro")], default="RIF", max_length=20, verbose_name="tipo de documento")),
                ("document_number", models.CharField(max_length=40, verbose_name="número de documento")),
                ("legal_name", models.CharField(max_length=220, verbose_name="nombre o razón social")),
                ("trade_name", models.CharField(blank=True, max_length=220, verbose_name="nombre comercial")),
                ("email", models.EmailField(blank=True, max_length=254, verbose_name="correo electrónico")),
                ("phone", models.CharField(blank=True, max_length=40, verbose_name="teléfono")),
                ("address", models.TextField(blank=True, verbose_name="dirección")),
                ("notes", models.TextField(blank=True, verbose_name="observaciones")),
                ("company", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="beneficiaries", to="organization.company", verbose_name="empresa")),
            ],
            options={
                "verbose_name": "beneficiario",
                "verbose_name_plural": "beneficiarios",
                "ordering": ["company__name", "legal_name"],
            },
        ),
        migrations.CreateModel(
            name="BeneficiaryBankAccount",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("is_active", models.BooleanField(default=True, verbose_name="activo")),
                ("created_at", models.DateTimeField(auto_now_add=True, verbose_name="creado")),
                ("updated_at", models.DateTimeField(auto_now=True, verbose_name="actualizado")),
                ("bank_name", models.CharField(max_length=160, verbose_name="banco")),
                ("account_number", models.CharField(max_length=80, verbose_name="número de cuenta")),
                ("account_holder", models.CharField(max_length=220, verbose_name="titular")),
                ("account_type", models.CharField(choices=[("CHECKING", "Corriente"), ("SAVINGS", "Ahorro"), ("INTERNATIONAL", "Internacional"), ("MOBILE_PAYMENT", "Pago móvil"), ("OTHER", "Otro")], default="CHECKING", max_length=30, verbose_name="tipo de cuenta")),
                ("currency", models.CharField(choices=[("VES", "Bolívar digital"), ("USD", "Dólar estadounidense"), ("EUR", "Euro")], default="VES", max_length=3, verbose_name="moneda")),
                ("is_primary", models.BooleanField(default=False, verbose_name="principal")),
                ("swift_code", models.CharField(blank=True, max_length=40, verbose_name="SWIFT")),
                ("intermediary_bank", models.CharField(blank=True, max_length=160, verbose_name="banco intermediario")),
                ("notes", models.TextField(blank=True, verbose_name="observaciones")),
                ("beneficiary", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="bank_accounts", to="beneficiaries.beneficiary", verbose_name="beneficiario")),
            ],
            options={
                "verbose_name": "cuenta bancaria de beneficiario",
                "verbose_name_plural": "cuentas bancarias de beneficiarios",
                "ordering": ["beneficiary__legal_name", "-is_primary", "bank_name"],
            },
        ),
        migrations.AddIndex(
            model_name="beneficiary",
            index=models.Index(fields=["company", "beneficiary_type"], name="idx_beneficiary_company_type"),
        ),
        migrations.AddIndex(
            model_name="beneficiary",
            index=models.Index(fields=["document_number"], name="idx_beneficiary_document"),
        ),
        migrations.AddConstraint(
            model_name="beneficiary",
            constraint=models.UniqueConstraint(fields=("company", "document_type", "document_number"), name="uniq_beneficiary_document_by_company"),
        ),
        migrations.AddIndex(
            model_name="beneficiarybankaccount",
            index=models.Index(fields=["bank_name"], name="idx_bank_account_bank"),
        ),
        migrations.AddIndex(
            model_name="beneficiarybankaccount",
            index=models.Index(fields=["account_number"], name="idx_bank_account_number"),
        ),
        migrations.AddConstraint(
            model_name="beneficiarybankaccount",
            constraint=models.UniqueConstraint(fields=("beneficiary", "account_number", "currency"), name="uniq_bank_account_by_beneficiary_currency"),
        ),
    ]
PY

cat > backend/apps/beneficiaries/tests/test_models.py <<'PY'
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.test import TestCase

from apps.beneficiaries.models import (
    AccountType,
    Beneficiary,
    BeneficiaryBankAccount,
    BeneficiaryType,
    Currency,
    DocumentType,
)
from apps.organization.models import Company


class BeneficiaryModelsTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.other_company = Company.objects.create(name="Oftalmi Distribución", code="OFD")

    def test_create_supplier_beneficiary(self):
        beneficiary = Beneficiary.objects.create(
            company=self.company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            document_type=DocumentType.RIF,
            document_number="j-12345678-9",
            legal_name="  Proveedor   Médico  CA  ",
            email="proveedor@example.com",
        )

        self.assertEqual(beneficiary.document_number, "J-12345678-9")
        self.assertEqual(beneficiary.legal_name, "Proveedor Médico CA")
        self.assertEqual(str(beneficiary), "Proveedor Médico CA (J-12345678-9)")
        self.assertTrue(beneficiary.is_active)

    def test_document_must_be_unique_by_company(self):
        Beneficiary.objects.create(
            company=self.company,
            document_type=DocumentType.RIF,
            document_number="J-12345678-9",
            legal_name="Proveedor Uno",
        )

        with self.assertRaises(ValidationError):
            Beneficiary.objects.create(
                company=self.company,
                document_type=DocumentType.RIF,
                document_number="J-12345678-9",
                legal_name="Proveedor Duplicado",
            )

    def test_same_document_can_exist_in_another_company(self):
        Beneficiary.objects.create(
            company=self.company,
            document_type=DocumentType.RIF,
            document_number="J-12345678-9",
            legal_name="Proveedor Uno",
        )
        beneficiary = Beneficiary.objects.create(
            company=self.other_company,
            document_type=DocumentType.RIF,
            document_number="J-12345678-9",
            legal_name="Proveedor Otra Empresa",
        )

        self.assertEqual(beneficiary.company, self.other_company)

    def test_create_bank_account(self):
        beneficiary = Beneficiary.objects.create(
            company=self.company,
            document_type=DocumentType.RIF,
            document_number="J-12345678-9",
            legal_name="Proveedor Médico CA",
        )
        account = BeneficiaryBankAccount.objects.create(
            beneficiary=beneficiary,
            bank_name=" Banco Nacional ",
            account_number=" 0102 0000 0000 0000 0000 ",
            account_holder=" Proveedor Médico CA ",
            account_type=AccountType.CHECKING,
            currency=Currency.VES,
            is_primary=True,
        )

        self.assertEqual(account.bank_name, "Banco Nacional")
        self.assertEqual(account.account_number, "01020000000000000000")
        self.assertEqual(account.account_holder, "Proveedor Médico CA")
        self.assertTrue(account.is_primary)

    def test_bank_account_unique_by_beneficiary_number_and_currency(self):
        beneficiary = Beneficiary.objects.create(
            company=self.company,
            document_type=DocumentType.RIF,
            document_number="J-12345678-9",
            legal_name="Proveedor Médico CA",
        )
        BeneficiaryBankAccount.objects.create(
            beneficiary=beneficiary,
            bank_name="Banco Nacional",
            account_number="01020000000000000000",
            account_holder="Proveedor Médico CA",
            currency=Currency.VES,
        )

        with self.assertRaises(ValidationError):
            BeneficiaryBankAccount.objects.create(
                beneficiary=beneficiary,
                bank_name="Banco Nacional",
                account_number="0102 0000 0000 0000 0000",
                account_holder="Proveedor Médico CA",
                currency=Currency.VES,
            )

    def test_database_constraint_blocks_duplicate_document_if_clean_is_bypassed(self):
        Beneficiary.objects.create(
            company=self.company,
            document_type=DocumentType.RIF,
            document_number="J-12345678-9",
            legal_name="Proveedor Uno",
        )

        duplicate = Beneficiary(
            company=self.company,
            document_type=DocumentType.RIF,
            document_number="J-12345678-9",
            legal_name="Proveedor Duplicado",
        )

        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                Beneficiary.objects.bulk_create([duplicate])
PY

# Ensure app is installed.
python3 - <<'PY'
from pathlib import Path
p = Path('backend/config/settings/base.py')
s = p.read_text()
if '"apps.beneficiaries"' not in s and "'apps.beneficiaries'" not in s:
    markers = ['"apps.organization",', "'apps.organization',"]
    for marker in markers:
        if marker in s:
            quote = '"' if marker.startswith('"') else "'"
            s = s.replace(marker, f"{marker}\n    {quote}apps.beneficiaries{quote},")
            break
    else:
        raise SystemExit('ERROR: apps.organization not found in INSTALLED_APPS')
p.write_text(s)
PY

cat > docs/05-modelo-datos/beneficiarios_proveedores.md <<'MD'
# Beneficiarios y proveedores - F1-P10

## Objetivo

Crear la base maestra de beneficiarios y proveedores que será usada por las futuras solicitudes de pago.

## Modelos

```text
Beneficiary
BeneficiaryBankAccount
```

## Beneficiary

Representa a cualquier persona natural o jurídica que pueda recibir un pago.

Tipos incluidos:

```text
SUPPLIER       Proveedor
EMPLOYEE       Empleado
THIRD_PARTY    Tercero
GOVERNMENT     Ente gubernamental
OTHER          Otro
```

Campos principales:

```text
company
beneficiary_type
document_type
document_number
legal_name
trade_name
email
phone
address
notes
is_active
```

## BeneficiaryBankAccount

Representa una cuenta bancaria asociada a un beneficiario.

Campos principales:

```text
beneficiary
bank_name
account_number
account_holder
account_type
currency
is_primary
swift_code
intermediary_bank
notes
is_active
```

## Reglas funcionales

```text
BEN-001 Todo beneficiario pertenece a una empresa.
BEN-002 Un mismo documento no puede repetirse dentro de la misma empresa.
BEN-003 El mismo documento puede existir en otra empresa del grupo.
BEN-004 Un beneficiario puede tener varias cuentas bancarias.
BEN-005 Una cuenta bancaria no puede duplicarse para el mismo beneficiario y moneda.
BEN-006 La eliminación física queda protegida con PROTECT para preservar trazabilidad futura.
BEN-007 El maestro de beneficiarios será usado por solicitudes de pago desde F1-P11.
```

## Alcance excluido en este bloque

```text
No se crean solicitudes de pago.
No se crean aprobaciones.
No se crean documentos soporte.
No se crean APIs.
No se crean pantallas CRUD fuera del Django Admin.
```
MD

cat > docs/03-desarrollo/f1_p10_beneficiarios_proveedores.md <<'MD'
# F1-P10 - Beneficiarios / proveedores

## Estado

```text
F1-P10 Beneficiarios / proveedores — IMPLEMENTADO POR SCRIPT
```

## Archivos creados

```text
backend/apps/beneficiaries/apps.py
backend/apps/beneficiaries/models.py
backend/apps/beneficiaries/admin.py
backend/apps/beneficiaries/migrations/0001_initial.py
backend/apps/beneficiaries/tests/test_models.py
docs/05-modelo-datos/beneficiarios_proveedores.md
```

## Archivos modificados

```text
backend/config/settings/base.py
```

## Validaciones requeridas

```bash
python manage.py check
python manage.py makemigrations --check --dry-run
python manage.py migrate
python manage.py test apps.organization apps.accounts apps.beneficiaries
```

## Commit sugerido

```bash
git add .
git commit -m "feat: add beneficiaries and bank accounts"
git push -u origin feature/beneficiaries
```
MD

printf '%s\n' 'OK: F1-P10 beneficiaries files generated.'
printf '%s\n' 'Next: run Django check, makemigrations --check --dry-run, migrate and tests.'
