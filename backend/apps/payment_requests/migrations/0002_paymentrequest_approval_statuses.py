# Generated for F1-P13
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("payment_requests", "0001_initial"),
    ]

    operations = [
        migrations.AlterField(
            model_name="paymentrequest",
            name="status",
            field=models.CharField(
                choices=[
                    ("DRAFT", "Borrador"),
                    ("SUBMITTED", "Enviada"),
                    ("UNIT_REVIEW", "Revisión unidad"),
                    ("FINANCE_REVIEW", "Revisión finanzas"),
                    ("MANAGEMENT_REVIEW", "Revisión gerencia"),
                    ("APPROVED", "Aprobada"),
                    ("REJECTED", "Rechazada"),
                    ("CANCELLED", "Cancelada"),
                ],
                default="DRAFT",
                max_length=30,
                verbose_name="estado",
            ),
        ),
    ]
