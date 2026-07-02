# Generated for F1-P13
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("payment_requests", "0002_paymentrequest_approval_statuses"),
    ]

    operations = [
        migrations.CreateModel(
            name="PaymentApprovalStep",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("sequence", models.PositiveSmallIntegerField(verbose_name="secuencia")),
                ("required_role", models.CharField(choices=[("ADMINISTRADOR", "Administrador"), ("SOLICITANTE", "Solicitante"), ("RESPONSABLE_UNIDAD", "Responsable de unidad"), ("FINANZAS", "Finanzas"), ("GERENCIA_GENERAL", "Gerencia General"), ("JUNTA_DIRECTIVA", "Junta Directiva"), ("CUENTAS_POR_PAGAR", "Cuentas por Pagar"), ("AUDITOR", "Auditor")], max_length=40, verbose_name="rol requerido")),
                ("status", models.CharField(choices=[("PENDING", "Pendiente"), ("APPROVED", "Aprobado"), ("REJECTED", "Rechazado"), ("SKIPPED", "Omitido")], default="PENDING", max_length=20, verbose_name="estado")),
                ("acted_at", models.DateTimeField(blank=True, null=True, verbose_name="fecha de acción")),
                ("comment", models.TextField(blank=True, verbose_name="comentario")),
                ("created_at", models.DateTimeField(auto_now_add=True, verbose_name="creado")),
                ("updated_at", models.DateTimeField(auto_now=True, verbose_name="actualizado")),
                ("acted_by", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, related_name="acted_approval_steps", to=settings.AUTH_USER_MODEL, verbose_name="ejecutado por")),
                ("assigned_to", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, related_name="assigned_approval_steps", to=settings.AUTH_USER_MODEL, verbose_name="asignado a")),
                ("payment_request", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="approval_steps", to="payment_requests.paymentrequest", verbose_name="solicitud de pago")),
            ],
            options={"verbose_name": "paso de aprobación", "verbose_name_plural": "pasos de aprobación", "ordering": ["payment_request_id", "sequence"], "unique_together": {("payment_request", "sequence")}},
        ),
        migrations.CreateModel(
            name="PaymentApprovalAction",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("action", models.CharField(choices=[("SUBMIT", "Enviar"), ("APPROVE", "Aprobar"), ("REJECT", "Rechazar"), ("CANCEL", "Cancelar"), ("COMMENT", "Comentario")], max_length=20, verbose_name="acción")),
                ("role", models.CharField(choices=[("ADMINISTRADOR", "Administrador"), ("SOLICITANTE", "Solicitante"), ("RESPONSABLE_UNIDAD", "Responsable de unidad"), ("FINANZAS", "Finanzas"), ("GERENCIA_GENERAL", "Gerencia General"), ("JUNTA_DIRECTIVA", "Junta Directiva"), ("CUENTAS_POR_PAGAR", "Cuentas por Pagar"), ("AUDITOR", "Auditor")], max_length=40, verbose_name="rol")),
                ("comment", models.TextField(blank=True, verbose_name="comentario")),
                ("created_at", models.DateTimeField(auto_now_add=True, verbose_name="creado")),
                ("payment_request", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="approval_actions", to="payment_requests.paymentrequest", verbose_name="solicitud de pago")),
                ("performed_by", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="payment_approval_actions", to=settings.AUTH_USER_MODEL, verbose_name="ejecutado por")),
                ("step", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, related_name="actions", to="payment_approvals.paymentapprovalstep", verbose_name="paso")),
            ],
            options={"verbose_name": "acción de aprobación", "verbose_name_plural": "acciones de aprobación", "ordering": ["payment_request_id", "created_at"]},
        ),
        migrations.AddIndex(model_name="paymentapprovalstep", index=models.Index(fields=["payment_request", "status"], name="paystep_req_st_idx")),
        migrations.AddIndex(model_name="paymentapprovalstep", index=models.Index(fields=["required_role", "status"], name="paystep_role_st_idx")),
        migrations.AddIndex(model_name="paymentapprovalaction", index=models.Index(fields=["payment_request", "action"], name="payact_req_action_idx")),
        migrations.AddIndex(model_name="paymentapprovalaction", index=models.Index(fields=["performed_by", "created_at"], name="payact_user_date_idx")),
    ]
