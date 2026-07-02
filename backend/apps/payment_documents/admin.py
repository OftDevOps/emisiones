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
