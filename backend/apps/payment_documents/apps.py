from django.apps import AppConfig


class PaymentDocumentsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.payment_documents"
    label = "payment_documents"
    verbose_name = "Documentos de pago"
