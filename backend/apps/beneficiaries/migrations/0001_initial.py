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
