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
