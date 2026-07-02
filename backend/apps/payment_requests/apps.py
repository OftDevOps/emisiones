from django.apps import AppConfig


class PaymentRequestsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.payment_requests"
    label = "payment_requests"
    verbose_name = "Solicitudes de pago"
