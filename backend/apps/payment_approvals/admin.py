from django.contrib import admin

from .models import PaymentApprovalAction, PaymentApprovalStep


@admin.register(PaymentApprovalStep)
class PaymentApprovalStepAdmin(admin.ModelAdmin):
    list_display = ("payment_request", "sequence", "required_role", "status", "assigned_to", "acted_by", "acted_at")
    search_fields = ("payment_request__concept", "required_role", "assigned_to__email", "acted_by__email")
    list_filter = ("status", "required_role", "acted_at")
    readonly_fields = ("created_at", "updated_at")


@admin.register(PaymentApprovalAction)
class PaymentApprovalActionAdmin(admin.ModelAdmin):
    list_display = ("payment_request", "action", "performed_by", "role", "created_at")
    search_fields = ("payment_request__concept", "performed_by__email", "comment")
    list_filter = ("action", "role", "created_at")
    readonly_fields = ("created_at",)
