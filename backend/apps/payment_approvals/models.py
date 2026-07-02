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
