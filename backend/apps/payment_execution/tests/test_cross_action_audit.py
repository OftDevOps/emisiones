from datetime import date
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.db import models
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from apps.accounts.models import UserRole
from apps.beneficiaries.models import Beneficiary
from apps.organization.models import Company
from apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction
from apps.payment_execution.models import PaymentExecution
from apps.payment_requests.models import PaymentRequest, PaymentRequestStatus


def _field_names(model):
    return {field.name for field in model._meta.fields}


def _first_existing(model, candidates):
    names = _field_names(model)
    for candidate in candidates:
        if candidate in names:
            return candidate
    return None


def _enum_value(enum_class, preferred=None):
    if preferred and hasattr(enum_class, preferred):
        return getattr(enum_class, preferred)
    return enum_class.choices[0][0]


def _fallback_value(field):
    if isinstance(field, models.CharField):
        if field.choices:
            return field.choices[0][0]
        return f"TEST-{field.name}"[: field.max_length or 50]
    if isinstance(field, models.TextField):
        return f"Texto de prueba {field.name}"
    if isinstance(field, models.DecimalField):
        return Decimal("150.00")
    if isinstance(field, models.IntegerField):
        return 1
    if isinstance(field, models.BooleanField):
        return False
    if isinstance(field, models.DateField):
        return timezone.localdate()
    if isinstance(field, models.DateTimeField):
        return timezone.now()
    return None


def _create_required(model, **overrides):
    data = dict(overrides)
    for field in model._meta.fields:
        if field.name in data:
            continue
        if field.auto_created or getattr(field, "primary_key", False):
            continue
        if getattr(field, "auto_now", False) or getattr(field, "auto_now_add", False):
            continue
        if field.has_default() or field.null or field.blank:
            continue
        if isinstance(field, models.ForeignKey):
            continue
        value = _fallback_value(field)
        if value is not None:
            data[field.name] = value
    return model.objects.create(**data)


class CrossActionAuditTests(TestCase):
    def setUp(self):
        self.company = _create_required(
            Company,
            **{
                _first_existing(Company, ["name", "legal_name", "business_name", "description"])
                or "name": "Empresa F1-P23"
            },
        )

        self.user = get_user_model().objects.create_user(
            email="cxp.f1p23@example.com",
            password="testpass123",
            role=UserRole.CUENTAS_POR_PAGAR,
        )
        self.user.is_staff = True
        self.user.is_superuser = True
        self.user.save(update_fields=["is_staff", "is_superuser"])

        beneficiary_data = {}
        if "company" in _field_names(Beneficiary):
            beneficiary_data["company"] = self.company
        name_field = _first_existing(
            Beneficiary,
            ["name", "legal_name", "business_name", "supplier_name", "display_name"],
        )
        if name_field:
            beneficiary_data[name_field] = "Proveedor F1-P23"
        id_field = _first_existing(
            Beneficiary,
            ["identification", "tax_id", "rif", "document_number", "code"],
        )
        if id_field:
            beneficiary_data[id_field] = "J-F1P23"
        self.beneficiary = _create_required(Beneficiary, **beneficiary_data)

        request_data = {}
        if "company" in _field_names(PaymentRequest):
            request_data["company"] = self.company
        if "beneficiary" in _field_names(PaymentRequest):
            request_data["beneficiary"] = self.beneficiary
        if "requested_by" in _field_names(PaymentRequest):
            request_data["requested_by"] = self.user
        if "created_by" in _field_names(PaymentRequest):
            request_data["created_by"] = self.user
        if "amount" in _field_names(PaymentRequest):
            request_data["amount"] = Decimal("150.00")
        if "concept" in _field_names(PaymentRequest):
            request_data["concept"] = "Pago F1-P23"
        if "description" in _field_names(PaymentRequest):
            request_data["description"] = "Pago F1-P23"
        if "due_date" in _field_names(PaymentRequest):
            request_data["due_date"] = timezone.localdate()
        if "status" in _field_names(PaymentRequest):
            request_data["status"] = PaymentRequestStatus.APPROVED
        self.payment_request = _create_required(PaymentRequest, **request_data)

    def test_payment_execution_registers_cross_action_audit(self):
        PaymentExecution.objects.create(
            payment_request=self.payment_request,
            executed_by=self.user,
            paid_at=date.today(),
            paid_amount=Decimal("150.00"),
            bank_reference="REF-F1P23",
            note="Pago validado por CxP",
        )

        action = PaymentApprovalAction.objects.get(
            payment_request=self.payment_request,
            action=ApprovalActionType.PAYMENT_EXECUTED,
        )
        self.assertEqual(action.performed_by, self.user)
        self.assertEqual(action.role, UserRole.CUENTAS_POR_PAGAR)
        self.assertIn("REF-F1P23", action.comment)
        self.assertIn("150.00", action.comment)

    def test_detail_shows_cross_action_audit_history(self):
        PaymentApprovalAction.objects.create(
            payment_request=self.payment_request,
            action=ApprovalActionType.PAYMENT_EXECUTED,
            performed_by=self.user,
            role=UserRole.CUENTAS_POR_PAGAR,
            comment="Pago ejecutado. Referencia bancaria: REF-F1P23. Monto pagado: 150.00.",
        )
        self.client.force_login(self.user)

        response = self.client.get(
            reverse("payment_requests:detail", kwargs={"pk": self.payment_request.pk})
        )

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Historial de acciones críticas")
        self.assertContains(response, "Pago ejecutado")
        self.assertContains(response, "REF-F1P23")

    def test_detail_shows_empty_audit_history_message(self):
        PaymentApprovalAction.objects.filter(payment_request=self.payment_request).delete()
        self.client.force_login(self.user)

        response = self.client.get(
            reverse("payment_requests:detail", kwargs={"pk": self.payment_request.pk})
        )

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Historial de acciones críticas")
        self.assertContains(response, "No hay acciones críticas registradas")
