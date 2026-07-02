#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' '== F1-P13: Basic approval route =='

if [ ! -f "backend/manage.py" ]; then
  printf '%s\n' 'ERROR: run this script from repository root: /home/dchirinos/oftalmiIA/emisiones/emisiones' >&2
  exit 1
fi

mkdir -p backend/apps/payment_approvals/migrations backend/apps/payment_approvals/tests docs/03-desarrollo docs/05-modelo-datos

touch backend/apps/payment_approvals/__init__.py

touch backend/apps/payment_approvals/migrations/__init__.py

touch backend/apps/payment_approvals/tests/__init__.py

cat > backend/apps/payment_approvals/apps.py <<'PY'
from django.apps import AppConfig


class PaymentApprovalsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.payment_approvals"
    label = "payment_approvals"
    verbose_name = "Aprobaciones de pago"
PY

cat > backend/apps/payment_approvals/models.py <<'PY'
from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
from django.utils import timezone

from apps.accounts.models import UserRole
from apps.payment_requests.models import PaymentRequest, PaymentRequestStatus


class ApprovalStepStatus(models.TextChoices):
    PENDING = "PENDING", "Pendiente"
    APPROVED = "APPROVED", "Aprobado"
    REJECTED = "REJECTED", "Rechazado"
    SKIPPED = "SKIPPED", "Omitido"


class ApprovalActionType(models.TextChoices):
    SUBMIT = "SUBMIT", "Enviar"
    APPROVE = "APPROVE", "Aprobar"
    REJECT = "REJECT", "Rechazar"
    CANCEL = "CANCEL", "Cancelar"
    COMMENT = "COMMENT", "Comentario"


class PaymentApprovalStep(models.Model):
    payment_request = models.ForeignKey(
        PaymentRequest,
        on_delete=models.PROTECT,
        related_name="approval_steps",
        verbose_name="solicitud de pago",
    )
    sequence = models.PositiveSmallIntegerField(verbose_name="secuencia")
    required_role = models.CharField(
        max_length=40,
        choices=UserRole.choices,
        verbose_name="rol requerido",
    )
    status = models.CharField(
        max_length=20,
        choices=ApprovalStepStatus.choices,
        default=ApprovalStepStatus.PENDING,
        verbose_name="estado",
    )
    assigned_to = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="assigned_approval_steps",
        null=True,
        blank=True,
        verbose_name="asignado a",
    )
    acted_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="acted_approval_steps",
        null=True,
        blank=True,
        verbose_name="ejecutado por",
    )
    acted_at = models.DateTimeField(null=True, blank=True, verbose_name="fecha de acción")
    comment = models.TextField(blank=True, verbose_name="comentario")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="creado")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="actualizado")

    class Meta:
        ordering = ["payment_request_id", "sequence"]
        unique_together = [("payment_request", "sequence")]
        indexes = [
            models.Index(fields=["payment_request", "status"], name="paystep_req_st_idx"),
            models.Index(fields=["required_role", "status"], name="paystep_role_st_idx"),
        ]
        verbose_name = "paso de aprobación"
        verbose_name_plural = "pasos de aprobación"

    def __str__(self) -> str:
        return f"{self.payment_request_id} - {self.sequence} - {self.required_role}"

    def approve(self, user, comment=""):
        if self.status != ApprovalStepStatus.PENDING:
            raise ValidationError("Solo se pueden aprobar pasos pendientes.")
        if user.role != self.required_role and not user.is_superuser:
            raise ValidationError("El usuario no tiene el rol requerido para aprobar este paso.")
        self.status = ApprovalStepStatus.APPROVED
        self.acted_by = user
        self.acted_at = timezone.now()
        self.comment = comment or self.comment
        self.save(update_fields=["status", "acted_by", "acted_at", "comment", "updated_at"])
        PaymentApprovalAction.objects.create(
            payment_request=self.payment_request,
            step=self,
            action=ApprovalActionType.APPROVE,
            performed_by=user,
            role=user.role,
            comment=comment,
        )
        self.payment_request.refresh_approval_status()

    def reject(self, user, comment):
        if self.status != ApprovalStepStatus.PENDING:
            raise ValidationError("Solo se pueden rechazar pasos pendientes.")
        if not comment or not comment.strip():
            raise ValidationError("El rechazo exige comentario.")
        if user.role != self.required_role and not user.is_superuser:
            raise ValidationError("El usuario no tiene el rol requerido para rechazar este paso.")
        self.status = ApprovalStepStatus.REJECTED
        self.acted_by = user
        self.acted_at = timezone.now()
        self.comment = comment.strip()
        self.save(update_fields=["status", "acted_by", "acted_at", "comment", "updated_at"])
        PaymentApprovalAction.objects.create(
            payment_request=self.payment_request,
            step=self,
            action=ApprovalActionType.REJECT,
            performed_by=user,
            role=user.role,
            comment=self.comment,
        )
        self.payment_request.status = PaymentRequestStatus.REJECTED
        self.payment_request.save(update_fields=["status", "updated_at"])


class PaymentApprovalAction(models.Model):
    payment_request = models.ForeignKey(
        PaymentRequest,
        on_delete=models.PROTECT,
        related_name="approval_actions",
        verbose_name="solicitud de pago",
    )
    step = models.ForeignKey(
        PaymentApprovalStep,
        on_delete=models.PROTECT,
        related_name="actions",
        null=True,
        blank=True,
        verbose_name="paso",
    )
    action = models.CharField(
        max_length=20,
        choices=ApprovalActionType.choices,
        verbose_name="acción",
    )
    performed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="payment_approval_actions",
        verbose_name="ejecutado por",
    )
    role = models.CharField(max_length=40, choices=UserRole.choices, verbose_name="rol")
    comment = models.TextField(blank=True, verbose_name="comentario")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="creado")

    class Meta:
        ordering = ["payment_request_id", "created_at"]
        indexes = [
            models.Index(fields=["payment_request", "action"], name="payact_req_action_idx"),
            models.Index(fields=["performed_by", "created_at"], name="payact_user_date_idx"),
        ]
        verbose_name = "acción de aprobación"
        verbose_name_plural = "acciones de aprobación"

    def clean(self):
        super().clean()
        if self.action == ApprovalActionType.REJECT and not self.comment.strip():
            raise ValidationError({"comment": "El rechazo exige comentario."})

    def save(self, *args, **kwargs):
        self.full_clean()
        super().save(*args, **kwargs)

    def __str__(self) -> str:
        return f"{self.payment_request_id} - {self.action} - {self.performed_by}"
PY

cat > backend/apps/payment_approvals/admin.py <<'PY'
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
PY

cat > backend/apps/payment_approvals/migrations/0001_initial.py <<'PY'
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
PY

cat > backend/apps/payment_requests/migrations/0002_paymentrequest_approval_statuses.py <<'PY'
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
PY

python3 - <<'PY'
from pathlib import Path
p = Path('backend/config/settings/base.py')
s = p.read_text()
if '"apps.payment_approvals"' not in s and "'apps.payment_approvals'" not in s:
    marker = '"apps.payment_documents",'
    if marker in s:
        s = s.replace(marker, '"apps.payment_documents",\n    "apps.payment_approvals",')
    else:
        marker = "'apps.payment_documents',"
        if marker in s:
            s = s.replace(marker, "'apps.payment_documents',\n    'apps.payment_approvals',")
        else:
            marker = '"apps.payment_requests",'
            if marker in s:
                s = s.replace(marker, '"apps.payment_requests",\n    "apps.payment_approvals",')
            else:
                raise SystemExit('ERROR: payment app marker not found in INSTALLED_APPS')
p.write_text(s)
PY

python3 - <<'PY'
from pathlib import Path
p = Path('backend/apps/payment_requests/models.py')
s = p.read_text()
old = '''class PaymentRequestStatus(models.TextChoices):\n    DRAFT = "DRAFT", "Borrador"\n    SUBMITTED = "SUBMITTED", "Enviada"\n    CANCELLED = "CANCELLED", "Cancelada"\n'''
new = '''class PaymentRequestStatus(models.TextChoices):\n    DRAFT = "DRAFT", "Borrador"\n    SUBMITTED = "SUBMITTED", "Enviada"\n    UNIT_REVIEW = "UNIT_REVIEW", "Revisión unidad"\n    FINANCE_REVIEW = "FINANCE_REVIEW", "Revisión finanzas"\n    MANAGEMENT_REVIEW = "MANAGEMENT_REVIEW", "Revisión gerencia"\n    APPROVED = "APPROVED", "Aprobada"\n    REJECTED = "REJECTED", "Rechazada"\n    CANCELLED = "CANCELLED", "Cancelada"\n'''
if old in s:
    s = s.replace(old, new)
elif 'UNIT_REVIEW = "UNIT_REVIEW"' not in s:
    raise SystemExit('ERROR: PaymentRequestStatus block not found')

if 'def submit_for_approval(' not in s:
    insert = '''\n    def submit_for_approval(self, user):\n        if self.status != PaymentRequestStatus.DRAFT:\n            from django.core.exceptions import ValidationError\n            raise ValidationError("Solo solicitudes en borrador pueden enviarse a aprobación.")\n        self.status = PaymentRequestStatus.UNIT_REVIEW\n        self.save(update_fields=["status", "updated_at"])\n\n        from apps.accounts.models import UserRole\n        from apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction, PaymentApprovalStep\n\n        default_steps = [\n            (1, UserRole.RESPONSABLE_UNIDAD),\n            (2, UserRole.FINANZAS),\n            (3, UserRole.GERENCIA_GENERAL),\n        ]\n        for sequence, required_role in default_steps:\n            PaymentApprovalStep.objects.get_or_create(\n                payment_request=self,\n                sequence=sequence,\n                defaults={"required_role": required_role},\n            )\n        PaymentApprovalAction.objects.create(\n            payment_request=self,\n            action=ApprovalActionType.SUBMIT,\n            performed_by=user,\n            role=user.role,\n            comment="Solicitud enviada a aprobación.",\n        )\n\n    def refresh_approval_status(self):\n        steps = list(self.approval_steps.order_by("sequence"))\n        if not steps:\n            return\n\n        from apps.payment_approvals.models import ApprovalStepStatus\n\n        if any(step.status == ApprovalStepStatus.REJECTED for step in steps):\n            self.status = PaymentRequestStatus.REJECTED\n        elif all(step.status == ApprovalStepStatus.APPROVED for step in steps):\n            self.status = PaymentRequestStatus.APPROVED\n        else:\n            pending = next((step for step in steps if step.status == ApprovalStepStatus.PENDING), None)\n            if pending and pending.required_role == "FINANZAS":\n                self.status = PaymentRequestStatus.FINANCE_REVIEW\n            elif pending and pending.required_role == "GERENCIA_GENERAL":\n                self.status = PaymentRequestStatus.MANAGEMENT_REVIEW\n            else:\n                self.status = PaymentRequestStatus.UNIT_REVIEW\n        self.save(update_fields=["status", "updated_at"])\n'''
    marker = '\n    def __str__(self) -> str:\n'
    if marker not in s:
        raise SystemExit('ERROR: __str__ marker not found in PaymentRequest model')
    s = s.replace(marker, insert + marker)

p.write_text(s)
PY

cat > backend/apps/payment_approvals/tests/test_models.py <<'PY'
from decimal import Decimal

from django.core.exceptions import ValidationError
from django.test import TestCase

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary, BeneficiaryType
from apps.organization.models import Company
from apps.payment_approvals.models import ApprovalActionType, ApprovalStepStatus, PaymentApprovalAction, PaymentApprovalStep
from apps.payment_requests.models import Currency, PaymentRequest, PaymentRequestStatus


class PaymentApprovalRouteTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.requester = CustomUser.objects.create_user(
            email="solicitante.aprobacion@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.company,
        )
        self.unit_manager = CustomUser.objects.create_user(
            email="unidad.aprobacion@oftalmi.com",
            password="test-pass-123",
            role=UserRole.RESPONSABLE_UNIDAD,
            primary_company=self.company,
        )
        self.finance = CustomUser.objects.create_user(
            email="finanzas.aprobacion@oftalmi.com",
            password="test-pass-123",
            role=UserRole.FINANZAS,
            primary_company=self.company,
        )
        self.management = CustomUser.objects.create_user(
            email="gerencia.aprobacion@oftalmi.com",
            password="test-pass-123",
            role=UserRole.GERENCIA_GENERAL,
            primary_company=self.company,
        )
        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Aprobación C.A.",
            document_number="J-33333333-3",
            email="proveedor.aprobacion@example.com",
        )
        self.payment_request = PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.requester,
            amount=Decimal("250.00"),
            currency=Currency.VES,
            concept="Pago para aprobación",
        )

    def test_submit_creates_default_approval_route(self):
        self.payment_request.submit_for_approval(self.requester)
        self.payment_request.refresh_from_db()

        self.assertEqual(self.payment_request.status, PaymentRequestStatus.UNIT_REVIEW)
        self.assertEqual(self.payment_request.approval_steps.count(), 3)
        self.assertEqual(self.payment_request.approval_actions.count(), 1)
        self.assertEqual(self.payment_request.approval_actions.first().action, ApprovalActionType.SUBMIT)

    def test_submit_only_from_draft(self):
        self.payment_request.status = PaymentRequestStatus.CANCELLED
        self.payment_request.save(update_fields=["status", "updated_at"])

        with self.assertRaises(ValidationError):
            self.payment_request.submit_for_approval(self.requester)

    def test_approval_advances_status_by_role(self):
        self.payment_request.submit_for_approval(self.requester)

        step1 = self.payment_request.approval_steps.get(sequence=1)
        step1.approve(self.unit_manager, "Unidad conforme")
        self.payment_request.refresh_from_db()
        self.assertEqual(self.payment_request.status, PaymentRequestStatus.FINANCE_REVIEW)

        step2 = self.payment_request.approval_steps.get(sequence=2)
        step2.approve(self.finance, "Finanzas conforme")
        self.payment_request.refresh_from_db()
        self.assertEqual(self.payment_request.status, PaymentRequestStatus.MANAGEMENT_REVIEW)

        step3 = self.payment_request.approval_steps.get(sequence=3)
        step3.approve(self.management, "Gerencia aprueba")
        self.payment_request.refresh_from_db()
        self.assertEqual(self.payment_request.status, PaymentRequestStatus.APPROVED)

    def test_wrong_role_cannot_approve_step(self):
        self.payment_request.submit_for_approval(self.requester)
        step1 = self.payment_request.approval_steps.get(sequence=1)

        with self.assertRaises(ValidationError):
            step1.approve(self.finance, "Intento inválido")

    def test_reject_requires_comment(self):
        self.payment_request.submit_for_approval(self.requester)
        step1 = self.payment_request.approval_steps.get(sequence=1)

        with self.assertRaises(ValidationError):
            step1.reject(self.unit_manager, "")

    def test_rejection_marks_request_as_rejected(self):
        self.payment_request.submit_for_approval(self.requester)
        step1 = self.payment_request.approval_steps.get(sequence=1)
        step1.reject(self.unit_manager, "Falta soporte")
        self.payment_request.refresh_from_db()

        self.assertEqual(self.payment_request.status, PaymentRequestStatus.REJECTED)
        self.assertEqual(step1.status, ApprovalStepStatus.REJECTED)
        self.assertEqual(
            PaymentApprovalAction.objects.filter(
                payment_request=self.payment_request,
                action=ApprovalActionType.REJECT,
            ).count(),
            1,
        )
PY

cat > docs/03-desarrollo/f1_p13_ruta_basica_aprobacion.md <<'MD'
# F1-P13 Ruta básica de aprobación

## Objetivo

Agregar una ruta básica y auditable para aprobar solicitudes de pago.

## Alcance implementado

- App `payment_approvals`.
- Modelo `PaymentApprovalStep`.
- Modelo `PaymentApprovalAction`.
- Estados extendidos en `PaymentRequest`.
- Método `submit_for_approval`.
- Método `refresh_approval_status`.
- Admin básico.
- Pruebas de flujo mínimo.

## Flujo base

```text
DRAFT
  -> UNIT_REVIEW
  -> FINANCE_REVIEW
  -> MANAGEMENT_REVIEW
  -> APPROVED
```

Rechazo:

```text
Cualquier paso pendiente rechazado -> REJECTED
```

## Roles de la ruta inicial

```text
1 RESPONSABLE_UNIDAD
2 FINANZAS
3 GERENCIA_GENERAL
```

## Reglas

```text
APP-001 Solo una solicitud en DRAFT puede enviarse a aprobación.
APP-002 El envío genera los pasos base de aprobación.
APP-003 Cada aprobación registra usuario, rol, fecha y comentario opcional.
APP-004 Todo rechazo exige comentario.
APP-005 Un usuario no puede aprobar un paso si no tiene el rol requerido.
APP-006 Si todos los pasos están aprobados, la solicitud pasa a APPROVED.
APP-007 Si cualquier paso es rechazado, la solicitud pasa a REJECTED.
```
MD

cat > docs/05-modelo-datos/ruta_basica_aprobacion.md <<'MD'
# Modelo de datos - Ruta básica de aprobación

## PaymentApprovalStep

Representa un paso requerido dentro de la ruta de aprobación de una solicitud.

Campos principales:

```text
payment_request
sequence
required_role
status
assigned_to
acted_by
acted_at
comment
created_at
updated_at
```

## PaymentApprovalAction

Representa la bitácora de acciones ejecutadas sobre la ruta.

Campos principales:

```text
payment_request
step
action
performed_by
role
comment
created_at
```

## Estados agregados a PaymentRequest

```text
DRAFT
SUBMITTED
UNIT_REVIEW
FINANCE_REVIEW
MANAGEMENT_REVIEW
APPROVED
REJECTED
CANCELLED
```
MD

printf '%s\n' 'OK: F1-P13 basic approval route files generated.'
printf '%s\n' 'Next: run Django check, makemigrations --check --dry-run, migrate, and tests.'
