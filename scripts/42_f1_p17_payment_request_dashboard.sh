#!/usr/bin/env bash
set -euo pipefail

# F1-P17 - Dashboard operativo de solicitudes
# Proyecto: OftDevOps/emisiones
#
# Uso:
#   cd /home/dchirinos/oftalmiIA/emisiones/emisiones
#   cp /ruta/descarga/42_f1_p17_payment_request_dashboard.sh scripts/42_f1_p17_payment_request_dashboard.sh
#   chmod +x scripts/42_f1_p17_payment_request_dashboard.sh
#   ./scripts/42_f1_p17_payment_request_dashboard.sh
#
# Este playbook:
# - Valida que se ejecute sobre la rama feature/payment-request-dashboard.
# - Modifica payment_requests/views.py de forma idempotente.
# - Agrega ruta /payment-requests/dashboard/.
# - Crea template paymentrequest_dashboard.html.
# - Agrega pruebas automatizadas del dashboard.
# - No crea modelos.
# - No crea migraciones.
# - No ejecuta commit.
#
# Luego debes correr el bloque estándar de validación Docker/NordVPN.

EXPECTED_BRANCH="feature/payment-request-dashboard"

echo "== F1-P17: Dashboard operativo de solicitudes =="

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "ERROR: este directorio no parece ser un repositorio Git."
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if [ ! -d "backend/apps/payment_requests" ]; then
  echo "ERROR: no se encontró backend/apps/payment_requests. Ejecuta desde la raíz del repo emisiones."
  exit 1
fi

CURRENT_BRANCH="$(git branch --show-current)"
if [ "$CURRENT_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ERROR: rama incorrecta."
  echo "Actual:   $CURRENT_BRANCH"
  echo "Esperada: $EXPECTED_BRANCH"
  exit 1
fi

echo "== Git status antes de aplicar cambios =="
git status --short

python3 - <<'PY'
from pathlib import Path

views_path = Path("backend/apps/payment_requests/views.py")
urls_path = Path("backend/apps/payment_requests/urls.py")
template_dir = Path("backend/templates/payment_requests")
dashboard_template_path = template_dir / "paymentrequest_dashboard.html"
list_template_path = template_dir / "paymentrequest_list.html"
tests_path = Path("backend/apps/payment_requests/tests/test_dashboard.py")

required_files = [views_path, urls_path]
for required_file in required_files:
    if not required_file.exists():
        raise SystemExit(f"ERROR: archivo requerido no existe: {required_file}")

views = views_path.read_text()

if "from django.db.models import Count" not in views:
    views = views.replace(
        "from django.core.exceptions import ValidationError\n",
        "from django.core.exceptions import ValidationError\nfrom django.db.models import Count\n",
    )

if "TemplateView" not in views:
    views = views.replace(
        "from django.views.generic import CreateView, DetailView, ListView",
        "from django.views.generic import CreateView, DetailView, ListView, TemplateView",
    )

single_approval_import = "from apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction"
multi_approval_import = (
    "from apps.payment_approvals.models import (\n"
    "    ApprovalActionType,\n"
    "    ApprovalStepStatus,\n"
    "    PaymentApprovalAction,\n"
    "    PaymentApprovalStep,\n"
    ")"
)
if single_approval_import in views:
    views = views.replace(single_approval_import, multi_approval_import)

old_scope = '''def scoped_payment_request_queryset(user):
    queryset = PaymentRequest.objects.select_related("company", "beneficiary", "requested_by")

    if not user.is_superuser and getattr(user, "primary_company_id", None):
        queryset = queryset.filter(company=user.primary_company)

    return queryset
'''

new_scope = '''def scoped_payment_request_queryset(user):
    queryset = PaymentRequest.objects.select_related("company", "beneficiary", "requested_by")

    if user.is_superuser:
        return queryset

    if getattr(user, "primary_company_id", None):
        return queryset.filter(company_id=user.primary_company_id)

    return queryset.none()
'''

if old_scope in views:
    views = views.replace(old_scope, new_scope)

dashboard_class = '''
class PaymentRequestDashboardView(LoginRequiredMixin, TemplateView):
    template_name = "payment_requests/paymentrequest_dashboard.html"

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        user = self.request.user
        payment_requests = scoped_payment_request_queryset(user)

        status_totals = dict(
            payment_requests.values_list("status").annotate(total=Count("id"))
        )
        status_cards = [
            {
                "code": status_code,
                "label": status_label,
                "total": status_totals.get(status_code, 0),
            }
            for status_code, status_label in PaymentRequestStatus.choices
        ]

        pending_steps = PaymentApprovalStep.objects.select_related(
            "payment_request",
            "payment_request__company",
            "payment_request__beneficiary",
        ).filter(
            status=ApprovalStepStatus.PENDING,
            required_role=user.role,
            payment_request__in=payment_requests,
        ).order_by("sequence", "-payment_request__created_at")[:10]

        context["total_requests"] = payment_requests.count()
        context["status_cards"] = status_cards
        context["latest_requests"] = payment_requests.order_by("-created_at")[:10]
        context["pending_approval_steps"] = pending_steps
        return context

'''

if "class PaymentRequestDashboardView" not in views:
    marker = "class PaymentRequestCreateView"
    if marker not in views:
        raise SystemExit("ERROR: no se encontró PaymentRequestCreateView en views.py")
    views = views.replace(marker, dashboard_class + "\n" + marker)

views_path.write_text(views)

urls = urls_path.read_text()

if "PaymentRequestDashboardView" not in urls:
    urls = urls.replace(
        "PaymentRequestCreateView,\n",
        "PaymentRequestCreateView,\n    PaymentRequestDashboardView,\n",
    )

dashboard_route = '    path("dashboard/", PaymentRequestDashboardView.as_view(), name="dashboard"),\n'
if dashboard_route not in urls:
    target = '    path("new/", PaymentRequestCreateView.as_view(), name="create"),\n'
    if target not in urls:
        raise SystemExit('ERROR: no se encontró ruta "new/" en payment_requests/urls.py')
    urls = urls.replace(target, target + dashboard_route)

urls_path.write_text(urls)

template_dir.mkdir(parents=True, exist_ok=True)

extends_line = '{% extends "base.html" %}'
if list_template_path.exists():
    for line in list_template_path.read_text().splitlines():
        if line.strip().startswith("{% extends "):
            extends_line = line.strip()
            break

dashboard_template = f'''{extends_line}

{{% block content %}}
<h1>Dashboard operativo de solicitudes</h1>

<section>
  <h2>Resumen ejecutivo</h2>
  <p><strong>Total de solicitudes:</strong> {{{{ total_requests }}}}</p>

  <div>
    {{% for card in status_cards %}}
      <article>
        <h3>{{{{ card.label }}}}</h3>
        <p>{{{{ card.total }}}}</p>
      </article>
    {{% endfor %}}
  </div>
</section>

<section>
  <h2>Pendientes de aprobación para mi rol</h2>

  {{% if pending_approval_steps %}}
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
        {{% for step in pending_approval_steps %}}
          <tr>
            <td>#{{{{ step.payment_request.id }}}}</td>
            <td>{{{{ step.payment_request.company }}}}</td>
            <td>{{{{ step.payment_request.beneficiary }}}}</td>
            <td>{{{{ step.payment_request.amount }}}} {{{{ step.payment_request.currency }}}}</td>
            <td>{{{{ step.sequence }}}}</td>
            <td>
              <a href="{{% url 'payment_requests:detail' step.payment_request.pk %}}">
                Ver solicitud
              </a>
            </td>
          </tr>
        {{% endfor %}}
      </tbody>
    </table>
  {{% else %}}
    <p>No hay aprobaciones pendientes para tu rol.</p>
  {{% endif %}}
</section>

<section>
  <h2>Últimas solicitudes</h2>

  {{% if latest_requests %}}
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
        {{% for payment_request in latest_requests %}}
          <tr>
            <td>
              <a href="{{% url 'payment_requests:detail' payment_request.pk %}}">
                #{{{{ payment_request.id }}}}
              </a>
            </td>
            <td>{{{{ payment_request.company }}}}</td>
            <td>{{{{ payment_request.beneficiary }}}}</td>
            <td>{{{{ payment_request.concept }}}}</td>
            <td>{{{{ payment_request.amount }}}} {{{{ payment_request.currency }}}}</td>
            <td>{{{{ payment_request.get_status_display }}}}</td>
            <td>{{{{ payment_request.created_at }}}}</td>
          </tr>
        {{% endfor %}}
      </tbody>
    </table>
  {{% else %}}
    <p>No hay solicitudes registradas.</p>
  {{% endif %}}
</section>

<p>
  <a href="{{% url 'payment_requests:list' %}}">Volver a solicitudes</a>
</p>
{{% endblock %}}
'''
dashboard_template_path.write_text(dashboard_template)

if list_template_path.exists():
    list_template = list_template_path.read_text()
    if "payment_requests:dashboard" not in list_template:
        dashboard_link = "<p><a href=\"{% url 'payment_requests:dashboard' %}\">Dashboard operativo</a></p>\n" 
        if "{% block content %}" in list_template:
            list_template = list_template.replace(
                "{% block content %}",
                "{% block content %}\n" + dashboard_link,
                1,
            )
        else:
            list_template = dashboard_link + list_template
        list_template_path.write_text(list_template)

tests_code = '''from datetime import date
from decimal import Decimal

from django.apps import apps
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from apps.accounts.models import UserRole
from apps.payment_approvals.models import ApprovalStepStatus, PaymentApprovalStep
from apps.payment_requests.models import PaymentRequest, PaymentRequestStatus


_COUNTER = 0


def next_value(prefix):
    global _COUNTER
    _COUNTER += 1
    return f"{prefix}-{_COUNTER}"


def build_required_data(model, **overrides):
    data = dict(overrides)

    for field in model._meta.concrete_fields:
        if field.name in data:
            continue
        if field.primary_key or field.auto_created:
            continue
        if getattr(field, "auto_now", False) or getattr(field, "auto_now_add", False):
            continue
        if field.has_default() or field.null or field.blank:
            continue

        internal_type = field.get_internal_type()

        if internal_type in {"CharField", "TextField", "SlugField"}:
            max_length = getattr(field, "max_length", None)
            value = next_value(field.name)
            data[field.name] = value[:max_length] if max_length else value
        elif internal_type == "EmailField":
            data[field.name] = f"{next_value('user')}@example.com"
        elif internal_type == "DecimalField":
            data[field.name] = Decimal("100.00")
        elif internal_type in {"IntegerField", "PositiveIntegerField", "PositiveSmallIntegerField"}:
            data[field.name] = 1
        elif internal_type == "BooleanField":
            data[field.name] = False
        elif internal_type == "DateField":
            data[field.name] = date.today()
        elif internal_type == "DateTimeField":
            data[field.name] = timezone.now()

    return data


def create_model(model_label, **overrides):
    app_label, model_name = model_label.split(".")
    model = apps.get_model(app_label, model_name)
    return model.objects.create(**build_required_data(model, **overrides))


class PaymentRequestDashboardViewTests(TestCase):
    def setUp(self):
        self.company = create_model("organization.Company")
        self.other_company = create_model("organization.Company")
        self.beneficiary = create_model("beneficiaries.Beneficiary", company=self.company)
        self.other_beneficiary = create_model(
            "beneficiaries.Beneficiary",
            company=self.other_company,
        )
        self.user = self.create_user(
            "finanzas@example.com",
            self.company,
            UserRole.FINANZAS,
        )
        self.other_user = self.create_user(
            "otra@example.com",
            self.other_company,
            UserRole.FINANZAS,
        )
        self.url = reverse("payment_requests:dashboard")

    def create_user(self, email, company, role):
        user_model = get_user_model()
        try:
            return user_model.objects.create_user(
                email=email,
                password="test-pass-123",
                primary_company=company,
                role=role,
            )
        except TypeError:
            user = user_model(
                email=email,
                primary_company=company,
                role=role,
            )
            user.set_password("test-pass-123")
            user.save()
            return user

    def create_payment_request(self, company, beneficiary, user, status, concept):
        return PaymentRequest.objects.create(
            company=company,
            beneficiary=beneficiary,
            requested_by=user,
            amount=Decimal("150.00"),
            currency="VES",
            concept=concept,
            status=status,
        )

    def test_dashboard_requires_login(self):
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 302)

    def test_authenticated_user_can_access_dashboard(self):
        self.client.force_login(self.user)
        self.create_payment_request(
            self.company,
            self.beneficiary,
            self.user,
            PaymentRequestStatus.DRAFT,
            "Solicitud visible",
        )

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(
            response,
            "payment_requests/paymentrequest_dashboard.html",
        )

    def test_dashboard_counts_only_user_company_requests(self):
        self.client.force_login(self.user)
        self.create_payment_request(
            self.company,
            self.beneficiary,
            self.user,
            PaymentRequestStatus.DRAFT,
            "Borrador empresa propia",
        )
        self.create_payment_request(
            self.company,
            self.beneficiary,
            self.user,
            PaymentRequestStatus.APPROVED,
            "Aprobada empresa propia",
        )
        self.create_payment_request(
            self.other_company,
            self.other_beneficiary,
            self.other_user,
            PaymentRequestStatus.REJECTED,
            "Solicitud otra empresa",
        )

        response = self.client.get(self.url)

        self.assertEqual(response.context["total_requests"], 2)
        status_totals = {
            card["code"]: card["total"]
            for card in response.context["status_cards"]
        }
        self.assertEqual(status_totals[PaymentRequestStatus.DRAFT], 1)
        self.assertEqual(status_totals[PaymentRequestStatus.APPROVED], 1)
        self.assertEqual(status_totals[PaymentRequestStatus.REJECTED], 0)

    def test_dashboard_shows_latest_requests_scoped_to_user_company(self):
        self.client.force_login(self.user)
        self.create_payment_request(
            self.company,
            self.beneficiary,
            self.user,
            PaymentRequestStatus.DRAFT,
            "Visible en dashboard",
        )
        self.create_payment_request(
            self.other_company,
            self.other_beneficiary,
            self.other_user,
            PaymentRequestStatus.DRAFT,
            "No visible en dashboard",
        )

        response = self.client.get(self.url)

        self.assertContains(response, "Visible en dashboard")
        self.assertNotContains(response, "No visible en dashboard")

    def test_dashboard_shows_pending_approval_steps_for_user_role(self):
        self.client.force_login(self.user)
        payment_request = self.create_payment_request(
            self.company,
            self.beneficiary,
            self.user,
            PaymentRequestStatus.FINANCE_REVIEW,
            "Pendiente finanzas",
        )
        expected_step = PaymentApprovalStep.objects.create(
            payment_request=payment_request,
            sequence=1,
            required_role=UserRole.FINANZAS,
            status=ApprovalStepStatus.PENDING,
        )

        other_request = self.create_payment_request(
            self.other_company,
            self.other_beneficiary,
            self.other_user,
            PaymentRequestStatus.FINANCE_REVIEW,
            "Pendiente otra empresa",
        )
        PaymentApprovalStep.objects.create(
            payment_request=other_request,
            sequence=1,
            required_role=UserRole.FINANZAS,
            status=ApprovalStepStatus.PENDING,
        )

        response = self.client.get(self.url)

        pending_steps = list(response.context["pending_approval_steps"])
        self.assertEqual(pending_steps, [expected_step])
        self.assertContains(response, "Pendiente finanzas")
        self.assertNotContains(response, "Pendiente otra empresa")
'''

tests_path.write_text(tests_code)

print("OK: F1-P17 dashboard aplicado correctamente.")
PY

echo "== Validación sintáctica Python de archivos tocados =="
python3 -m py_compile \
  backend/apps/payment_requests/views.py \
  backend/apps/payment_requests/urls.py \
  backend/apps/payment_requests/tests/test_dashboard.py

echo "== Archivos modificados/creados =="
git status --short

cat <<'NEXT'

Siguiente paso obligatorio:

nordvpn disconnect
sleep 3

git status
git log --oneline --max-count=5

docker compose exec backend ruff check .
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests apps.payment_documents apps.payment_approvals

nordvpn connect United_States
nordvpn status

NEXT
