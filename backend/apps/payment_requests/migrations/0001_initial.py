# Generated for F1-P11
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        ("beneficiaries", "0001_initial"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("organization", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="PaymentRequest",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("amount", models.DecimalField(decimal_places=2, max_digits=18, verbose_name="monto")),
                ("currency", models.CharField(choices=[("VES", "Bolívares"), ("USD", "Dólares"), ("EUR", "Euros")], default="VES", max_length=3, verbose_name="moneda")),
                ("concept", models.CharField(max_length=220, verbose_name="concepto")),
                ("description", models.TextField(blank=True, verbose_name="descripción")),
                ("due_date", models.DateField(blank=True, null=True, verbose_name="fecha estimada de pago")),
                ("status", models.CharField(choices=[("DRAFT", "Borrador"), ("SUBMITTED", "Enviada"), ("CANCELLED", "Cancelada")], default="DRAFT", max_length=20, verbose_name="estado")),
                ("created_at", models.DateTimeField(auto_now_add=True, verbose_name="creado")),
                ("updated_at", models.DateTimeField(auto_now=True, verbose_name="actualizado")),
                ("beneficiary", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="payment_requests", to="beneficiaries.beneficiary", verbose_name="beneficiario")),
                ("company", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="payment_requests", to="organization.company", verbose_name="empresa")),
                ("requested_by", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="payment_requests", to=settings.AUTH_USER_MODEL, verbose_name="solicitado por")),
            ],
            options={
                "verbose_name": "solicitud de pago",
                "verbose_name_plural": "solicitudes de pago",
                "ordering": ["-created_at", "-id"],
                "indexes": [
                    models.Index(fields=["company", "status"], name="payreq_comp_st_idx"),
                    models.Index(fields=["beneficiary", "status"], name="payreq_ben_st_idx"),
                    models.Index(fields=["requested_by", "status"], name="payreq_req_st_idx"),
                    models.Index(fields=["created_at"], name="payreq_created_idx"),
                ],
            },
        ),
    ]
