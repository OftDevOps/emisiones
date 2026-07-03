#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_ROOT"

echo "== F1-P24: Workbench de auditoria transversal de acciones criticas =="
echo "== Rama actual =="
git branch --show-current

echo "== Estado inicial =="
git status --short

if [ "$(git branch --show-current)" != "feature/f1-p24" ]; then
  echo "ERROR: este script debe ejecutarse en feature/f1-p24" >&2
  exit 1
fi

echo "== Actualizar views.py con CrossActionAuditWorkbenchView =="
python - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_approvals/views.py")
text = path.read_text()

# Normalizar imports del archivo, que actualmente tiene mezcla de imports relativos y directos.
text = text.replace("from .models import ApprovalActionType\n", "")
text = text.replace("from apps.payment_approvals.models import ApprovalStepStatus, PaymentApprovalStep\n", "")
text = text.replace("from .forms import ApprovalActionForm\n", "from .forms import ApprovalActionForm\n")

imports_marker = "from django.views.generic import ListView, View\n"
if imports_marker not in text:
    raise SystemExit("ERROR: no se encontro bloque de imports esperado en views.py")

new_imports = """from django.views.generic import ListView, View\n\nfrom .forms import ApprovalActionForm\nfrom .models import (\n    ApprovalActionType,\n    ApprovalStepStatus,\n    PaymentApprovalAction,\n    PaymentApprovalStep,\n)\n"""

start = text.find("from django.contrib import messages")
class_start = text.find("class PendingApprovalStepsView")
if start == -1 or class_start == -1:
    raise SystemExit("ERROR: estructura de views.py no reconocida")

old_import_block = text[start:class_start]
base_imports = """from django.contrib import messages\nfrom django.contrib.auth.mixins import LoginRequiredMixin\nfrom django.core.exceptions import PermissionDenied, ValidationError\nfrom django.shortcuts import get_object_or_404, redirect\nfrom django.views.generic import ListView, View\n\nfrom .forms import ApprovalActionForm\nfrom .models import (\n    ApprovalActionType,\n    ApprovalStepStatus,\n    PaymentApprovalAction,\n    PaymentApprovalStep,\n)\n\n\n"""
text = text[:start] + base_imports + text[class_start:]

view_code = r'''

class CrossActionAuditWorkbenchView(LoginRequiredMixin, ListView):
    model = PaymentApprovalAction
    template_name = "payment_approvals/cross_action_audit_workbench.html"
    context_object_name = "actions"
    paginate_by = 25

    def get_queryset(self):
        user = self.request.user
        queryset = PaymentApprovalAction.objects.select_related(
            "payment_request",
            "payment_request__company",
            "payment_request__beneficiary",
            "performed_by",
            "step",
        ).order_by("-created_at", "-id")

        if not user.is_superuser:
            if not getattr(user, "primary_company_id", None):
                return queryset.none()
            queryset = queryset.filter(payment_request__company_id=user.primary_company_id)

        action = self.request.GET.get("action", "").strip()
        company = self.request.GET.get("company", "").strip()
        date_from = self.request.GET.get("date_from", "").strip()
        date_to = self.request.GET.get("date_to", "").strip()

        if action:
            queryset = queryset.filter(action=action)
        if company:
            queryset = queryset.filter(payment_request__company_id=company)
        if date_from:
            queryset = queryset.filter(created_at__date__gte=date_from)
        if date_to:
            queryset = queryset.filter(created_at__date__lte=date_to)

        return queryset

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        user = self.request.user

        actions_queryset = PaymentApprovalAction.objects.select_related("payment_request__company")
        if not user.is_superuser:
            if getattr(user, "primary_company_id", None):
                actions_queryset = actions_queryset.filter(payment_request__company_id=user.primary_company_id)
            else:
                actions_queryset = actions_queryset.none()

        companies = []
        seen_company_ids = set()
        for action in actions_queryset.order_by("payment_request__company__name"):
            company = action.payment_request.company
            if company.pk not in seen_company_ids:
                seen_company_ids.add(company.pk)
                companies.append(company)

        context["action_choices"] = ApprovalActionType.choices
        context["companies"] = companies
        context["filters"] = {
            "action": self.request.GET.get("action", "").strip(),
            "company": self.request.GET.get("company", "").strip(),
            "date_from": self.request.GET.get("date_from", "").strip(),
            "date_to": self.request.GET.get("date_to", "").strip(),
        }
        context["total_actions"] = self.object_list.count()
        return context
'''

if "class CrossActionAuditWorkbenchView" not in text:
    text = text.rstrip() + view_code + "\n"

path.write_text(text)
PY

echo "== Actualizar urls.py =="
python - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_approvals/urls.py")
text = path.read_text()

if "CrossActionAuditWorkbenchView" not in text:
    text = text.replace(
        "from .views import PendingApprovalStepsView\n",
        "from .views import CrossActionAuditWorkbenchView, PendingApprovalStepsView\n",
    )

if 'path("audit/", CrossActionAuditWorkbenchView.as_view(), name="audit"),' not in text:
    text = text.replace(
        "urlpatterns = [\n",
        "urlpatterns = [\n    path(\"audit/\", CrossActionAuditWorkbenchView.as_view(), name=\"audit\"),\n",
    )

path.write_text(text)
PY

echo "== Crear template cross_action_audit_workbench.html =="
cat > backend/templates/payment_approvals/cross_action_audit_workbench.html <<'HTML'
{% extends "base.html" %}

{% block title %}Auditoría de acciones críticas{% endblock %}

{% block content %}
<div class="d-flex justify-content-between align-items-center mb-3">
  <div>
    <h1 class="h3 mb-1">Auditoría de acciones críticas</h1>
    <p class="text-muted mb-0">Trazabilidad transversal de solicitudes de pago.</p>
  </div>
  <a class="btn btn-outline-secondary" href="{% url 'payment_approvals:pending' %}">Pendientes por aprobar</a>
</div>

<div class="card mb-3">
  <div class="card-body">
    <form method="get" class="row g-3 align-items-end">
      <div class="col-md-3">
        <label class="form-label" for="id_action">Acción</label>
        <select class="form-select" id="id_action" name="action">
          <option value="">Todas</option>
          {% for value, label in action_choices %}
            <option value="{{ value }}" {% if filters.action == value %}selected{% endif %}>{{ label }}</option>
          {% endfor %}
        </select>
      </div>
      <div class="col-md-3">
        <label class="form-label" for="id_company">Empresa</label>
        <select class="form-select" id="id_company" name="company">
          <option value="">Todas</option>
          {% for company in companies %}
            <option value="{{ company.pk }}" {% if filters.company == company.pk|stringformat:'s' %}selected{% endif %}>{{ company.name }}</option>
          {% endfor %}
        </select>
      </div>
      <div class="col-md-2">
        <label class="form-label" for="id_date_from">Desde</label>
        <input class="form-control" type="date" id="id_date_from" name="date_from" value="{{ filters.date_from }}">
      </div>
      <div class="col-md-2">
        <label class="form-label" for="id_date_to">Hasta</label>
        <input class="form-control" type="date" id="id_date_to" name="date_to" value="{{ filters.date_to }}">
      </div>
      <div class="col-md-2 d-flex gap-2">
        <button class="btn btn-primary" type="submit">Filtrar</button>
        <a class="btn btn-outline-secondary" href="{% url 'payment_approvals:audit' %}">Limpiar</a>
      </div>
    </form>
  </div>
</div>

<div class="card">
  <div class="card-header d-flex justify-content-between align-items-center">
    <span>Historial transversal</span>
    <span class="badge text-bg-secondary">{{ total_actions }} registro(s)</span>
  </div>
  <div class="table-responsive">
    <table class="table table-hover align-middle mb-0">
      <thead>
        <tr>
          <th>Fecha</th>
          <th>Solicitud</th>
          <th>Empresa</th>
          <th>Acción</th>
          <th>Usuario</th>
          <th>Rol</th>
          <th>Comentario</th>
        </tr>
      </thead>
      <tbody>
        {% for action in actions %}
          <tr>
            <td>{{ action.created_at|date:"Y-m-d H:i" }}</td>
            <td>
              <a href="{% url 'payment_requests:detail' action.payment_request.pk %}">#{{ action.payment_request.pk }}</a>
            </td>
            <td>{{ action.payment_request.company.name }}</td>
            <td>{{ action.get_action_display }}</td>
            <td>{{ action.performed_by }}</td>
            <td>{{ action.get_role_display }}</td>
            <td>{{ action.comment|default:"-" }}</td>
          </tr>
        {% empty %}
          <tr>
            <td colspan="7" class="text-muted">No hay acciones críticas registradas.</td>
          </tr>
        {% endfor %}
      </tbody>
    </table>
  </div>
</div>
{% endblock %}
HTML

echo "== Crear tests F1-P24 =="
cat > backend/apps/payment_approvals/tests/test_cross_action_audit_workbench.py <<'PY'
from decimal import Decimal

from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary, BeneficiaryType
from apps.organization.models import Company
from apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction
from apps.payment_requests.models import Currency, PaymentRequest, PaymentRequestStatus


class CrossActionAuditWorkbenchTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.other_company = Company.objects.create(name="Otra Empresa", code="OTH")

        self.cxp_user = CustomUser.objects.create_user(
            email="cxp.audit@oftalmi.com",
            password="test-pass-123",
            role=UserRole.CUENTAS_POR_PAGAR,
            primary_company=self.company,
        )
        self.other_user = CustomUser.objects.create_user(
            email="cxp.audit.otra@oftalmi.com",
            password="test-pass-123",
            role=UserRole.CUENTAS_POR_PAGAR,
            primary_company=self.other_company,
        )
        self.superuser = CustomUser.objects.create_superuser(
            email="admin.audit@oftalmi.com",
            password="test-pass-123",
        )

        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Auditoría C.A.",
            document_number="J-44444444-4",
            email="proveedor.audit@example.com",
        )
        self.other_beneficiary = Beneficiary.objects.create(
            company=self.other_company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Otra Empresa C.A.",
            document_number="J-55555555-5",
            email="proveedor.otra.audit@example.com",
        )

        self.payment_request = PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.cxp_user,
            amount=Decimal("150.00"),
            currency=Currency.VES,
            concept="Pago auditado",
            status=PaymentRequestStatus.APPROVED,
        )
        self.other_payment_request = PaymentRequest.objects.create(
            company=self.other_company,
            beneficiary=self.other_beneficiary,
            requested_by=self.other_user,
            amount=Decimal("250.00"),
            currency=Currency.VES,
            concept="Pago auditado otra empresa",
            status=PaymentRequestStatus.APPROVED,
        )

        self.company_action = PaymentApprovalAction.objects.create(
            payment_request=self.payment_request,
            action=ApprovalActionType.PAYMENT_EXECUTED,
            performed_by=self.cxp_user,
            role=UserRole.CUENTAS_POR_PAGAR,
            comment="Pago ejecutado REF-AUDIT-01",
        )
        self.other_company_action = PaymentApprovalAction.objects.create(
            payment_request=self.other_payment_request,
            action=ApprovalActionType.REJECT,
            performed_by=self.other_user,
            role=UserRole.CUENTAS_POR_PAGAR,
            comment="Rechazo otra empresa",
        )

    def url(self):
        return reverse("payment_approvals:audit")

    def test_login_required(self):
        response = self.client.get(self.url())

        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response.url)

    def test_user_sees_only_primary_company_actions(self):
        self.client.force_login(self.cxp_user)

        response = self.client.get(self.url())

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Auditoría de acciones críticas")
        self.assertContains(response, "Pago ejecutado REF-AUDIT-01")
        self.assertNotContains(response, "Rechazo otra empresa")

    def test_superuser_sees_all_company_actions(self):
        self.client.force_login(self.superuser)

        response = self.client.get(self.url())

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Pago ejecutado REF-AUDIT-01")
        self.assertContains(response, "Rechazo otra empresa")

    def test_filter_by_action(self):
        self.client.force_login(self.superuser)

        response = self.client.get(self.url(), {"action": ApprovalActionType.REJECT})

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Rechazo otra empresa")
        self.assertNotContains(response, "Pago ejecutado REF-AUDIT-01")

    def test_filter_by_company(self):
        self.client.force_login(self.superuser)

        response = self.client.get(self.url(), {"company": str(self.company.pk)})

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Pago ejecutado REF-AUDIT-01")
        self.assertNotContains(response, "Rechazo otra empresa")
PY

echo "== Validacion focalizada F1-P24 =="
docker compose exec backend ruff check apps/payment_approvals/views.py apps/payment_approvals/urls.py apps/payment_approvals/tests/test_cross_action_audit_workbench.py
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py test apps.payment_approvals.tests.test_cross_action_audit_workbench

echo "== OK F1-P24 aplicado. Ejecutar validacion completa antes de commit. =="
