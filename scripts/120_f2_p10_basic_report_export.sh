#!/usr/bin/env bash
set -euo pipefail

cd /home/dchirinos/oftalmiIA/emisiones/emisiones

echo "== F2-P10: exportacion operativa basica del reporte =="
echo "== Estado inicial =="
git status --short

python3 - <<'PY'
from pathlib import Path

views = Path("backend/apps/payment_requests/views.py")
text = views.read_text(encoding="utf-8")

# Ensure imports
text = text.replace(
    "from apps.accounts.role_permissions import (\n",
    "import csv\n\nfrom apps.accounts.role_permissions import (\n",
    1,
) if not text.startswith("import csv\n") and "import csv\n" not in text.splitlines()[:5] else text

if "from django.http import HttpResponse" not in text:
    text = text.replace(
        "from django.db.models import Count, Sum\n",
        "from django.db.models import Count, Sum\nfrom django.http import HttpResponse\n",
        1,
    )

helper = '''\n\ndef get_payment_request_report_queryset(request):\n    """Return report queryset using the same filters for screen and exports."""\n    queryset = scoped_payment_request_queryset(request.user)\n    status = request.GET.get("status", "").strip()\n    company_id = request.GET.get("company", "").strip()\n    date_from = parse_date(request.GET.get("date_from", ""))\n    date_to = parse_date(request.GET.get("date_to", ""))\n\n    valid_statuses = {choice[0] for choice in PaymentRequestStatus.choices}\n    if status in valid_statuses:\n        queryset = queryset.filter(status=status)\n\n    if company_id:\n        queryset = queryset.filter(company_id=company_id)\n\n    if date_from:\n        queryset = queryset.filter(due_date__gte=date_from)\n\n    if date_to:\n        queryset = queryset.filter(due_date__lte=date_to)\n\n    return queryset.order_by("company__name", "status", "due_date", "-created_at")\n'''

if "def get_payment_request_report_queryset(request):" not in text:
    marker = "\n\nclass PaymentRequestListView(LoginRequiredMixin, ListView):\n"
    if marker not in text:
        raise SystemExit("ERROR: marker para insertar helper no encontrado")
    text = text.replace(marker, helper + marker, 1)

old_method = '''    def get_filtered_queryset(self):\n        queryset = scoped_payment_request_queryset(self.request.user)\n        status = self.request.GET.get("status", "").strip()\n        company_id = self.request.GET.get("company", "").strip()\n        date_from = parse_date(self.request.GET.get("date_from", ""))\n        date_to = parse_date(self.request.GET.get("date_to", ""))\n\n        valid_statuses = {choice[0] for choice in PaymentRequestStatus.choices}\n        if status in valid_statuses:\n            queryset = queryset.filter(status=status)\n\n        if company_id:\n            queryset = queryset.filter(company_id=company_id)\n\n        if date_from:\n            queryset = queryset.filter(due_date__gte=date_from)\n\n        if date_to:\n            queryset = queryset.filter(due_date__lte=date_to)\n\n        return queryset.order_by("company__name", "status", "due_date", "-created_at")\n'''
new_method = '''    def get_filtered_queryset(self):\n        return get_payment_request_report_queryset(self.request)\n'''
if old_method in text:
    text = text.replace(old_method, new_method, 1)

export_class = '''\n\nclass PaymentRequestReportExportView(LoginRequiredMixin, View):\n    """CSV export for the basic operational payment request report."""\n\n    def dispatch(self, request, *args, **kwargs):\n        _require_operational_permission(\n            request.user,\n            PERM_VIEW_PAYMENT_REQUEST_REPORT,\n            "Su rol no permite exportar el reporte operativo de solicitudes.",\n        )\n        return super().dispatch(request, *args, **kwargs)\n\n    def get(self, request, *args, **kwargs):\n        queryset = get_payment_request_report_queryset(request)\n        response = HttpResponse(content_type="text/csv; charset=utf-8")\n        response["Content-Disposition"] = 'attachment; filename="payment_requests_report.csv"'\n        response.write("\\ufeff")\n\n        writer = csv.writer(response)\n        writer.writerow([\n            "Empresa",\n            "Beneficiario",\n            "Concepto",\n            "Estado",\n            "Fecha vencimiento",\n            "Monto",\n            "Moneda",\n            "Solicitado por",\n        ])\n\n        for payment_request in queryset:\n            writer.writerow([\n                payment_request.company.name,\n                str(payment_request.beneficiary),\n                payment_request.concept,\n                payment_request.get_status_display(),\n                payment_request.due_date.isoformat() if payment_request.due_date else "",\n                payment_request.amount,\n                payment_request.currency,\n                payment_request.requested_by.email if payment_request.requested_by else "",\n            ])\n\n        return response\n'''

if "class PaymentRequestReportExportView" not in text:
    marker = "\n\nclass PaymentRequestDashboardView(LoginRequiredMixin, TemplateView):"
    if marker not in text:
        raise SystemExit("ERROR: marker para insertar export view no encontrado")
    text = text.replace(marker, export_class + marker, 1)

views.write_text(text, encoding="utf-8")

urls = Path("backend/apps/payment_requests/urls.py")
text = urls.read_text(encoding="utf-8")
if "PaymentRequestReportExportView" not in text:
    text = text.replace(
        "    PaymentRequestReportView,\n",
        "    PaymentRequestReportView,\n    PaymentRequestReportExportView,\n",
        1,
    )
if 'path("reports/basic/export/", PaymentRequestReportExportView.as_view(), name="report_export"),' not in text:
    text = text.replace(
        '    path("reports/basic/", PaymentRequestReportView.as_view(), name="report"),\n',
        '    path("reports/basic/", PaymentRequestReportView.as_view(), name="report"),\n    path("reports/basic/export/", PaymentRequestReportExportView.as_view(), name="report_export"),\n',
        1,
    )
urls.write_text(text, encoding="utf-8")

template = Path("backend/templates/payment_requests/paymentrequest_report.html")
text = template.read_text(encoding="utf-8")
export_form = '''\n    <form method="get" action="{% url 'payment_requests:report_export' %}" class="mb-4">\n      <input type="hidden" name="status" value="{{ filter_status }}">\n      <input type="hidden" name="company" value="{{ filter_company }}">\n      <input type="hidden" name="date_from" value="{{ filter_date_from }}">\n      <input type="hidden" name="date_to" value="{{ filter_date_to }}">\n      <button type="submit" class="btn btn-secondary">Exportar CSV</button>\n    </form>\n'''
if "Exportar CSV" not in text:
    text = text.replace("\n    <div class=\"row mb-4\">", export_form + "\n    <div class=\"row mb-4\">", 1)
template.write_text(text, encoding="utf-8")

# Tests
report_tests = Path("backend/apps/payment_requests/tests/test_reports.py")
text = report_tests.read_text(encoding="utf-8")
append = '''\n\n    def test_report_export_requires_login(self):\n        response = self.client.get(reverse("payment_requests:report_export"))\n\n        self.assertEqual(response.status_code, 302)\n\n    def test_solicitante_cannot_export_report(self):\n        self.client.force_login(self.requester)\n\n        response = self.client.get(reverse("payment_requests:report_export"))\n\n        self.assertEqual(response.status_code, 403)\n\n    def test_finance_user_can_export_filtered_report_as_csv(self):\n        self.client.force_login(self.finance_user)\n        self.create_payment_request(\n            self.company,\n            self.beneficiary,\n            self.finance_user,\n            PaymentRequestStatus.APPROVED,\n            "Exportable dentro del rango",\n            date(2026, 7, 15),\n        )\n        self.create_payment_request(\n            self.company,\n            self.beneficiary,\n            self.finance_user,\n            PaymentRequestStatus.REJECTED,\n            "No exportable por estado",\n            date(2026, 7, 15),\n        )\n        self.create_payment_request(\n            self.other_company,\n            self.other_beneficiary,\n            self.other_user,\n            PaymentRequestStatus.APPROVED,\n            "No exportable por empresa",\n            date(2026, 7, 15),\n        )\n\n        response = self.client.get(\n            reverse("payment_requests:report_export"),\n            {\n                "status": PaymentRequestStatus.APPROVED,\n                "date_from": "2026-07-01",\n                "date_to": "2026-07-31",\n            },\n        )\n\n        self.assertEqual(response.status_code, 200)\n        self.assertEqual(response["Content-Type"], "text/csv; charset=utf-8")\n        self.assertIn("attachment;", response["Content-Disposition"])\n        content = response.content.decode("utf-8-sig")\n        self.assertIn("Empresa,Beneficiario,Concepto,Estado", content)\n        self.assertIn("Exportable dentro del rango", content)\n        self.assertNotIn("No exportable por estado", content)\n        self.assertNotIn("No exportable por empresa", content)\n\n    def test_report_screen_exposes_export_action(self):\n        self.client.force_login(self.finance_user)\n\n        response = self.client.get(self.url)\n\n        self.assertContains(response, "Exportar CSV")\n        self.assertContains(response, reverse("payment_requests:report_export"))\n'''
if "test_finance_user_can_export_filtered_report_as_csv" not in text:
    text = text.rstrip() + append + "\n"
report_tests.write_text(text, encoding="utf-8")

# Docs
Path("docs/f2_p10_exportacion_operativa_basica.md").write_text('''# F2-P10 - Exportacion operativa basica\n\n## Objetivo\n\nAgregar exportacion CSV basica sobre el reporte operativo de solicitudes de pago implementado en F2-P09.\n\n## Alcance implementado\n\n- Nueva ruta `payment_requests:report_export` en `/payment-requests/reports/basic/export/`.\n- Nueva vista `PaymentRequestReportExportView`.\n- Exportacion CSV con los mismos filtros de estado, empresa y rango de fecha del reporte en pantalla.\n- Reutilizacion de `scoped_payment_request_queryset` y del permiso `payment_requests.view_report`.\n- Boton `Exportar CSV` en el reporte operativo.\n- Pruebas de login, permisos, alcance por empresa, filtros y respuesta CSV.\n\n## Campos exportados\n\n- Empresa.\n- Beneficiario.\n- Concepto.\n- Estado.\n- Fecha de vencimiento.\n- Monto.\n- Moneda.\n- Solicitado por.\n\n## Decision tecnica\n\nNo se crean modelos ni migraciones. La exportacion usa la misma consulta filtrada del reporte para evitar divergencia de reglas de negocio.\n''', encoding="utf-8")

roadmap = Path("docs/roadmap_fase2.md")
text = roadmap.read_text(encoding="utf-8")
text = text.replace("| 10 | F2-P10 | Exportacion operativa basica |", "| 10 | F2-P10 | Cerrado - Exportacion operativa basica |")
text = text.replace("Ejecutar F2-P10 con foco en:", "Ejecutar F2-P11 con foco en:")
text = text.replace("- Exportacion operativa basica del reporte.\n- Reutilizar filtros de estado, empresa y fecha.\n- Mantener alcance por empresa y permisos centralizados.\n- Sin modelos nuevos salvo necesidad justificada.\n- Sin migraciones salvo necesidad justificada.", "- Auditoria extendida.\n- Reforzar trazabilidad operativa sobre acciones criticas.\n- Mantener permisos centralizados.\n- Sin modelos nuevos salvo necesidad justificada.\n- Sin migraciones salvo necesidad justificada.")
roadmap.write_text(text, encoding="utf-8")
PY

echo "OK: F2-P10 aplicado a codigo, tests y documentacion."
echo "== Archivos F2-P10 =="
git status --short

echo "== Validando diff whitespace =="
git diff --check

echo "== Ruff focal F2-P10 =="
docker compose exec backend ruff check \
  apps/payment_requests/views.py \
  apps/payment_requests/urls.py \
  apps/payment_requests/tests/test_reports.py

echo "== Tests focales F2-P10 =="
docker compose exec backend python manage.py test \
  apps.payment_requests.tests.test_reports

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== F2-P10 implementacion focal OK =="
