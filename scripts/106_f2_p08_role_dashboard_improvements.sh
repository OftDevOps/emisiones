#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_ROOT"

echo "== F2-P08: dashboard operativo mejorado por rol =="

VIEW_FILE="backend/apps/payment_requests/views.py"
DASHBOARD_TEMPLATE="backend/templates/payment_requests/paymentrequest_dashboard.html"
DASHBOARD_TEST="backend/apps/payment_requests/tests/test_dashboard.py"
ACCOUNTS_PAYABLE_TEST="backend/apps/payment_requests/tests/test_accounts_payable_workbench.py"
DOC_FILE="docs/f2_p08_dashboard_operativo_por_rol.md"
MATRIX_DOC="docs/matriz_dashboard_operativo_por_rol_fase2.md"
ROADMAP="docs/roadmap_fase2.md"

echo "== Verificando precondiciones =="
for required in "$VIEW_FILE" "$DASHBOARD_TEMPLATE" "$DASHBOARD_TEST" "$ACCOUNTS_PAYABLE_TEST" "$ROADMAP"; do
  if [ ! -f "$required" ]; then
    echo "ERROR: falta $required"
    exit 1
  fi
  echo "OK: $required"
done

grep -q "F2-P08 | Dashboard operativo mejorado por rol" "$ROADMAP"
grep -q "role_nav.can_view_accounts_payable" "backend/templates/base.html"
grep -q "PERM_VIEW_ACCOUNTS_PAYABLE" "backend/apps/accounts/role_permissions.py"

echo "== Ajustando permisos backend de Cuentas por Pagar segun matriz operativa =="
python3 - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_requests/views.py")
text = path.read_text(encoding="utf-8")

if "PERM_VIEW_ACCOUNTS_PAYABLE," not in text:
    text = text.replace(
        "from apps.accounts.role_permissions import (\n",
        "from apps.accounts.role_permissions import (\n    PERM_VIEW_ACCOUNTS_PAYABLE,\n",
    )

if "PERM_VIEW_AUDIT_WORKBENCH," not in text:
    text = text.replace(
        "from apps.accounts.role_permissions import (\n",
        "from apps.accounts.role_permissions import (\n    PERM_VIEW_AUDIT_WORKBENCH,\n",
    )

old_dispatch = '''    def dispatch(self, request, *args, **kwargs):
        user = request.user
        if not user.is_authenticated:
            return super().dispatch(request, *args, **kwargs)

        if not user.is_superuser and user.role != UserRole.CUENTAS_POR_PAGAR:
            raise PermissionDenied("Su rol no permite acceder a Cuentas por Pagar.")

        return super().dispatch(request, *args, **kwargs)
'''
new_dispatch = '''    def dispatch(self, request, *args, **kwargs):
        user = request.user
        if not user.is_authenticated:
            return super().dispatch(request, *args, **kwargs)

        if not user.is_superuser:
            _require_operational_permission(
                user,
                PERM_VIEW_ACCOUNTS_PAYABLE,
                "Su rol no permite acceder a Cuentas por Pagar.",
            )

        return super().dispatch(request, *args, **kwargs)
'''
if old_dispatch in text:
    text = text.replace(old_dispatch, new_dispatch)
elif "PERM_VIEW_ACCOUNTS_PAYABLE" not in text[text.find("class AccountsPayablePendingView"):text.find("class PaymentRequestDashboardView")]:
    raise SystemExit("ERROR: no se pudo ajustar dispatch de AccountsPayablePendingView.")

old_context = '''        context["total_requests"] = payment_requests.count()
        context["status_cards"] = status_cards
        context["latest_requests"] = payment_requests.order_by("-created_at")[:10]
        context["pending_approval_steps"] = pending_steps
        return context
'''
new_context = '''        pending_payment_requests = payment_requests.filter(
            status=PaymentRequestStatus.APPROVED,
            payment_execution__isnull=True,
        ).order_by("due_date", "-updated_at", "-created_at")[:10]

        audit_action_count = (
            PaymentApprovalAction.objects.filter(payment_request__in=payment_requests).count()
            if user_has_permission(user, PERM_VIEW_AUDIT_WORKBENCH)
            else 0
        )

        context["total_requests"] = payment_requests.count()
        context["status_cards"] = status_cards
        context["latest_requests"] = payment_requests.order_by("-created_at")[:10]
        context["pending_approval_steps"] = pending_steps
        context["pending_payment_requests"] = pending_payment_requests
        context["pending_payment_count"] = pending_payment_requests.count()
        context["audit_action_count"] = audit_action_count
        context["dashboard_role_label"] = user.get_role_display() if hasattr(user, "get_role_display") else user.role
        context["dashboard_scope_label"] = (
            "Todas las empresas"
            if user.is_superuser
            else str(user.primary_company)
            if getattr(user, "primary_company_id", None)
            else "Sin empresa primaria asignada"
        )
        return context
'''
if old_context in text:
    text = text.replace(old_context, new_context)
elif 'context["pending_payment_requests"]' not in text:
    raise SystemExit("ERROR: no se pudo insertar contexto de dashboard por rol.")

text = text.replace("from django.core.exceptions import PermissionDenied, ValidationError\n", "from django.core.exceptions import ValidationError\n")

path.write_text(text, encoding="utf-8")
PY

echo "== Reescribiendo template de dashboard por rol =="
cat > "$DASHBOARD_TEMPLATE" <<'HTML'
{% extends "base.html" %}

{% block content %}
<h1>Dashboard operativo de solicitudes</h1>

<section>
  <h2>Perfil operativo</h2>
  <p><strong>Rol:</strong> {{ dashboard_role_label }}</p>
  <p><strong>Alcance:</strong> {{ dashboard_scope_label }}</p>
</section>

<section>
  <h2>Accesos operativos</h2>

  {% if role_nav.can_view_pending_approvals or role_nav.can_view_audit_workbench or role_nav.can_view_accounts_payable %}
    <ul>
      {% if role_nav.can_view_pending_approvals %}
        <li><a href="{% url 'payment_approvals:pending' %}">Pendientes por aprobar</a></li>
      {% endif %}
      {% if role_nav.can_view_audit_workbench %}
        <li><a href="{% url 'payment_approvals:audit' %}">Auditoría de acciones críticas</a></li>
      {% endif %}
      {% if role_nav.can_view_accounts_payable %}
        <li><a href="{% url 'payment_requests:accounts_payable' %}">Cuentas por Pagar</a></li>
      {% endif %}
    </ul>
  {% else %}
    <p>No tienes accesos operativos adicionales para tu rol.</p>
  {% endif %}
</section>

<section>
  <h2>Resumen ejecutivo</h2>
  <p><strong>Total de solicitudes:</strong> {{ total_requests }}</p>

  <div>
    {% for card in status_cards %}
      <article>
        <h3>{{ card.label }}</h3>
        <p>{{ card.total }}</p>
      </article>
    {% endfor %}
  </div>
</section>

{% if role_nav.can_view_accounts_payable %}
<section>
  <h2>Solicitudes aprobadas pendientes de pago</h2>
  <p><strong>Total pendiente de pago:</strong> {{ pending_payment_count }}</p>

  {% if pending_payment_requests %}
    <table>
      <thead>
        <tr>
          <th>ID</th>
          <th>Empresa</th>
          <th>Beneficiario</th>
          <th>Monto</th>
          <th>Fecha estimada</th>
          <th>Acción</th>
        </tr>
      </thead>
      <tbody>
        {% for payment_request in pending_payment_requests %}
          <tr>
            <td>#{{ payment_request.id }}</td>
            <td>{{ payment_request.company }}</td>
            <td>{{ payment_request.beneficiary }}</td>
            <td>{{ payment_request.amount }} {{ payment_request.currency }}</td>
            <td>{{ payment_request.due_date|default:"Sin fecha" }}</td>
            <td>
              <a href="{% url 'payment_requests:detail' payment_request.pk %}">Ver solicitud</a>
            </td>
          </tr>
        {% endfor %}
      </tbody>
    </table>
  {% else %}
    <p>No hay solicitudes aprobadas pendientes de pago.</p>
  {% endif %}
</section>
{% endif %}

{% if role_nav.can_view_audit_workbench %}
<section>
  <h2>Auditoría operativa</h2>
  <p><strong>Acciones registradas en el alcance:</strong> {{ audit_action_count }}</p>
  <p><a href="{% url 'payment_approvals:audit' %}">Ir a auditoría de acciones críticas</a></p>
</section>
{% endif %}

<section>
  <h2>Pendientes de aprobación para mi rol</h2>

  {% if pending_approval_steps %}
    <table>
      <thead>
        <tr>
          <th>Solicitud</th>
          <th>Empresa</th>
          <th>Beneficiario</th>
          <th>Monto</th>
          <th>Paso</th>
          <th>Acción</th>
        </tr>
      </thead>
      <tbody>
        {% for step in pending_approval_steps %}
          <tr>
            <td>#{{ step.payment_request.id }}</td>
            <td>{{ step.payment_request.company }}</td>
            <td>{{ step.payment_request.beneficiary }}</td>
            <td>{{ step.payment_request.amount }} {{ step.payment_request.currency }}</td>
            <td>{{ step.sequence }}</td>
            <td>
              <a href="{% url 'payment_requests:detail' step.payment_request.pk %}">
                Ver solicitud
              </a>
            </td>
          </tr>
        {% endfor %}
      </tbody>
    </table>
  {% else %}
    <p>No hay aprobaciones pendientes para tu rol.</p>
  {% endif %}
</section>

<section>
  <h2>Últimas solicitudes</h2>

  {% if latest_requests %}
    <table>
      <thead>
        <tr>
          <th>ID</th>
          <th>Empresa</th>
          <th>Beneficiario</th>
          <th>Concepto</th>
          <th>Monto</th>
          <th>Estado</th>
          <th>Creada</th>
        </tr>
      </thead>
      <tbody>
        {% for payment_request in latest_requests %}
          <tr>
            <td>
              <a href="{% url 'payment_requests:detail' payment_request.pk %}">
                #{{ payment_request.id }}
              </a>
            </td>
            <td>{{ payment_request.company }}</td>
            <td>{{ payment_request.beneficiary }}</td>
            <td>{{ payment_request.concept }}</td>
            <td>{{ payment_request.amount }} {{ payment_request.currency }}</td>
            <td>{{ payment_request.get_status_display }}</td>
            <td>{{ payment_request.created_at }}</td>
          </tr>
        {% endfor %}
      </tbody>
    </table>
  {% else %}
    <p>No hay solicitudes registradas.</p>
  {% endif %}
</section>

<p>
  <a href="{% url 'payment_requests:list' %}">Volver a solicitudes</a>
</p>
{% endblock %}
HTML

echo "== Ajustando pruebas existentes de dashboard =="
python3 - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_requests/tests/test_dashboard.py")
text = path.read_text(encoding="utf-8")

old = '''    def test_dashboard_shows_operational_access_links(self):
        self.client.force_login(self.user)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Accesos operativos")
        self.assertContains(response, "Pendientes por aprobar")
        self.assertContains(response, "Auditoría de acciones críticas")
        self.assertContains(response, "Cuentas por Pagar")
        self.assertContains(response, reverse("payment_approvals:pending"))
        self.assertContains(response, reverse("payment_approvals:audit"))
        self.assertContains(response, reverse("payment_requests:accounts_payable"))
'''
new = '''    def test_dashboard_shows_operational_access_links_by_role(self):
        self.client.force_login(self.user)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Accesos operativos")
        self.assertContains(response, "Pendientes por aprobar")
        self.assertContains(response, "Cuentas por Pagar")
        self.assertContains(response, reverse("payment_approvals:pending"))
        self.assertContains(response, reverse("payment_requests:accounts_payable"))
        self.assertNotContains(response, "Auditoría de acciones críticas")
        self.assertNotContains(response, reverse("payment_approvals:audit"))
'''
if old in text:
    text = text.replace(old, new)

append = r'''
    def test_dashboard_hides_operational_links_for_solicitante(self):
        solicitante = self.create_user(
            "solicitante.dashboard@example.com",
            self.company,
            UserRole.SOLICITANTE,
        )
        self.client.force_login(solicitante)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "No tienes accesos operativos adicionales para tu rol.")
        self.assertNotContains(response, "Pendientes por aprobar")
        self.assertNotContains(response, "Auditoría de acciones críticas")
        self.assertNotContains(response, "Cuentas por Pagar")

    def test_dashboard_shows_audit_panel_only_for_auditor(self):
        auditor = self.create_user(
            "auditor.dashboard@example.com",
            self.company,
            UserRole.AUDITOR,
        )
        self.client.force_login(auditor)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Auditoría operativa")
        self.assertContains(response, "Ir a auditoría de acciones críticas")
        self.assertContains(response, reverse("payment_approvals:audit"))
        self.assertNotContains(response, "Pendientes por aprobar")
        self.assertNotContains(response, "Cuentas por Pagar")

    def test_dashboard_shows_pending_payment_panel_for_accounts_payable_roles(self):
        self.client.force_login(self.user)
        self.create_payment_request(
            self.company,
            self.beneficiary,
            self.user,
            PaymentRequestStatus.APPROVED,
            "Pago aprobado pendiente",
        )

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Solicitudes aprobadas pendientes de pago")
        self.assertContains(response, "Total pendiente de pago:")
        self.assertContains(response, "Pago aprobado pendiente")
'''
if "test_dashboard_hides_operational_links_for_solicitante" not in text:
    text = text.rstrip() + "\n" + append + "\n"

path.write_text(text, encoding="utf-8")
PY

echo "== Agregando cobertura de Cuentas por Pagar para FINANZAS segun matriz =="
python3 - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_requests/tests/test_accounts_payable_workbench.py")
text = path.read_text(encoding="utf-8")

append = r'''
    def test_finance_user_can_access_accounts_payable_per_permission_matrix(self):
        finance_user = self.create_user(
            "finanzas.cxp@oftalmi.com",
            self.company,
            UserRole.FINANZAS,
        )
        self.client.force_login(finance_user)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, "payment_requests/accounts_payable_pending.html")
'''
if "test_finance_user_can_access_accounts_payable_per_permission_matrix" not in text:
    text = text.rstrip() + "\n" + append + "\n"

path.write_text(text, encoding="utf-8")
PY

echo "== Creando documentacion F2-P08 =="
cat > "$DOC_FILE" <<'MD'
# F2-P08 - Dashboard operativo mejorado por rol

## Objetivo

Mejorar el dashboard operativo de solicitudes para que los indicadores y accesos visibles respondan al rol del usuario y a la matriz UX-permisos de Fase 2.

## Alcance implementado

- Se agrego perfil operativo visible: rol y alcance empresarial.
- Los accesos operativos del dashboard ahora se muestran segun `role_nav`.
- El panel de Cuentas por Pagar solo aparece para roles con permiso visual/operativo.
- El panel de Auditoria solo aparece para roles con permiso de auditoria.
- Se agregaron pruebas especificas para Solicitante, Finanzas y Auditor.
- Se alineo el acceso backend de Cuentas por Pagar con `PERM_VIEW_ACCOUNTS_PAYABLE`.

## Decision tecnica

El dashboard no sustituye permisos backend. La plantilla solo mejora la experiencia y reduce enlaces rotos. Las vistas siguen siendo la fuente de autorizacion real.

## Hallazgo corregido

La matriz de permisos permitia `payment_requests.view_accounts_payable` a roles definidos en `PERM_VIEW_ACCOUNTS_PAYABLE`, pero la vista de Cuentas por Pagar estaba acoplada a `CUENTAS_POR_PAGAR`.

F2-P08 alinea esa vista con la matriz centralizada.
MD

cat > "$MATRIX_DOC" <<'MD'
# Matriz de dashboard operativo por rol - Fase 2

## Regla base

El dashboard usa `role_nav` para visibilidad UX y permisos backend para autorizacion efectiva.

## Paneles y accesos

| Elemento | Variable / permiso | Resultado |
|---|---|---|
| Perfil operativo | usuario autenticado | Muestra rol y alcance |
| Pendientes por aprobar | `role_nav.can_view_pending_approvals` | Enlace a bandeja de aprobaciones |
| Cuentas por Pagar | `role_nav.can_view_accounts_payable` | Enlace y panel de aprobadas pendientes de pago |
| Auditoria operativa | `role_nav.can_view_audit_workbench` | Enlace y total de acciones auditables |
| Ultimas solicitudes | alcance por empresa | Listado acotado al usuario |

## Criterio de control

- Solicitante: sin accesos operativos adicionales.
- Finanzas: aprobaciones y Cuentas por Pagar, segun matriz vigente.
- Auditor: auditoria operativa.
- Cuentas por Pagar: panel operativo de solicitudes aprobadas pendientes.
MD

python3 - <<'PY'
from pathlib import Path

path = Path("docs/roadmap_fase2.md")
text = path.read_text(encoding="utf-8")
old = '''## Siguiente accion

Ejecutar F2-P08 con foco en:

- Dashboard operativo por rol.
- Indicadores visibles segun permisos.
- Enlaces de accion coherentes con la matriz UX-permisos.
- Sin modelos nuevos salvo necesidad justificada.
- Sin migraciones salvo necesidad justificada.
'''
new = '''## Siguiente accion

Ejecutar F2-P09 con foco en:

- Reporte basico por estado, empresa y fecha.
- Filtros operativos coherentes con alcance por empresa.
- Reporte visible solo para roles autorizados.
- Sin modelos nuevos salvo necesidad justificada.
- Sin migraciones salvo necesidad justificada.
'''
if old in text:
    text = text.replace(old, new)
elif "Ejecutar F2-P09 con foco en:" not in text:
    raise SystemExit("ERROR: no se pudo actualizar la siguiente accion del roadmap.")

path.write_text(text, encoding="utf-8")
PY

echo "== Ruff focal =="
docker compose exec backend ruff check apps/payment_requests/views.py apps/payment_requests/tests/test_dashboard.py apps/payment_requests/tests/test_accounts_payable_workbench.py

echo "== Tests focales F2-P08 =="
docker compose exec backend python manage.py test apps.payment_requests.tests.test_dashboard apps.payment_requests.tests.test_accounts_payable_workbench

echo "== Validacion global rapida =="
docker compose exec backend ruff check .
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== Estado posterior =="
git status --short
