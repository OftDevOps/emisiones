#!/usr/bin/env bash
set -euo pipefail

EXPECTED_BRANCH="feature/accounts-payable-workbench"

echo "== F1-P20: Cuentas por Pagar - pagos aprobados pendientes por ejecutar =="

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "ERROR: este directorio no parece ser un repositorio Git."
  exit 1
fi

cd "$(git rev-parse --show-toplevel)"

if [ "$(git branch --show-current)" != "$EXPECTED_BRANCH" ]; then
  echo "ERROR: rama incorrecta."
  echo "Actual:   $(git branch --show-current)"
  echo "Esperada: $EXPECTED_BRANCH"
  echo
  echo "Crea la rama con:"
  echo "  git switch develop"
  echo "  git pull origin develop"
  echo "  git switch -c $EXPECTED_BRANCH"
  exit 1
fi

if [ ! -f backend/apps/payment_requests/views.py ] || [ ! -f backend/apps/payment_requests/urls.py ]; then
  echo "ERROR: no se encontraron archivos base de payment_requests."
  exit 1
fi

echo "== Git status antes de aplicar cambios =="
git status --short

python3 - <<'PY'
from pathlib import Path

views_path = Path("backend/apps/payment_requests/views.py")
urls_path = Path("backend/apps/payment_requests/urls.py")
template_path = Path("backend/templates/payment_requests/accounts_payable_pending.html")
tests_path = Path("backend/apps/payment_requests/tests/test_accounts_payable_workbench.py")

views = views_path.read_text()

if "PermissionDenied" not in views:
    views = views.replace(
        "from django.core.exceptions import ValidationError",
        "from django.core.exceptions import PermissionDenied, ValidationError",
    )

if "from apps.accounts.models import UserRole" not in views:
    lines = views.splitlines()
    idx = 0
    for i, line in enumerate(lines):
        if line.startswith("from django.") or line.startswith("from apps."):
            idx = i + 1
    lines.insert(idx, "from apps.accounts.models import UserRole")
    views = "\n".join(lines) + "\n"

if "ListView" not in views:
    if "from django.views.generic import " in views:
        line = next(x for x in views.splitlines() if x.startswith("from django.views.generic import "))
        imports = [x.strip() for x in line.replace("from django.views.generic import ", "").split(",")]
        imports.append("ListView")
        views = views.replace(line, "from django.views.generic import " + ", ".join(sorted(set(imports))), 1)
    else:
        views = "from django.views.generic import ListView\n" + views

view_code = '''
class AccountsPayablePendingView(LoginRequiredMixin, ListView):
    model = PaymentRequest
    template_name = "payment_requests/accounts_payable_pending.html"
    context_object_name = "payment_requests"
    paginate_by = 25

    def dispatch(self, request, *args, **kwargs):
        user = request.user
        if not user.is_superuser and user.role != UserRole.CUENTAS_POR_PAGAR:
            raise PermissionDenied("Su rol no permite acceder a Cuentas por Pagar.")
        return super().dispatch(request, *args, **kwargs)

    def get_queryset(self):
        return scoped_payment_request_queryset(self.request.user).filter(
            status=PaymentRequestStatus.APPROVED,
        ).order_by("due_date", "-updated_at", "-created_at")

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context["pending_payment_count"] = self.object_list.count()
        return context

'''

if "class AccountsPayablePendingView" not in views:
    marker = "class PaymentRequestDashboardView"
    if marker not in views:
        marker = "class PaymentRequestListView"
    if marker not in views:
        raise SystemExit("ERROR: no se encontró PaymentRequestDashboardView ni PaymentRequestListView.")
    views = views.replace(marker, view_code + "\n" + marker, 1)

views_path.write_text(views)

urls = urls_path.read_text()

if "AccountsPayablePendingView" not in urls:
    urls = urls.replace(
        "PaymentRequestDashboardView,\n",
        "PaymentRequestDashboardView,\n    AccountsPayablePendingView,\n",
        1,
    )

route = '    path("accounts-payable/", AccountsPayablePendingView.as_view(), name="accounts_payable"),\n'
if route not in urls:
    detail = '    path("<int:pk>/", PaymentRequestDetailView.as_view(), name="detail"),\n'
    if detail in urls:
        urls = urls.replace(detail, route + detail, 1)
    else:
        urls = urls.replace("urlpatterns = [\n", "urlpatterns = [\n" + route, 1)

urls_path.write_text(urls)

template_path.parent.mkdir(parents=True, exist_ok=True)

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
        break

template = f'''{extends_line}

{{% block content %}}
<h1>Cuentas por Pagar</h1>
<h2>Pagos aprobados pendientes por ejecutar</h2>

<p><strong>Total pendiente:</strong> {{{{ pending_payment_count }}}}</p>

{{% if payment_requests %}}
<table>
  <thead>
    <tr>
      <th>Solicitud</th>
      <th>Empresa</th>
      <th>Beneficiario</th>
      <th>Solicitante</th>
      <th>Concepto</th>
      <th>Monto</th>
      <th>Fecha requerida</th>
      <th>Estado</th>
      <th>Acción</th>
    </tr>
  </thead>
  <tbody>
    {{% for payment_request in payment_requests %}}
    <tr>
      <td>#{{{{ payment_request.id }}}}</td>
      <td>{{{{ payment_request.company }}}}</td>
      <td>{{{{ payment_request.beneficiary }}}}</td>
      <td>{{{{ payment_request.requested_by }}}}</td>
      <td>{{{{ payment_request.concept }}}}</td>
      <td>{{{{ payment_request.amount }}}} {{{{ payment_request.currency }}}}</td>
      <td>{{{{ payment_request.due_date|default:"Sin fecha" }}}}</td>
      <td>{{{{ payment_request.get_status_display }}}}</td>
      <td><a href="{{% url 'payment_requests:detail' payment_request.pk %}}">Ver solicitud</a></td>
    </tr>
    {{% endfor %}}
  </tbody>
</table>
{{% else %}}
<p>No hay pagos aprobados pendientes por ejecutar.</p>
{{% endif %}}

<p><a href="{{% url 'payment_requests:dashboard' %}}">Volver al dashboard</a></p>
{{% endblock %}}
'''
template_path.write_text(template)

tests_path.write_text('''from datetime import date
from decimal import Decimal

from django.apps import apps
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import UserRole
from apps.payment_requests.models import PaymentRequest, PaymentRequestStatus


_counter = 0


def unique(prefix):
    global _counter
    _counter += 1
    return f"{prefix}-{_counter}"


def required_data(model, **overrides):
    data = dict(overrides)
    for field in model._meta.concrete_fields:
        if field.name in data or field.primary_key or field.auto_created:
            continue
        if getattr(field, "auto_now", False) or getattr(field, "auto_now_add", False):
            continue
        if field.has_default() or field.null or field.blank:
            continue
        kind = field.get_internal_type()
        if kind in {"CharField", "TextField", "SlugField"}:
            value = unique(field.name)
            data[field.name] = value[: field.max_length] if getattr(field, "max_length", None) else value
        elif kind == "EmailField":
            data[field.name] = f"{unique('user')}@example.com"
        elif kind == "DecimalField":
            data[field.name] = Decimal("100.00")
        elif kind in {"IntegerField", "PositiveIntegerField", "PositiveSmallIntegerField"}:
            data[field.name] = 1
        elif kind == "BooleanField":
            data[field.name] = False
        elif kind == "DateField":
            data[field.name] = date.today()
    return data


def create_model(label, **overrides):
    app_label, model_name = label.split(".")
    model = apps.get_model(app_label, model_name)
    return model.objects.create(**required_data(model, **overrides))


class AccountsPayablePendingViewTests(TestCase):
    def setUp(self):
        self.company = create_model("organization.Company")
        self.other_company = create_model("organization.Company")
        self.beneficiary = create_model("beneficiaries.Beneficiary", company=self.company)
        self.other_beneficiary = create_model("beneficiaries.Beneficiary", company=self.other_company)
        self.cxp_user = self.create_user("cxp@example.com", self.company, UserRole.CUENTAS_POR_PAGAR)
        self.finance_user = self.create_user("finanzas@example.com", self.company, UserRole.FINANZAS)
        self.other_cxp_user = self.create_user("otra-cxp@example.com", self.other_company, UserRole.CUENTAS_POR_PAGAR)
        self.url = reverse("payment_requests:accounts_payable")

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
            user = user_model(email=email, primary_company=company, role=role)
            user.set_password("test-pass-123")
            user.save()
            return user

    def create_request(self, company, beneficiary, user, status, concept):
        return PaymentRequest.objects.create(
            company=company,
            beneficiary=beneficiary,
            requested_by=user,
            amount=Decimal("150.00"),
            currency="VES",
            concept=concept,
            due_date=date.today(),
            status=status,
        )

    def test_requires_login(self):
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 302)

    def test_accounts_payable_user_can_access(self):
        self.client.force_login(self.cxp_user)
        payment_request = self.create_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            PaymentRequestStatus.APPROVED,
            "Pago aprobado visible",
        )

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(list(response.context["payment_requests"]), [payment_request])
        self.assertContains(response, "Pago aprobado visible")

    def test_non_accounts_payable_user_gets_403(self):
        self.client.force_login(self.finance_user)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 403)

    def test_only_lists_approved_requests(self):
        self.client.force_login(self.cxp_user)
        approved_request = self.create_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            PaymentRequestStatus.APPROVED,
            "Pago aprobado",
        )
        self.create_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            PaymentRequestStatus.FINANCE_REVIEW,
            "Pago no aprobado",
        )

        response = self.client.get(self.url)

        self.assertEqual(list(response.context["payment_requests"]), [approved_request])
        self.assertContains(response, "Pago aprobado")
        self.assertNotContains(response, "Pago no aprobado")

    def test_scopes_by_company(self):
        self.client.force_login(self.cxp_user)
        own_request = self.create_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            PaymentRequestStatus.APPROVED,
            "Pago empresa propia",
        )
        self.create_request(
            self.other_company,
            self.other_beneficiary,
            self.other_cxp_user,
            PaymentRequestStatus.APPROVED,
            "Pago otra empresa",
        )

        response = self.client.get(self.url)

        self.assertEqual(list(response.context["payment_requests"]), [own_request])
        self.assertContains(response, "Pago empresa propia")
        self.assertNotContains(response, "Pago otra empresa")
''')

print("OK: F1-P20 bandeja de Cuentas por Pagar aplicada correctamente.")
PY

echo "== Validación sintáctica Python de archivos tocados =="
python3 -m py_compile \
  backend/apps/payment_requests/views.py \
  backend/apps/payment_requests/urls.py \
  backend/apps/payment_requests/tests/test_accounts_payable_workbench.py

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

git add backend/apps/payment_requests/views.py \
  backend/apps/payment_requests/urls.py \
  backend/templates/payment_requests/accounts_payable_pending.html \
  backend/apps/payment_requests/tests/test_accounts_payable_workbench.py \
  scripts/46_f1_p20_accounts_payable_workbench.sh

git commit -m "feat: add accounts payable workbench"
git push -u origin feature/accounts-payable-workbench

NEXT
