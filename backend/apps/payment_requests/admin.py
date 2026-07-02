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
