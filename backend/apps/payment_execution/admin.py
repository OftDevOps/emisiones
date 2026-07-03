from django.contrib import admin

from .models import PaymentExecution


@admin.register(PaymentExecution)
class PaymentExecutionAdmin(admin.ModelAdmin):
    list_display = ("id", "payment_request", "paid_at", "paid_amount", "bank_reference", "executed_by", "created_at")
    list_filter = ("paid_at", "created_at")
    search_fields = ("bank_reference", "payment_request__concept", "executed_by__email")
    readonly_fields = ("created_at", "updated_at")
