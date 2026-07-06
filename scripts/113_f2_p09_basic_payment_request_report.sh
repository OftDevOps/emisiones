#!/usr/bin/env bash
set -euo pipefail

cd /home/dchirinos/oftalmiIA/emisiones/emisiones

echo "== F2-P09: reporte basico por estado, empresa y fecha =="

echo "== Estado inicial =="
git status --short

python3 - <<'PY'
from pathlib import Path

# ---------------------------------------------------------------------
# 1) Permiso centralizado para reporte operativo
# ---------------------------------------------------------------------
role_path = Path("backend/apps/accounts/role_permissions.py")
text = role_path.read_text(encoding="utf-8")

if 'PERM_VIEW_PAYMENT_REQUEST_REPORT = "payment_requests.view_report"' not in text:
    text = text.replace(
        'PERM_VIEW_ACCOUNTS_PAYABLE = "payment_requests.view_accounts_payable"\n',
        'PERM_VIEW_ACCOUNTS_PAYABLE = "payment_requests.view_accounts_payable"\n'
        'PERM_VIEW_PAYMENT_REQUEST_REPORT = "payment_requests.view_report"\n',
    )

matrix_block = '''    PERM_VIEW_PAYMENT_REQUEST_REPORT: {
        ROLE_ADMINISTRADOR,
        ROLE_FINANZAS,
        ROLE_CUENTAS_POR_PAGAR,
        ROLE_AUDITOR,
    },
'''

if "PERM_VIEW_PAYMENT_REQUEST_REPORT:" not in text:
    text = text.replace(
        '''    PERM_VIEW_ACCOUNTS_PAYABLE: {
        ROLE_ADMINISTRADOR,
        ROLE_CUENTAS_POR_PAGAR,
        ROLE_FINANZAS,
    },
''',
        '''    PERM_VIEW_ACCOUNTS_PAYABLE: {
        ROLE_ADMINISTRADOR,
        ROLE_CUENTAS_POR_PAGAR,
        ROLE_FINANZAS,
    },
''' + matrix_block,
    )

role_path.write_text(text, encoding="utf-8")

# ---------------------------------------------------------------------
# 2) Context processor role_nav: visibilidad UX para reporte
# ---------------------------------------------------------------------
ctx_path = Path("backend/apps/accounts/context_processors.py")
if ctx_path.exists():
    text = ctx_path.read_text(encoding="utf-8")

    if "PERM_VIEW_PAYMENT_REQUEST_REPORT" not in text:
        text = text.replace(
            "PERM_VIEW_PAYMENT_REQUESTS,\n",
            "PERM_VIEW_PAYMENT_REQUESTS,\n    PERM_VIEW_PAYMENT_REQUEST_REPORT,\n",
        )

    if '"can_view_payment_request_report"' not in text:
        anchor = '"can_view_accounts_payable": user_has_permission(user, PERM_VIEW_ACCOUNTS_PAYABLE),'
        if anchor in text:
            text = text.replace(
                anchor,
                anchor + '\n            "can_view_payment_request_report": user_has_permission(user, PERM_VIEW_PAYMENT_REQUEST_REPORT),',
            )
        else:
            # Fallback: add key near any role_nav dict return if the exact anchor changed.
            text = text.replace(
                '"can_view_payment_requests": user_has_permission(user, PERM_VIEW_PAYMENT_REQUESTS),',
                '"can_view_payment_requests": user_has_permission(user, PERM_VIEW_PAYMENT_REQUESTS),\n            "can_view_payment_request_report": user_has_permission(user, PERM_VIEW_PAYMENT_REQUEST_REPORT),',
            )

    ctx_path.write_text(text, encoding="utf-8")

# ---------------------------------------------------------------------
# 3) Vista de reporte en payment_requests.views
# ---------------------------------------------------------------------
views_path = Path("backend/apps/payment_requests/views.py")
text = views_path.read_text(encoding="utf-8")

if "PERM_VIEW_PAYMENT_REQUEST_REPORT" not in text:
    text = text.replace(
        "PERM_VIEW_PAYMENT_REQUESTS,\n",
        "PERM_VIEW_PAYMENT_REQUESTS,\n    PERM_VIEW_PAYMENT_REQUEST_REPORT,\n",
    )

text = text.replace(
    "from django.db.models import Count\n",
    "from django.db.models import Count, Sum\n",
)

if "from django.utils.dateparse import parse_date" not in text:
    text = text.replace(
        "from django.urls import reverse_lazy\n",
        "from django.urls import reverse_lazy\nfrom django.utils.dateparse import parse_date\n",
    )

if "from apps.organization.models import Company" not in text:
    text = text.replace(
        "from apps.accounts.models import UserRole\n",
        "from apps.accounts.models import UserRole\nfrom apps.organization.models import Company\n",
    )

report_class = r'''

class PaymentRequestReportView(LoginRequiredMixin, TemplateView):
    """Basic operational report filtered by status, company and due date."""

    template_name = "payment_requests/paymentrequest_report.html"

    def dispatch(self, request, *args, **kwargs):
        _require_operational_permission(
            request.user,
            PERM_VIEW_PAYMENT_REQUEST_REPORT,
            "Su rol no permite acceder al reporte operativo de solicitudes.",
        )
        return super().dispatch(request, *args, **kwargs)

    def get_filtered_queryset(self):
        queryset = scoped_payment_request_queryset(self.request.user)
        status = self.request.GET.get("status", "").strip()
        company_id = self.request.GET.get("company", "").strip()
        date_from = parse_date(self.request.GET.get("date_from", ""))
        date_to = parse_date(self.request.GET.get("date_to", ""))

        valid_statuses = {choice[0] for choice in PaymentRequestStatus.choices}
        if status in valid_statuses:
            queryset = queryset.filter(status=status)

        if company_id:
            queryset = queryset.filter(company_id=company_id)

        if date_from:
            queryset = queryset.filter(due_date__gte=date_from)

        if date_to:
            queryset = queryset.filter(due_date__lte=date_to)

        return queryset.order_by("company__name", "status", "due_date", "-created_at")

    def get_available_companies(self):
        user = self.request.user
        if user.is_superuser:
            return Company.objects.all().order_by("name")
        if getattr(user, "primary_company_id", None):
            return Company.objects.filter(pk=user.primary_company_id).order_by("name")
        return Company.objects.none()

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        payment_requests = self.get_filtered_queryset()
        totals = payment_requests.aggregate(
            total_requests=Count("id"),
            total_amount=Sum("amount"),
        )
        summary_rows = payment_requests.values(
            "company__name",
            "status",
        ).annotate(
            total=Count("id"),
            amount=Sum("amount"),
        ).order_by("company__name", "status")

        context.update(
            {
                "payment_requests": payment_requests[:100],
                "summary_rows": summary_rows,
                "total_requests": totals["total_requests"] or 0,
                "total_amount": totals["total_amount"] or 0,
                "status_choices": PaymentRequestStatus.choices,
                "available_companies": self.get_available_companies(),
                "filter_status": self.request.GET.get("status", ""),
                "filter_company": self.request.GET.get("company", ""),
                "filter_date_from": self.request.GET.get("date_from", ""),
                "filter_date_to": self.request.GET.get("date_to", ""),
            }
        )
        return context
'''

if "class PaymentRequestReportView" not in text:
    marker = "class PaymentRequestDashboardView(LoginRequiredMixin, TemplateView):"
    if marker not in text:
        raise SystemExit("ERROR: no se encontro PaymentRequestDashboardView para insertar PaymentRequestReportView.")
    text = text.replace(marker, report_class + "\n\n" + marker)

views_path.write_text(text, encoding="utf-8")

# ---------------------------------------------------------------------
# 4) URL del reporte
# ---------------------------------------------------------------------
urls_path = Path("backend/apps/payment_requests/urls.py")
text = urls_path.read_text(encoding="utf-8")

if "PaymentRequestReportView" not in text:
    text = text.replace(
        "PaymentRequestListView,\n",
        "PaymentRequestListView,\n    PaymentRequestReportView,\n",
    )

if 'name="report"' not in text:
    dashboard_line = '    path("dashboard/", PaymentRequestDashboardView.as_view(), name="dashboard"),\n'
    report_line = '    path("reports/basic/", PaymentRequestReportView.as_view(), name="report"),\n'
    if dashboard_line in text:
        text = text.replace(dashboard_line, dashboard_line + report_line)
    else:
        text = text.replace("urlpatterns = [\n", "urlpatterns = [\n" + report_line)

urls_path.write_text(text, encoding="utf-8")

# ---------------------------------------------------------------------
# 5) Dashboard: enlace al reporte si role_nav lo permite
# ---------------------------------------------------------------------
dashboard_path = Path("backend/templates/payment_requests/paymentrequest_dashboard.html")
if dashboard_path.exists():
    text = dashboard_path.read_text(encoding="utf-8")
    if "payment_requests:report" not in text:
        block = '''
      {% if role_nav.can_view_payment_request_report %}
        <a href="{% url 'payment_requests:report' %}" class="btn btn-outline-primary">Reporte operativo</a>
      {% endif %}
'''
        # Insert before Cuentas por Pagar if present, otherwise before end of operational access block.
        if "payment_requests:accounts_payable" in text:
            idx = text.find("payment_requests:accounts_payable")
            line_start = text.rfind("{% if", 0, idx)
            if line_start != -1:
                text = text[:line_start] + block + text[line_start:]
            else:
                text = text.replace("</section>", block + "</section>", 1)
        else:
            text = text.replace("</section>", block + "</section>", 1)
    dashboard_path.write_text(text, encoding="utf-8")

# ---------------------------------------------------------------------
# 6) Template del reporte
# ---------------------------------------------------------------------
template_path = Path("backend/templates/payment_requests/paymentrequest_report.html")
template_path.parent.mkdir(parents=True, exist_ok=True)
if not template_path.exists():
    template_path.write_text('''{% extends "base.html" %}

{% block title %}Reporte operativo de solicitudes{% endblock %}

{% block content %}
<section class="card">
  <div class="card-body">
    <h1>Reporte operativo de solicitudes</h1>
    <p>Consulta basica por estado, empresa y fecha de vencimiento.</p>

    <form method="get" class="row g-3 mb-4">
      <div class="col-md-3">
        <label for="status" class="form-label">Estado</label>
        <select id="status" name="status" class="form-select">
          <option value="">Todos</option>
          {% for value, label in status_choices %}
            <option value="{{ value }}" {% if filter_status == value %}selected{% endif %}>{{ label }}</option>
          {% endfor %}
        </select>
      </div>
      <div class="col-md-3">
        <label for="company" class="form-label">Empresa</label>
        <select id="company" name="company" class="form-select">
          <option value="">Todas disponibles</option>
          {% for company in available_companies %}
            <option value="{{ company.pk }}" {% if filter_company == company.pk|stringformat:"s" %}selected{% endif %}>{{ company.name }}</option>
          {% endfor %}
        </select>
      </div>
      <div class="col-md-2">
        <label for="date_from" class="form-label">Desde</label>
        <input id="date_from" type="date" name="date_from" value="{{ filter_date_from }}" class="form-control">
      </div>
      <div class="col-md-2">
        <label for="date_to" class="form-label">Hasta</label>
        <input id="date_to" type="date" name="date_to" value="{{ filter_date_to }}" class="form-control">
      </div>
      <div class="col-md-2 d-flex align-items-end">
        <button type="submit" class="btn btn-primary">Filtrar</button>
      </div>
    </form>

    <div class="row mb-4">
      <div class="col-md-6">
        <div class="border rounded p-3">
          <strong>Total solicitudes</strong>
          <div>{{ total_requests }}</div>
        </div>
      </div>
      <div class="col-md-6">
        <div class="border rounded p-3">
          <strong>Monto total</strong>
          <div>{{ total_amount }}</div>
        </div>
      </div>
    </div>

    <h2>Resumen por empresa y estado</h2>
    <table class="table table-sm table-striped">
      <thead>
        <tr>
          <th>Empresa</th>
          <th>Estado</th>
          <th>Cantidad</th>
          <th>Monto</th>
        </tr>
      </thead>
      <tbody>
        {% for row in summary_rows %}
          <tr>
            <td>{{ row.company__name }}</td>
            <td>{{ row.status }}</td>
            <td>{{ row.total }}</td>
            <td>{{ row.amount }}</td>
          </tr>
        {% empty %}
          <tr><td colspan="4">Sin solicitudes para los filtros seleccionados.</td></tr>
        {% endfor %}
      </tbody>
    </table>

    <h2>Detalle operativo</h2>
    <table class="table table-sm table-hover">
      <thead>
        <tr>
          <th>Empresa</th>
          <th>Beneficiario</th>
          <th>Concepto</th>
          <th>Estado</th>
          <th>Fecha vencimiento</th>
          <th>Monto</th>
        </tr>
      </thead>
      <tbody>
        {% for request in payment_requests %}
          <tr>
            <td>{{ request.company.name }}</td>
            <td>{{ request.beneficiary }}</td>
            <td>{{ request.concept }}</td>
            <td>{{ request.get_status_display }}</td>
            <td>{{ request.due_date|default:"-" }}</td>
            <td>{{ request.amount }} {{ request.currency }}</td>
          </tr>
        {% empty %}
          <tr><td colspan="6">Sin detalle disponible.</td></tr>
        {% endfor %}
      </tbody>
    </table>
  </div>
</section>
{% endblock %}
''', encoding="utf-8")

# ---------------------------------------------------------------------
# 7) Pruebas focales F2-P09
# ---------------------------------------------------------------------
test_path = Path("backend/apps/payment_requests/tests/test_reports.py")
test_path.write_text('''from datetime import date
from decimal import Decimal

from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary, BeneficiaryType
from apps.organization.models import Company
from apps.payment_requests.models import Currency, PaymentRequest, PaymentRequestStatus


class PaymentRequestReportViewTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.other_company = Company.objects.create(name="Otra Empresa", code="OTH")
        self.finance_user = CustomUser.objects.create_user(
            email="finanzas.reportes@oftalmi.com",
            password="test-pass-123",
            role=UserRole.FINANZAS,
            primary_company=self.company,
        )
        self.requester = CustomUser.objects.create_user(
            email="solicitante.reportes@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.company,
        )
        self.other_user = CustomUser.objects.create_user(
            email="otro.reportes@oftalmi.com",
            password="test-pass-123",
            role=UserRole.FINANZAS,
            primary_company=self.other_company,
        )
        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Reportes C.A.",
            document_number="J-11111111-1",
            email="proveedor.reportes@example.com",
        )
        self.other_beneficiary = Beneficiary.objects.create(
            company=self.other_company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Externo Reportes C.A.",
            document_number="J-22222222-2",
            email="proveedor.externo.reportes@example.com",
        )
        self.url = reverse("payment_requests:report")

    def create_payment_request(self, company, beneficiary, user, status, concept, due_date):
        return PaymentRequest.objects.create(
            company=company,
            beneficiary=beneficiary,
            requested_by=user,
            amount=Decimal("250.00"),
            currency=Currency.VES,
            concept=concept,
            status=status,
            due_date=due_date,
        )

    def test_report_requires_login(self):
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 302)

    def test_finance_user_can_access_report(self):
        self.client.force_login(self.finance_user)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, "payment_requests/paymentrequest_report.html")
        self.assertContains(response, "Reporte operativo de solicitudes")

    def test_solicitante_cannot_access_report(self):
        self.client.force_login(self.requester)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 403)

    def test_report_scopes_results_to_user_company(self):
        self.client.force_login(self.finance_user)
        self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            PaymentRequestStatus.APPROVED,
            "Solicitud visible reporte",
            date(2026, 7, 10),
        )
        self.create_payment_request(
            self.other_company,
            self.other_beneficiary,
            self.other_user,
            PaymentRequestStatus.APPROVED,
            "Solicitud oculta reporte",
            date(2026, 7, 10),
        )

        response = self.client.get(self.url)

        self.assertEqual(response.context["total_requests"], 1)
        self.assertContains(response, "Solicitud visible reporte")
        self.assertNotContains(response, "Solicitud oculta reporte")

    def test_report_filters_by_status_and_date_range(self):
        self.client.force_login(self.finance_user)
        expected = self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            PaymentRequestStatus.APPROVED,
            "Aprobada dentro del rango",
            date(2026, 7, 15),
        )
        self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            PaymentRequestStatus.REJECTED,
            "Rechazada fuera del filtro",
            date(2026, 7, 15),
        )
        self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            PaymentRequestStatus.APPROVED,
            "Aprobada fuera de fecha",
            date(2026, 8, 1),
        )

        response = self.client.get(
            self.url,
            {
                "status": PaymentRequestStatus.APPROVED,
                "date_from": "2026-07-01",
                "date_to": "2026-07-31",
            },
        )

        self.assertEqual(list(response.context["payment_requests"]), [expected])
        self.assertEqual(response.context["total_requests"], 1)
        self.assertContains(response, "Aprobada dentro del rango")
        self.assertNotContains(response, "Rechazada fuera del filtro")
        self.assertNotContains(response, "Aprobada fuera de fecha")
''', encoding="utf-8")

# ---------------------------------------------------------------------
# 8) Documentacion
# ---------------------------------------------------------------------
doc_path = Path("docs/f2_p09_reporte_basico_estado_empresa_fecha.md")
doc_path.write_text('''# F2-P09 - Reporte basico por estado, empresa y fecha

## Objetivo

Incorporar un reporte operativo basico de solicitudes de pago filtrable por estado, empresa y fecha de vencimiento.

## Alcance implementado

- Nueva vista `PaymentRequestReportView`.
- Nueva ruta `payment_requests:report` en `/payment-requests/reports/basic/`.
- Filtros por estado, empresa disponible y rango de fecha.
- Resumen por empresa y estado.
- Detalle operativo limitado al alcance empresarial del usuario.
- Permiso centralizado `payment_requests.view_report`.
- Visibilidad UX desde `role_nav.can_view_payment_request_report`.
- Pruebas focales de acceso, autorizacion, alcance por empresa y filtros.

## Roles autorizados

- Administrador.
- Finanzas.
- Cuentas por Pagar.
- Auditor.

## Decision tecnica

No se crean modelos ni migraciones. El reporte reutiliza `PaymentRequest`, `scoped_payment_request_queryset` y la matriz de permisos centralizada.

## Relacion con F2-P10

F2-P09 deja la consulta operativa en pantalla. F2-P10 debe agregar exportacion operativa basica sobre este mismo criterio de filtros, evitando duplicar reglas de negocio.
''', encoding="utf-8")

roadmap_path = Path("docs/roadmap_fase2.md")
text = roadmap_path.read_text(encoding="utf-8")
if "F2-P09 | Cerrado" not in text:
    text = text.replace(
        "| 9 | F2-P09 | Reporte basico por estado, empresa y fecha |",
        "| 9 | F2-P09 | Cerrado - Reporte basico por estado, empresa y fecha |",
    )
    text = text.replace(
        "Ejecutar F2-P09 con foco en:\n\n- Reporte basico por estado, empresa y fecha.\n- Filtros operativos coherentes con alcance por empresa.\n- Reporte visible solo para roles autorizados.\n- Sin modelos nuevos salvo necesidad justificada.\n- Sin migraciones salvo necesidad justificada.",
        "Ejecutar F2-P10 con foco en:\n\n- Exportacion operativa basica del reporte.\n- Reutilizar filtros de estado, empresa y fecha.\n- Mantener alcance por empresa y permisos centralizados.\n- Sin modelos nuevos salvo necesidad justificada.\n- Sin migraciones salvo necesidad justificada.",
    )
roadmap_path.write_text(text, encoding="utf-8")

print("OK: F2-P09 aplicado a codigo, tests y documentacion.")
PY

echo "== Archivos F2-P09 =="
git status --short

echo "== Validando diff whitespace =="
git diff --check

echo "== Ruff focal =="
docker compose exec backend ruff check \
  apps/accounts/role_permissions.py \
  apps/accounts/context_processors.py \
  apps/payment_requests/views.py \
  apps/payment_requests/urls.py \
  apps/payment_requests/tests/test_reports.py

echo "== Tests focales F2-P09 =="
docker compose exec backend python manage.py test \
  apps.payment_requests.tests.test_reports \
  apps.payment_requests.tests.test_dashboard

echo "== F2-P09 implementacion focal OK =="
