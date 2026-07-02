from decimal import Decimal

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models


class PaymentRequestStatus(models.TextChoices):
    DRAFT = "DRAFT", "Borrador"
    SUBMITTED = "SUBMITTED", "Enviada"
    UNIT_REVIEW = "UNIT_REVIEW", "Revisión unidad"
    FINANCE_REVIEW = "FINANCE_REVIEW", "Revisión finanzas"
    MANAGEMENT_REVIEW = "MANAGEMENT_REVIEW", "Revisión gerencia"
    APPROVED = "APPROVED", "Aprobada"
    REJECTED = "REJECTED", "Rechazada"
    CANCELLED = "CANCELLED", "Cancelada"


class Currency(models.TextChoices):
    VES = "VES", "Bolívares"
    USD = "USD", "Dólares"
    EUR = "EUR", "Euros"


class PaymentRequest(models.Model):
    company = models.ForeignKey(
        "organization.Company",
        on_delete=models.PROTECT,
        related_name="payment_requests",
        verbose_name="empresa",
    )
    beneficiary = models.ForeignKey(
        "beneficiaries.Beneficiary",
        on_delete=models.PROTECT,
        related_name="payment_requests",
        verbose_name="beneficiario",
    )
    requested_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="payment_requests",
        verbose_name="solicitado por",
    )
    amount = models.DecimalField(max_digits=18, decimal_places=2, verbose_name="monto")
    currency = models.CharField(
        max_length=3,
        choices=Currency.choices,
        default=Currency.VES,
        verbose_name="moneda",
    )
    concept = models.CharField(max_length=220, verbose_name="concepto")
    description = models.TextField(blank=True, verbose_name="descripción")
    due_date = models.DateField(null=True, blank=True, verbose_name="fecha estimada de pago")
    status = models.CharField(
        max_length=20,
        choices=PaymentRequestStatus.choices,
        default=PaymentRequestStatus.DRAFT,
        verbose_name="estado",
    )
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="creado")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="actualizado")

    class Meta:
        ordering = ["-created_at", "-id"]
        verbose_name = "solicitud de pago"
        verbose_name_plural = "solicitudes de pago"
        indexes = [
            models.Index(fields=["company", "status"], name="payreq_comp_st_idx"),
            models.Index(fields=["beneficiary", "status"], name="payreq_ben_st_idx"),
            models.Index(fields=["requested_by", "status"], name="payreq_req_st_idx"),
            models.Index(fields=["created_at"], name="payreq_created_idx"),
        ]

    def clean(self):
        super().clean()
        if self.amount is not None and self.amount <= Decimal("0"):
            raise ValidationError({"amount": "El monto debe ser mayor que cero."})

        if self.company_id and self.beneficiary_id:
            beneficiary_company_id = getattr(self.beneficiary, "company_id", None)
            if beneficiary_company_id and beneficiary_company_id != self.company_id:
                raise ValidationError(
                    {"beneficiary": "El beneficiario debe pertenecer a la misma empresa de la solicitud."}
                )

    def save(self, *args, **kwargs):
        self.full_clean()
        return super().save(*args, **kwargs)

    def submit_for_approval(self, user):
        if self.status != PaymentRequestStatus.DRAFT:
            from django.core.exceptions import ValidationError
            raise ValidationError("Solo solicitudes en borrador pueden enviarse a aprobación.")
        self.status = PaymentRequestStatus.UNIT_REVIEW
        self.save(update_fields=["status", "updated_at"])

        from apps.accounts.models import UserRole
        from apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction, PaymentApprovalStep

        default_steps = [
            (1, UserRole.RESPONSABLE_UNIDAD),
            (2, UserRole.FINANZAS),
            (3, UserRole.GERENCIA_GENERAL),
        ]
        for sequence, required_role in default_steps:
            PaymentApprovalStep.objects.get_or_create(
                payment_request=self,
                sequence=sequence,
                defaults={"required_role": required_role},
            )
        PaymentApprovalAction.objects.create(
            payment_request=self,
            action=ApprovalActionType.SUBMIT,
            performed_by=user,
            role=user.role,
            comment="Solicitud enviada a aprobación.",
        )

    def refresh_approval_status(self):
        steps = list(self.approval_steps.order_by("sequence"))
        if not steps:
            return

        from apps.payment_approvals.models import ApprovalStepStatus

        if any(step.status == ApprovalStepStatus.REJECTED for step in steps):
            self.status = PaymentRequestStatus.REJECTED
        elif all(step.status == ApprovalStepStatus.APPROVED for step in steps):
            self.status = PaymentRequestStatus.APPROVED
        else:
            pending = next((step for step in steps if step.status == ApprovalStepStatus.PENDING), None)
            if pending and pending.required_role == "FINANZAS":
                self.status = PaymentRequestStatus.FINANCE_REVIEW
            elif pending and pending.required_role == "GERENCIA_GENERAL":
                self.status = PaymentRequestStatus.MANAGEMENT_REVIEW
            else:
                self.status = PaymentRequestStatus.UNIT_REVIEW
        self.save(update_fields=["status", "updated_at"])

    def __str__(self) -> str:
        return f"{self.company} - {self.beneficiary} - {self.amount} {self.currency}"
