from datetime import date, timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.db import transaction

from apps.accounts.models import UserRole
from apps.beneficiaries.models import Beneficiary, BeneficiaryType
from apps.organization.models import Company
from apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction, ApprovalStepStatus
from apps.payment_execution.models import PaymentExecution
from apps.payment_requests.models import Currency, PaymentRequest, PaymentRequestStatus

User = get_user_model()
PASSWORD = "Demo123456*"


def ensure_company(code, name):
    company, _ = Company.objects.get_or_create(code=code, defaults={"name": name})
    if company.name != name:
        company.name = name
        company.save(update_fields=["name"])
    return company


def ensure_user(email, role, company, *, superuser=False):
    user, _ = User.objects.get_or_create(
        email=email,
        defaults={
            "username": email,
            "role": role,
            "primary_company": company,
            "is_active": True,
            "is_staff": superuser,
            "is_superuser": superuser,
        },
    )
    user.username = email
    user.role = role
    user.primary_company = company
    user.is_active = True
    if superuser:
        user.is_staff = True
        user.is_superuser = True
    user.set_password(PASSWORD)
    user.save()
    return user


def ensure_beneficiary(company, legal_name, document_number, email):
    beneficiary, _ = Beneficiary.objects.get_or_create(
        company=company,
        document_number=document_number,
        defaults={
            "beneficiary_type": BeneficiaryType.SUPPLIER,
            "legal_name": legal_name,
            "email": email,
        },
    )
    beneficiary.beneficiary_type = BeneficiaryType.SUPPLIER
    beneficiary.legal_name = legal_name
    beneficiary.email = email
    beneficiary.save()
    return beneficiary


def ensure_request(company, beneficiary, requester, concept, amount, status):
    payment_request, _ = PaymentRequest.objects.get_or_create(
        company=company,
        beneficiary=beneficiary,
        concept=concept,
        defaults={
            "requested_by": requester,
            "amount": amount,
            "currency": Currency.VES,
            "due_date": date.today() + timedelta(days=7),
            "status": status,
        },
    )
    payment_request.requested_by = requester
    payment_request.amount = amount
    payment_request.currency = Currency.VES
    payment_request.due_date = date.today() + timedelta(days=7)
    payment_request.status = status
    payment_request.save()
    return payment_request


def ensure_action(payment_request, action, user, role, comment):
    obj, _ = PaymentApprovalAction.objects.get_or_create(
        payment_request=payment_request,
        action=action,
        comment=comment,
        defaults={
            "performed_by": user,
            "role": role,
        },
    )
    obj.performed_by = user
    obj.role = role
    obj.save()
    return obj


@transaction.atomic
def run():
    company = ensure_company("OFT", "Laboratorios Oftalmi")
    other_company = ensure_company("INB", "Inversiones Demo Oftalmi")

    admin = ensure_user("douglas.chirinos@oftalmi.com", UserRole.ADMINISTRADOR, company, superuser=True)
    requester = ensure_user("solicitante.demo@oftalmi.com", UserRole.SOLICITANTE, company)
    approver = ensure_user("responsable.demo@oftalmi.com", UserRole.RESPONSABLE_UNIDAD, company)
    finance = ensure_user("finanzas.demo@oftalmi.com", UserRole.FINANZAS, company)
    cxp = ensure_user("cxp.demo@oftalmi.com", UserRole.CUENTAS_POR_PAGAR, company)
    auditor = ensure_user("auditor.demo@oftalmi.com", UserRole.AUDITOR, company)
    other_requester = ensure_user("solicitante.otra.demo@oftalmi.com", UserRole.SOLICITANTE, other_company)

    supplier = ensure_beneficiary(company, "Proveedor Demo Oftalmi C.A.", "J-90000000-1", "proveedor.demo@oftalmi.com")
    services = ensure_beneficiary(company, "Servicios Clinicos Demo C.A.", "J-90000000-2", "servicios.demo@oftalmi.com")
    other_supplier = ensure_beneficiary(other_company, "Proveedor Otra Empresa Demo C.A.", "J-90000000-3", "otra.demo@oftalmi.com")

    draft = ensure_request(company, supplier, requester, "DEMO F1-P26 - Solicitud borrador", Decimal("125.00"), PaymentRequestStatus.DRAFT)
    pending = ensure_request(company, supplier, requester, "DEMO F1-P26 - Pendiente de aprobacion", Decimal("250.00"), PaymentRequestStatus.SUBMITTED)
    approved = ensure_request(company, services, requester, "DEMO F1-P26 - Aprobada pendiente de pago", Decimal("375.00"), PaymentRequestStatus.APPROVED)
    paid = ensure_request(company, services, requester, "DEMO F1-P26 - Pagada con trazabilidad", Decimal("500.00"), PaymentRequestStatus.APPROVED)
    rejected = ensure_request(company, supplier, requester, "DEMO F1-P26 - Rechazada con auditoria", Decimal("180.00"), PaymentRequestStatus.REJECTED)
    other = ensure_request(other_company, other_supplier, other_requester, "DEMO F1-P26 - Otra empresa no visible", Decimal("999.00"), PaymentRequestStatus.APPROVED)

    # Limpiar pasos demo para poder resembrar de forma idempotente en la solicitud pendiente.
    pending.approval_steps.all().delete()
    pending.approval_steps.create(sequence=1, required_role=UserRole.RESPONSABLE_UNIDAD, status=ApprovalStepStatus.PENDING)
    pending.approval_steps.create(sequence=2, required_role=UserRole.FINANZAS, status=ApprovalStepStatus.PENDING)

    ensure_action(pending, ApprovalActionType.SUBMIT, requester, UserRole.SOLICITANTE, "Solicitud enviada a aprobacion demo.")
    ensure_action(approved, ApprovalActionType.APPROVE, approver, UserRole.RESPONSABLE_UNIDAD, "Aprobacion demo por responsable de unidad.")
    ensure_action(approved, ApprovalActionType.APPROVE, finance, UserRole.FINANZAS, "Aprobacion demo por finanzas.")
    ensure_action(rejected, ApprovalActionType.REJECT, approver, UserRole.RESPONSABLE_UNIDAD, "Rechazo demo por soporte incompleto.")
    ensure_action(other, ApprovalActionType.APPROVE, other_requester, UserRole.SOLICITANTE, "Accion demo de otra empresa.")

    execution, created = PaymentExecution.objects.get_or_create(
        payment_request=paid,
        defaults={
            "executed_by": cxp,
            "paid_at": date.today(),
            "paid_amount": Decimal("500.00"),
            "bank_reference": "DEMO-F1P26-REF-001",
            "note": "Pago demo generado para validacion visual.",
        },
    )
    if not created:
        execution.executed_by = cxp
        execution.paid_at = date.today()
        execution.paid_amount = Decimal("500.00")
        execution.bank_reference = "DEMO-F1P26-REF-001"
        execution.note = "Pago demo generado para validacion visual."
        execution.save()

    paid.refresh_from_db()

    print("\n== Datos demo F1-P26 listos ==")
    print("URL base: http://localhost:8001")
    print("\nUsuarios demo, todos con clave:", PASSWORD)
    for user in [admin, requester, approver, finance, cxp, auditor, other_requester]:
        print(f"- {user.email} | rol={user.role} | empresa={user.primary_company}")
    print("\nRutas para validar:")
    print("- http://localhost:8001/accounts/login/")
    print("- http://localhost:8001/payment-requests/dashboard/")
    print("- http://localhost:8001/payment-requests/")
    print("- http://localhost:8001/payment-approvals/pending/")
    print("- http://localhost:8001/payment-approvals/audit/")
    print("- http://localhost:8001/payment-requests/accounts-payable/")
    print("\nSolicitudes demo:")
    for item in [draft, pending, approved, paid, rejected, other]:
        item.refresh_from_db()
        print(f"- #{item.pk} | {item.status} | {item.concept}")


run()
