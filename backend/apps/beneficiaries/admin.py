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
