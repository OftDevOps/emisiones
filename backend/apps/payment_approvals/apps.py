from django.apps import AppConfig


class PaymentApprovalsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.payment_approvals"
    label = "payment_approvals"
    verbose_name = "Aprobaciones de pago"
