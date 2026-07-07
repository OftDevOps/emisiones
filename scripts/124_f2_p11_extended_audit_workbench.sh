#!/usr/bin/env bash
set -euo pipefail

cd /home/dchirinos/oftalmiIA/emisiones/emisiones

echo "== F2-P11: auditoria extendida sobre workbench existente =="
echo "== Estado inicial =="
git status --short

python3 - <<'PY'
from pathlib import Path

views_path = Path("backend/apps/payment_approvals/views.py")
text = views_path.read_text(encoding="utf-8")

# Add Count import if missing.
text = text.replace(
    "from django.contrib.auth.mixins import LoginRequiredMixin\n",
    "from django.contrib.auth.mixins import LoginRequiredMixin\nfrom django.db.models import Count\n",
)

old_get_queryset = '''    def get_queryset(self):
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
'''
new_get_queryset = '''    def get_base_queryset(self):
        user = self.request.user
        queryset = PaymentApprovalAction.objects.select_related(
            "payment_request",
            "payment_request__company",
            "payment_request__beneficiary",
            "performed_by",
            "step",
        )

        if not user.is_superuser:
            if not getattr(user, "primary_company_id", None):
                return queryset.none()
            queryset = queryset.filter(payment_request__company_id=user.primary_company_id)

        return queryset

    def get_queryset(self):
        queryset = self.get_base_queryset().order_by("-created_at", "-id")

        action = self.request.GET.get("action", "").strip()
        company = self.request.GET.get("company", "").strip()
        date_from = self.request.GET.get("date_from", "").strip()
        date_to = self.request.GET.get("date_to", "").strip()
        user_query = self.request.GET.get("user", "").strip()
        request_query = self.request.GET.get("request", "").strip()

        if action:
            queryset = queryset.filter(action=action)
        if company:
            queryset = queryset.filter(payment_request__company_id=company)
        if date_from:
            queryset = queryset.filter(created_at__date__gte=date_from)
        if date_to:
            queryset = queryset.filter(created_at__date__lte=date_to)
        if user_query:
            queryset = queryset.filter(performed_by__email__icontains=user_query)
        if request_query:
            queryset = queryset.filter(payment_request__concept__icontains=request_query)

        return queryset
'''
if old_get_queryset not in text:
    raise SystemExit("ERROR: bloque get_queryset de auditoria no encontrado.")
text = text.replace(old_get_queryset, new_get_queryset)

old_context = '''    def get_context_data(self, **kwargs):
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
new_context = '''    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        actions_queryset = self.get_base_queryset().select_related("payment_request__company")

        companies = []
        seen_company_ids = set()
        for action in actions_queryset.order_by("payment_request__company__name"):
            company = action.payment_request.company
            if company.pk not in seen_company_ids:
                seen_company_ids.add(company.pk)
                companies.append(company)

        action_summary = list(
            self.object_list.values("action")
            .annotate(total=Count("id"))
            .order_by("action")
        )
        company_summary = list(
            self.object_list.values("payment_request__company__name")
            .annotate(total=Count("id"))
            .order_by("payment_request__company__name")
        )

        context["action_choices"] = ApprovalActionType.choices
        context["companies"] = companies
        context["filters"] = {
            "action": self.request.GET.get("action", "").strip(),
            "company": self.request.GET.get("company", "").strip(),
            "date_from": self.request.GET.get("date_from", "").strip(),
            "date_to": self.request.GET.get("date_to", "").strip(),
            "user": self.request.GET.get("user", "").strip(),
            "request": self.request.GET.get("request", "").strip(),
        }
        context["total_actions"] = self.object_list.count()
        context["action_summary"] = action_summary
        context["company_summary"] = company_summary
        return context
'''
if old_context not in text:
    raise SystemExit("ERROR: bloque get_context_data de auditoria no encontrado.")
text = text.replace(old_context, new_context)
views_path.write_text(text, encoding="utf-8")

# Update audit template.
template_path = Path("backend/templates/payment_approvals/cross_action_audit_workbench.html")
tpl = template_path.read_text(encoding="utf-8")

tpl = tpl.replace(
'''      <div class="col-md-2">
        <label class="form-label" for="id_date_to">Hasta</label>
        <input class="form-control" type="date" id="id_date_to" name="date_to" value="{{ filters.date_to }}">
      </div>
      <div class="col-md-2 d-flex gap-2">
        <button class="btn btn-primary" type="submit">Filtrar</button>
        <a class="btn btn-outline-secondary" href="{% url 'payment_approvals:audit' %}">Limpiar</a>
      </div>
''',
'''      <div class="col-md-2">
        <label class="form-label" for="id_date_to">Hasta</label>
        <input class="form-control" type="date" id="id_date_to" name="date_to" value="{{ filters.date_to }}">
      </div>
      <div class="col-md-3">
        <label class="form-label" for="id_user">Usuario</label>
        <input class="form-control" type="search" id="id_user" name="user" value="{{ filters.user }}" placeholder="correo usuario">
      </div>
      <div class="col-md-3">
        <label class="form-label" for="id_request">Solicitud</label>
        <input class="form-control" type="search" id="id_request" name="request" value="{{ filters.request }}" placeholder="concepto solicitud">
      </div>
      <div class="col-md-3 d-flex gap-2">
        <button class="btn btn-primary" type="submit">Filtrar</button>
        <a class="btn btn-outline-secondary" href="{% url 'payment_approvals:audit' %}">Limpiar</a>
      </div>
''')

insert = '''
<div class="row mb-3">
  <div class="col-md-6">
    <div class="card h-100">
      <div class="card-header">Resumen por acción</div>
      <div class="card-body p-0">
        <table class="table table-sm mb-0">
          <thead>
            <tr>
              <th>Acción</th>
              <th class="text-end">Total</th>
            </tr>
          </thead>
          <tbody>
            {% for row in action_summary %}
              <tr>
                <td>{{ row.action }}</td>
                <td class="text-end">{{ row.total }}</td>
              </tr>
            {% empty %}
              <tr><td colspan="2" class="text-muted">Sin acciones para los filtros seleccionados.</td></tr>
            {% endfor %}
          </tbody>
        </table>
      </div>
    </div>
  </div>
  <div class="col-md-6">
    <div class="card h-100">
      <div class="card-header">Resumen por empresa</div>
      <div class="card-body p-0">
        <table class="table table-sm mb-0">
          <thead>
            <tr>
              <th>Empresa</th>
              <th class="text-end">Total</th>
            </tr>
          </thead>
          <tbody>
            {% for row in company_summary %}
              <tr>
                <td>{{ row.payment_request__company__name }}</td>
                <td class="text-end">{{ row.total }}</td>
              </tr>
            {% empty %}
              <tr><td colspan="2" class="text-muted">Sin empresas para los filtros seleccionados.</td></tr>
            {% endfor %}
          </tbody>
        </table>
      </div>
    </div>
  </div>
</div>
'''
if '<div class="card">\n  <div class="card-header d-flex justify-content-between align-items-center">' not in tpl:
    raise SystemExit("ERROR: punto de insercion de resumen no encontrado en template auditoria.")
tpl = tpl.replace('<div class="card">\n  <div class="card-header d-flex justify-content-between align-items-center">', insert + '\n<div class="card">\n  <div class="card-header d-flex justify-content-between align-items-center">')

# Add request concept column.
tpl = tpl.replace(
'''          <th>Solicitud</th>
          <th>Empresa</th>
          <th>Acción</th>
''',
'''          <th>Solicitud</th>
          <th>Concepto</th>
          <th>Empresa</th>
          <th>Acción</th>
''')
tpl = tpl.replace(
'''            <td>
              <a href="{% url 'payment_requests:detail' action.payment_request.pk %}">#{{ action.payment_request.pk }}</a>
            </td>
            <td>{{ action.payment_request.company.name }}</td>
''',
'''            <td>
              <a href="{% url 'payment_requests:detail' action.payment_request.pk %}">#{{ action.payment_request.pk }}</a>
            </td>
            <td>{{ action.payment_request.concept }}</td>
            <td>{{ action.payment_request.company.name }}</td>
''')
tpl = tpl.replace('colspan="7"', 'colspan="8"')
template_path.write_text(tpl, encoding="utf-8")

# Extend tests.
test_path = Path("backend/apps/payment_approvals/tests/test_cross_action_audit_workbench.py")
test = test_path.read_text(encoding="utf-8")
append = '''

    def test_filter_by_user_email(self):
        self.client.force_login(self.superuser)

        response = self.client.get(self.url(), {"user": "auditor.audit.otra"})

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Rechazo otra empresa")
        self.assertNotContains(response, "Pago ejecutado REF-AUDIT-01")

    def test_filter_by_request_concept(self):
        self.client.force_login(self.superuser)

        response = self.client.get(self.url(), {"request": "otra empresa"})

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Pago auditado otra empresa")
        self.assertContains(response, "Rechazo otra empresa")
        self.assertNotContains(response, "Pago ejecutado REF-AUDIT-01")

    def test_audit_workbench_shows_extended_summaries(self):
        self.client.force_login(self.superuser)

        response = self.client.get(self.url())

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Resumen por acción")
        self.assertContains(response, "Resumen por empresa")
        self.assertContains(response, "Concepto")
        self.assertContains(response, "Pago auditado")
'''
if "test_filter_by_user_email" not in test:
    test = test.rstrip() + append + "\n"
test_path.write_text(test, encoding="utf-8")

# Docs and roadmap.
doc_path = Path("docs/f2_p11_auditoria_extendida.md")
doc_path.write_text('''# F2-P11 - Auditoria extendida

## Objetivo

Extender el workbench de auditoria transversal sin crear modelos nuevos ni migraciones, reforzando trazabilidad operativa para revision interna.

## Alcance implementado

- Se reutiliza `PaymentApprovalAction` como fuente de auditoria transversal.
- Se mantiene la ruta `payment_approvals:audit` en `/payment-approvals/audit/`.
- Se agregan filtros por usuario ejecutor y concepto de solicitud.
- Se agregan resumenes por accion y por empresa sobre el resultado filtrado.
- Se agrega columna de concepto de solicitud al historial transversal.
- Se mantiene alcance por empresa para usuarios no superuser.
- Se mantiene permiso centralizado `payment_approvals.view_audit`.

## Roles autorizados

- Administrador.
- Auditor.

## Decision tecnica

No se crean modelos ni migraciones. La auditoria extendida mejora la explotacion del registro transversal existente y evita introducir una segunda fuente de verdad.

## Validacion esperada

- `ruff check` sin errores.
- `manage.py check` sin errores.
- `makemigrations --check --dry-run` sin cambios.
- Pruebas focales de auditoria en verde.
- Suite principal en verde antes del commit.
''', encoding="utf-8")

roadmap = Path("docs/roadmap_fase2.md")
road = roadmap.read_text(encoding="utf-8")
road = road.replace("| 11 | F2-P11 | Auditoria extendida |", "| 11 | F2-P11 | Cerrado - Auditoria extendida |")
road = road.replace(
'''Ejecutar F2-P11 con foco en:

- Auditoria extendida.
- Reforzar trazabilidad operativa sobre acciones criticas.
- Mantener permisos centralizados.
- Sin modelos nuevos salvo necesidad justificada.
- Sin migraciones salvo necesidad justificada.
''',
'''Ejecutar F2-P12 con foco en:

- Paquete de validacion con usuarios internos.
- Escenarios operativos por rol.
- Evidencias de flujos criticos.
- Checklist UAT para piloto interno.
- Sin modelos nuevos salvo necesidad justificada.
- Sin migraciones salvo necesidad justificada.
''')
roadmap.write_text(road, encoding="utf-8")

print("OK: F2-P11 aplicado a vista, template, tests y documentacion.")
PY

echo "== Archivos F2-P11 =="
git status --short

echo "== Validando diff whitespace =="
git diff --check

echo "== Ruff focal F2-P11 =="
docker compose exec backend ruff check \
  apps/payment_approvals/views.py \
  apps/payment_approvals/tests/test_cross_action_audit_workbench.py

echo "== Tests focales F2-P11 =="
docker compose exec backend python manage.py test \
  apps.payment_approvals.tests.test_cross_action_audit_workbench

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== F2-P11 implementacion focal OK =="
