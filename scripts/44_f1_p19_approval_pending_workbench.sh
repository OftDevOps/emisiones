#!/usr/bin/env bash
set -euo pipefail

# F1-P19 - Bandeja de trabajo: pendientes por aprobar
# Proyecto: OftDevOps/emisiones
#
# Ruta del proyecto:
#   /home/dchirinos/oftalmiIA/emisiones/emisiones
#
# Ruta destino del playbook:
#   /home/dchirinos/oftalmiIA/emisiones/emisiones/scripts/44_f1_p19_approval_pending_workbench.sh
#
# Uso:
#   cd /home/dchirinos/oftalmiIA/emisiones/emisiones
#   chmod +x scripts/44_f1_p19_approval_pending_workbench.sh
#   ./scripts/44_f1_p19_approval_pending_workbench.sh
#
# Alcance:
# - Crea bandeja de pendientes por aprobar.
# - Agrega ruta /payment-approvals/pending/.
# - Agrega template.
# - Agrega tests.
# - No crea modelos.
# - No crea migraciones.
# - No hace commit.
# - No hace push.

EXPECTED_BRANCH="feature/approval-pending-workbench"

echo "== F1-P19: Bandeja de trabajo - pendientes por aprobar =="

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "ERROR: este directorio no parece ser un repositorio Git."
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if [ ! -d "backend/apps/payment_approvals" ]; then
  echo "ERROR: no se encontró backend/apps/payment_approvals."
  exit 1
fi

if [ ! -d "backend/apps/payment_requests" ]; then
  echo "ERROR: no se encontró backend/apps/payment_requests."
  exit 1
fi

CURRENT_BRANCH="$(git branch --show-current)"
if [ "$CURRENT_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ERROR: rama incorrecta."
  echo "Actual:   $CURRENT_BRANCH"
  echo "Esperada: $EXPECTED_BRANCH"
  echo
  echo "Crea la rama con:"
  echo "  git switch develop"
  echo "  git pull origin develop"
  echo "  git switch -c $EXPECTED_BRANCH"
  exit 1
fi

echo "== Git status antes de aplicar cambios =="
git status --short

python3 - <<'PY'
from pathlib import Path

views_path = Path("backend/apps/payment_approvals/views.py")
urls_path = Path("backend/apps/payment_approvals/urls.py")
template_dir = Path("backend/templates/payment_approvals")
template_path = template_dir / "pending_approval_steps.html"
tests_path = Path("backend/apps/payment_approvals/tests/test_pending_workbench.py")

for required_file in [views_path, urls_path]:
    if not required_file.exists():
        raise SystemExit(f"ERROR: archivo requerido no existe: {required_file}")

views = views_path.read_text()

if "LoginRequiredMixin" not in views:
    if "from django.contrib.auth.mixins import" in views:
        views = views.replace(
            "from django.contrib.auth.mixins import ",
            "from django.contrib.auth.mixins import LoginRequiredMixin, ",
            1,
        )
    else:
        views = "from django.contrib.auth.mixins import LoginRequiredMixin\n" + views

if "ListView" not in views:
    if "from django.views.generic import " in views:
        line = next(
            item for item in views.splitlines()
            if item.startswith("from django.views.generic import ")
        )
        imports = [part.strip() for part in line.replace("from django.views.generic import ", "").split(",")]
        if "ListView" not in imports:
            imports.append("ListView")
        new_line = "from django.views.generic import " + ", ".join(sorted(imports))
        views = views.replace(line, new_line, 1)
    elif "from django.views import View" in views:
        views = views.replace("from django.views import View", "from django.views.generic import ListView, View")
    else:
        views = "from django.views.generic import ListView\n" + views

if "ApprovalStepStatus" not in views or "PaymentApprovalStep" not in views:
    if "from apps.payment_approvals.models import (" in views:
        if "ApprovalStepStatus" not in views:
            views = views.replace(
                "from apps.payment_approvals.models import (\n",
                "from apps.payment_approvals.models import (\n    ApprovalStepStatus,\n",
                1,
            )
        if "PaymentApprovalStep" not in views:
            views = views.replace(
                "from apps.payment_approvals.models import (\n",
                "from apps.payment_approvals.models import (\n    PaymentApprovalStep,\n",
                1,
            )
    elif "from apps.payment_approvals.models import PaymentApprovalStep" in views:
        views = views.replace(
            "from apps.payment_approvals.models import PaymentApprovalStep",
            "from apps.payment_approvals.models import ApprovalStepStatus, PaymentApprovalStep",
            1,
        )
    elif "from apps.payment_approvals.models import ApprovalStepStatus" in views:
        views = views.replace(
            "from apps.payment_approvals.models import ApprovalStepStatus",
            "from apps.payment_approvals.models import ApprovalStepStatus, PaymentApprovalStep",
            1,
        )
    else:
        insert_after = None
        for candidate in [
            "from django.views.generic import",
            "from django.views import",
            "from django.shortcuts import",
        ]:
            if candidate in views:
                insert_after = candidate
                break
        if insert_after:
            lines = views.splitlines()
            for index, line in enumerate(lines):
                if line.startswith(insert_after):
                    lines.insert(index + 1, "from apps.payment_approvals.models import ApprovalStepStatus, PaymentApprovalStep")
                    views = "\n".join(lines) + "\n"
                    break
        else:
            views = "from apps.payment_approvals.models import ApprovalStepStatus, PaymentApprovalStep\n" + views

pending_view = '''
class PendingApprovalStepsView(LoginRequiredMixin, ListView):
    model = PaymentApprovalStep
    template_name = "payment_approvals/pending_approval_steps.html"
    context_object_name = "pending_steps"
    paginate_by = 25

    def get_queryset(self):
        user = self.request.user
        queryset = PaymentApprovalStep.objects.select_related(
            "payment_request",
            "payment_request__company",
            "payment_request__beneficiary",
            "payment_request__requested_by",
        ).filter(status=ApprovalStepStatus.PENDING)

        if user.is_superuser:
            return queryset.order_by("sequence", "-payment_request__created_at")

        if not getattr(user, "primary_company_id", None):
            return queryset.none()

        return queryset.filter(
            required_role=user.role,
            payment_request__company_id=user.primary_company_id,
        ).order_by("sequence", "-payment_request__created_at")

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context["pending_count"] = self.object_list.count()
        return context

'''

if "class PendingApprovalStepsView" not in views:
    marker = "class ApprovalStepActionView"
    if marker not in views:
        raise SystemExit("ERROR: no se encontró ApprovalStepActionView en payment_approvals/views.py")
    views = views.replace(marker, pending_view + "\n" + marker)

views_path.write_text(views)

urls = urls_path.read_text()

if "PendingApprovalStepsView" not in urls:
    if "from .views import" in urls:
        if "ApprovalStepActionView" in urls:
            urls = urls.replace(
                "ApprovalStepActionView",
                "ApprovalStepActionView, PendingApprovalStepsView",
                1,
            )
        else:
            urls = urls.replace(
                "from .views import ",
                "from .views import PendingApprovalStepsView, ",
                1,
            )
    else:
        urls = "from .views import PendingApprovalStepsView\n" + urls

pending_route = '    path("pending/", PendingApprovalStepsView.as_view(), name="pending"),\n'
if pending_route not in urls:
    if "urlpatterns = [" not in urls:
        raise SystemExit("ERROR: no se encontró urlpatterns en payment_approvals/urls.py")
    urls = urls.replace("urlpatterns = [\n", "urlpatterns = [\n" + pending_route, 1)

urls_path.write_text(urls)

template_dir.mkdir(parents=True, exist_ok=True)

extends_line = '{% extends "base.html" %}'
for candidate in [
    Path("backend/templates/payment_requests/paymentrequest_dashboard.html"),
    Path("backend/templates/payment_requests/paymentrequest_list.html"),
]:
    if candidate.exists():
        for line in candidate.read_text().splitlines():
            if line.strip().startswith("{% extends "):
                extends_line = line.strip()
                break
        if extends_line != '{% extends "base.html" %}':
            break

template_path.write_text(f'''{extends_line}

{{% block content %}}
<h1>Pendientes por aprobar</h1>

<p>
  <strong>Total pendiente:</strong> {{{{ pending_count }}}}
</p>

{{% if pending_steps %}}
  <table>
    <thead>
      <tr>
        <th>Solicitud</th>
        <th>Empresa</th>
        <th>Beneficiario</th>
        <th>Solicitante</th>
        <th>Monto</th>
        <th>Estado solicitud</th>
        <th>Paso</th>
        <th>Rol requerido</th>
        <th>Creada</th>
        <th>Acción</th>
      </tr>
    </thead>
    <tbody>
      {{% for step in pending_steps %}}
        <tr>
          <td>#{{{{ step.payment_request.id }}}}</td>
          <td>{{{{ step.payment_request.company }}}}</td>
          <td>{{{{ step.payment_request.beneficiary }}}}</td>
          <td>{{{{ step.payment_request.requested_by }}}}</td>
          <td>{{{{ step.payment_request.amount }}}} {{{{ step.payment_request.currency }}}}</td>
          <td>{{{{ step.payment_request.get_status_display }}}}</td>
          <td>{{{{ step.sequence }}}}</td>
          <td>{{{{ step.get_required_role_display }}}}</td>
          <td>{{{{ step.payment_request.created_at }}}}</td>
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
  <p>No tienes solicitudes pendientes por aprobar.</p>
{{% endif %}}

<p>
  <a href="{{% url 'payment_requests:dashboard' %}}">Volver al dashboard</a>
</p>
{{% endblock %}}
''')

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


class PendingApprovalStepsViewTests(TestCase):
    def setUp(self):
        self.company = create_model("organization.Company")
        self.other_company = create_model("organization.Company")
        self.beneficiary = create_model("beneficiaries.Beneficiary", company=self.company)
        self.other_beneficiary = create_model(
            "beneficiaries.Beneficiary",
            company=self.other_company,
        )
        self.finance_user = self.create_user(
            "finanzas@example.com",
            self.company,
            UserRole.FINANZAS,
        )
        self.management_user = self.create_user(
            "gerencia@example.com",
            self.company,
            UserRole.GERENCIA_GENERAL,
        )
        self.other_company_user = self.create_user(
            "otra-finanzas@example.com",
            self.other_company,
            UserRole.FINANZAS,
        )
        self.url = reverse("payment_approvals:pending")

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

    def create_payment_request(self, company, beneficiary, user, concept):
        return PaymentRequest.objects.create(
            company=company,
            beneficiary=beneficiary,
            requested_by=user,
            amount=Decimal("150.00"),
            currency="VES",
            concept=concept,
            status=PaymentRequestStatus.FINANCE_REVIEW,
        )

    def create_step(self, payment_request, role, status=ApprovalStepStatus.PENDING):
        return PaymentApprovalStep.objects.create(
            payment_request=payment_request,
            sequence=1,
            required_role=role,
            status=status,
        )

    def test_pending_workbench_requires_login(self):
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 302)

    def test_pending_workbench_lists_pending_steps_for_user_role_and_company(self):
        self.client.force_login(self.finance_user)
        payment_request = self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            "Pendiente visible finanzas",
        )
        expected_step = self.create_step(payment_request, UserRole.FINANZAS)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, "payment_approvals/pending_approval_steps.html")
        self.assertEqual(list(response.context["pending_steps"]), [expected_step])
        self.assertContains(response, "Pendiente visible finanzas")

    def test_pending_workbench_excludes_other_company_steps(self):
        self.client.force_login(self.finance_user)
        visible_request = self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            "Pendiente empresa propia",
        )
        expected_step = self.create_step(visible_request, UserRole.FINANZAS)

        other_request = self.create_payment_request(
            self.other_company,
            self.other_beneficiary,
            self.other_company_user,
            "Pendiente otra empresa",
        )
        self.create_step(other_request, UserRole.FINANZAS)

        response = self.client.get(self.url)

        self.assertEqual(list(response.context["pending_steps"]), [expected_step])
        self.assertContains(response, "Pendiente empresa propia")
        self.assertNotContains(response, "Pendiente otra empresa")

    def test_pending_workbench_excludes_other_role_steps(self):
        self.client.force_login(self.finance_user)
        visible_request = self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            "Pendiente rol finanzas",
        )
        expected_step = self.create_step(visible_request, UserRole.FINANZAS)

        management_request = self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            "Pendiente gerencia",
        )
        self.create_step(management_request, UserRole.GERENCIA_GENERAL)

        response = self.client.get(self.url)

        self.assertEqual(list(response.context["pending_steps"]), [expected_step])
        self.assertContains(response, "Pendiente rol finanzas")
        self.assertNotContains(response, "Pendiente gerencia")

    def test_pending_workbench_excludes_non_pending_steps(self):
        self.client.force_login(self.finance_user)
        pending_request = self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            "Pendiente real",
        )
        expected_step = self.create_step(pending_request, UserRole.FINANZAS)

        approved_request = self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            "Ya aprobado",
        )
        self.create_step(
            approved_request,
            UserRole.FINANZAS,
            status=ApprovalStepStatus.APPROVED,
        )

        response = self.client.get(self.url)

        self.assertEqual(list(response.context["pending_steps"]), [expected_step])
        self.assertContains(response, "Pendiente real")
        self.assertNotContains(response, "Ya aprobado")

    def test_user_without_company_gets_empty_workbench(self):
        user_model = get_user_model()
        try:
            no_company_user = user_model.objects.create_user(
                email="sin-empresa@example.com",
                password="test-pass-123",
                role=UserRole.FINANZAS,
            )
        except TypeError:
            no_company_user = user_model(
                email="sin-empresa@example.com",
                role=UserRole.FINANZAS,
            )
            no_company_user.set_password("test-pass-123")
            no_company_user.save()

        payment_request = self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            "No visible sin empresa",
        )
        self.create_step(payment_request, UserRole.FINANZAS)

        self.client.force_login(no_company_user)
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(list(response.context["pending_steps"]), [])
        self.assertContains(response, "No tienes solicitudes pendientes por aprobar.")
        self.assertNotContains(response, "No visible sin empresa")
'''

tests_path.write_text(tests_code)

print("OK: F1-P19 bandeja de pendientes aplicada correctamente.")
PY

echo "== Validación sintáctica Python de archivos tocados =="
python3 -m py_compile \
  backend/apps/payment_approvals/views.py \
  backend/apps/payment_approvals/urls.py \
  backend/apps/payment_approvals/tests/test_pending_workbench.py

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

Si todo está correcto:

git add backend/apps/payment_approvals/views.py \
  backend/apps/payment_approvals/urls.py \
  backend/templates/payment_approvals/pending_approval_steps.html \
  backend/apps/payment_approvals/tests/test_pending_workbench.py \
  scripts/44_f1_p19_approval_pending_workbench.sh

git commit -m "feat: add pending approval workbench"
git push -u origin feature/approval-pending-workbench

NEXT
