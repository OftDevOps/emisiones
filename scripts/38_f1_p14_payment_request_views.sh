#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' '== F1-P14: Basic payment request views =='

if [ ! -f "backend/manage.py" ]; then
  printf '%s\n' 'ERROR: run this script from repository root: /home/dchirinos/oftalmiIA/emisiones/emisiones' >&2
  exit 1
fi

mkdir -p backend/apps/payment_requests/tests backend/templates/payment_requests docs/03-desarrollo

touch backend/apps/payment_requests/tests/__init__.py

# Ensure templates dir exists in settings if the project uses backend/templates.
python3 - <<'PY'
from pathlib import Path
p = Path('backend/config/settings/base.py')
s = p.read_text()
# Conservative: do not rewrite settings if already has DIRS configured for templates.
if 'BASE_DIR / "templates"' not in s and "BASE_DIR / 'templates'" not in s:
    old = '"DIRS": [],'
    new = '"DIRS": [BASE_DIR / "templates"],'
    if old in s:
        s = s.replace(old, new)
    else:
        old = "'DIRS': [],"
        new = "'DIRS': [BASE_DIR / 'templates'],"
        if old in s:
            s = s.replace(old, new)
p.write_text(s)
PY

cat > backend/apps/payment_requests/forms.py <<'PY'
from django import forms

from .models import PaymentRequest
from apps.beneficiaries.models import Beneficiary


class PaymentRequestCreateForm(forms.ModelForm):
    class Meta:
        model = PaymentRequest
        fields = [
            "company",
            "beneficiary",
            "amount",
            "currency",
            "concept",
            "description",
            "due_date",
        ]
        widgets = {
            "due_date": forms.DateInput(attrs={"type": "date"}),
            "description": forms.Textarea(attrs={"rows": 4}),
        }

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.user = user

        if user is not None and getattr(user, "primary_company_id", None):
            self.fields["company"].queryset = self.fields["company"].queryset.filter(
                id=user.primary_company_id
            )
            self.fields["company"].initial = user.primary_company
            self.fields["beneficiary"].queryset = Beneficiary.objects.filter(
                company=user.primary_company,
                is_active=True,
            )
        else:
            self.fields["beneficiary"].queryset = Beneficiary.objects.filter(is_active=True)

    def clean(self):
        cleaned_data = super().clean()
        company = cleaned_data.get("company")
        beneficiary = cleaned_data.get("beneficiary")

        if company and beneficiary and beneficiary.company_id != company.id:
            self.add_error(
                "beneficiary",
                "El beneficiario debe pertenecer a la empresa seleccionada.",
            )

        return cleaned_data
PY

cat > backend/apps/payment_requests/views.py <<'PY'
from django.contrib.auth.mixins import LoginRequiredMixin
from django.urls import reverse_lazy
from django.views.generic import CreateView, DetailView, ListView

from .forms import PaymentRequestCreateForm
from .models import PaymentRequest


class PaymentRequestListView(LoginRequiredMixin, ListView):
    model = PaymentRequest
    template_name = "payment_requests/paymentrequest_list.html"
    context_object_name = "payment_requests"
    paginate_by = 20

    def get_queryset(self):
        queryset = (
            PaymentRequest.objects.select_related("company", "beneficiary", "requested_by")
            .order_by("-created_at")
        )
        user = self.request.user

        if not user.is_superuser and getattr(user, "primary_company_id", None):
            queryset = queryset.filter(company=user.primary_company)

        return queryset


class PaymentRequestDetailView(LoginRequiredMixin, DetailView):
    model = PaymentRequest
    template_name = "payment_requests/paymentrequest_detail.html"
    context_object_name = "payment_request"

    def get_queryset(self):
        queryset = PaymentRequest.objects.select_related("company", "beneficiary", "requested_by")
        user = self.request.user

        if not user.is_superuser and getattr(user, "primary_company_id", None):
            queryset = queryset.filter(company=user.primary_company)

        return queryset


class PaymentRequestCreateView(LoginRequiredMixin, CreateView):
    model = PaymentRequest
    form_class = PaymentRequestCreateForm
    template_name = "payment_requests/paymentrequest_form.html"
    success_url = reverse_lazy("payment_requests:list")

    def get_form_kwargs(self):
        kwargs = super().get_form_kwargs()
        kwargs["user"] = self.request.user
        return kwargs

    def form_valid(self, form):
        form.instance.requested_by = self.request.user
        return super().form_valid(form)
PY

cat > backend/apps/payment_requests/urls.py <<'PY'
from django.urls import path

from .views import PaymentRequestCreateView, PaymentRequestDetailView, PaymentRequestListView

app_name = "payment_requests"

urlpatterns = [
    path("", PaymentRequestListView.as_view(), name="list"),
    path("new/", PaymentRequestCreateView.as_view(), name="create"),
    path("<int:pk>/", PaymentRequestDetailView.as_view(), name="detail"),
]
PY

# Include payment request URLs in config/urls.py.
python3 - <<'PY'
from pathlib import Path
p = Path('backend/config/urls.py')
s = p.read_text()
if 'payment-requests/' not in s:
    if 'include' not in s:
        s = s.replace('from django.urls import path', 'from django.urls import include, path')
    s = s.replace(
        'urlpatterns = [',
        'urlpatterns = [\n    path("payment-requests/", include("apps.payment_requests.urls")),',
    )
p.write_text(s)
PY

# Add navigation link to base template if present.
python3 - <<'PY'
from pathlib import Path
p = Path('backend/templates/base.html')
if p.exists():
    s = p.read_text()
    if 'payment_requests:list' not in s:
        marker = '</nav>'
        link = '    <a href="{% url \'payment_requests:list\' %}">Solicitudes de pago</a>\n'
        if marker in s:
            s = s.replace(marker, link + marker)
        elif '</body>' in s:
            s = s.replace('</body>', '<p><a href="{% url \'payment_requests:list\' %}">Solicitudes de pago</a></p>\n</body>')
        p.write_text(s)
PY

cat > backend/templates/payment_requests/paymentrequest_list.html <<'HTML'
{% extends "base.html" %}

{% block title %}Solicitudes de pago{% endblock %}

{% block content %}
<h1>Solicitudes de pago</h1>

<p>
    <a href="{% url 'payment_requests:create' %}">Nueva solicitud</a>
</p>

{% if payment_requests %}
<table>
    <thead>
        <tr>
            <th>ID</th>
            <th>Empresa</th>
            <th>Beneficiario</th>
            <th>Monto</th>
            <th>Moneda</th>
            <th>Estado</th>
            <th>Creada</th>
            <th></th>
        </tr>
    </thead>
    <tbody>
        {% for request in payment_requests %}
        <tr>
            <td>{{ request.id }}</td>
            <td>{{ request.company }}</td>
            <td>{{ request.beneficiary }}</td>
            <td>{{ request.amount }}</td>
            <td>{{ request.currency }}</td>
            <td>{{ request.get_status_display }}</td>
            <td>{{ request.created_at|date:"Y-m-d H:i" }}</td>
            <td><a href="{% url 'payment_requests:detail' request.pk %}">Ver</a></td>
        </tr>
        {% endfor %}
    </tbody>
</table>
{% else %}
<p>No hay solicitudes de pago registradas.</p>
{% endif %}
{% endblock %}
HTML

cat > backend/templates/payment_requests/paymentrequest_detail.html <<'HTML'
{% extends "base.html" %}

{% block title %}Solicitud de pago #{{ payment_request.id }}{% endblock %}

{% block content %}
<h1>Solicitud de pago #{{ payment_request.id }}</h1>

<dl>
    <dt>Empresa</dt>
    <dd>{{ payment_request.company }}</dd>

    <dt>Beneficiario</dt>
    <dd>{{ payment_request.beneficiary }}</dd>

    <dt>Solicitante</dt>
    <dd>{{ payment_request.requested_by }}</dd>

    <dt>Monto</dt>
    <dd>{{ payment_request.amount }} {{ payment_request.currency }}</dd>

    <dt>Concepto</dt>
    <dd>{{ payment_request.concept }}</dd>

    <dt>Descripción</dt>
    <dd>{{ payment_request.description|default:"-" }}</dd>

    <dt>Fecha de vencimiento</dt>
    <dd>{{ payment_request.due_date|default:"-" }}</dd>

    <dt>Estado</dt>
    <dd>{{ payment_request.get_status_display }}</dd>
</dl>

<p>
    <a href="{% url 'payment_requests:list' %}">Volver al listado</a>
</p>
{% endblock %}
HTML

cat > backend/templates/payment_requests/paymentrequest_form.html <<'HTML'
{% extends "base.html" %}

{% block title %}Nueva solicitud de pago{% endblock %}

{% block content %}
<h1>Nueva solicitud de pago</h1>

<form method="post">
    {% csrf_token %}
    {{ form.non_field_errors }}

    <p>
        {{ form.company.label_tag }}<br>
        {{ form.company }}
        {{ form.company.errors }}
    </p>

    <p>
        {{ form.beneficiary.label_tag }}<br>
        {{ form.beneficiary }}
        {{ form.beneficiary.errors }}
    </p>

    <p>
        {{ form.amount.label_tag }}<br>
        {{ form.amount }}
        {{ form.amount.errors }}
    </p>

    <p>
        {{ form.currency.label_tag }}<br>
        {{ form.currency }}
        {{ form.currency.errors }}
    </p>

    <p>
        {{ form.concept.label_tag }}<br>
        {{ form.concept }}
        {{ form.concept.errors }}
    </p>

    <p>
        {{ form.description.label_tag }}<br>
        {{ form.description }}
        {{ form.description.errors }}
    </p>

    <p>
        {{ form.due_date.label_tag }}<br>
        {{ form.due_date }}
        {{ form.due_date.errors }}
    </p>

    <button type="submit">Crear solicitud</button>
</form>

<p>
    <a href="{% url 'payment_requests:list' %}">Cancelar</a>
</p>
{% endblock %}
HTML

cat > backend/apps/payment_requests/tests/test_views.py <<'PY'
from decimal import Decimal

from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary, BeneficiaryType
from apps.organization.models import Company
from apps.payment_requests.models import Currency, PaymentRequest, PaymentRequestStatus


class PaymentRequestViewsTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.other_company = Company.objects.create(name="Otra Empresa", code="OTH")
        self.user = CustomUser.objects.create_user(
            email="solicitante.views@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.company,
        )
        self.other_user = CustomUser.objects.create_user(
            email="otro.views@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.other_company,
        )
        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Vistas C.A.",
            document_number="J-33333333-3",
            email="proveedor.views@example.com",
        )
        self.other_beneficiary = Beneficiary.objects.create(
            company=self.other_company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Otra Empresa C.A.",
            document_number="J-44444444-4",
            email="proveedor.otra@example.com",
        )
        self.payment_request = PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.user,
            amount=Decimal("250.00"),
            currency=Currency.VES,
            concept="Pago desde vistas",
        )
        self.other_payment_request = PaymentRequest.objects.create(
            company=self.other_company,
            beneficiary=self.other_beneficiary,
            requested_by=self.other_user,
            amount=Decimal("300.00"),
            currency=Currency.VES,
            concept="Pago de otra empresa",
        )

    def test_list_requires_login(self):
        response = self.client.get(reverse("payment_requests:list"))
        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response["Location"])

    def test_create_requires_login(self):
        response = self.client.get(reverse("payment_requests:create"))
        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response["Location"])

    def test_detail_requires_login(self):
        response = self.client.get(reverse("payment_requests:detail", args=[self.payment_request.pk]))
        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response["Location"])

    def test_authenticated_user_can_list_own_company_requests(self):
        self.client.force_login(self.user)
        response = self.client.get(reverse("payment_requests:list"))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Pago desde vistas")
        self.assertNotContains(response, "Pago de otra empresa")

    def test_authenticated_user_can_view_own_company_request_detail(self):
        self.client.force_login(self.user)
        response = self.client.get(reverse("payment_requests:detail", args=[self.payment_request.pk]))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Pago desde vistas")

    def test_authenticated_user_cannot_view_other_company_request_detail(self):
        self.client.force_login(self.user)
        response = self.client.get(reverse("payment_requests:detail", args=[self.other_payment_request.pk]))

        self.assertEqual(response.status_code, 404)

    def test_authenticated_user_can_create_payment_request(self):
        self.client.force_login(self.user)
        response = self.client.post(
            reverse("payment_requests:create"),
            data={
                "company": self.company.pk,
                "beneficiary": self.beneficiary.pk,
                "amount": "500.00",
                "currency": Currency.VES,
                "concept": "Nueva solicitud desde formulario",
                "description": "Soporte pendiente",
                "due_date": "2026-12-31",
            },
        )

        self.assertEqual(response.status_code, 302)
        created = PaymentRequest.objects.get(concept="Nueva solicitud desde formulario")
        self.assertEqual(created.requested_by, self.user)
        self.assertEqual(created.status, PaymentRequestStatus.DRAFT)
        self.assertEqual(created.company, self.company)

    def test_create_rejects_beneficiary_from_another_company(self):
        self.client.force_login(self.user)
        response = self.client.post(
            reverse("payment_requests:create"),
            data={
                "company": self.company.pk,
                "beneficiary": self.other_beneficiary.pk,
                "amount": "500.00",
                "currency": Currency.VES,
                "concept": "Solicitud cruzada inválida",
                "description": "Debe fallar",
                "due_date": "2026-12-31",
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Seleccione una opción válida", html=False)
        self.assertFalse(PaymentRequest.objects.filter(concept="Solicitud cruzada inválida").exists())
PY

cat > docs/03-desarrollo/f1_p14_vistas_basicas_solicitudes_pago.md <<'MD'
# F1-P14 - Vistas básicas de solicitudes de pago

## Objetivo

Agregar una primera capa web para operar solicitudes de pago sin implementar todavía aprobación en pantalla, edición avanzada, adjuntos desde UI o notificaciones.

## Alcance implementado

- Listado autenticado de solicitudes de pago.
- Detalle autenticado de solicitud de pago.
- Creación básica de solicitud de pago.
- Filtro por empresa principal del usuario.
- Protección por login.
- Pruebas transversales de acceso, listado, detalle y creación.

## URLs

```text
/payment-requests/
/payment-requests/new/
/payment-requests/<id>/
```

## Reglas

```text
VIEW-001 El listado requiere autenticación.
VIEW-002 El detalle requiere autenticación.
VIEW-003 La creación requiere autenticación.
VIEW-004 Un usuario no superusuario solo ve solicitudes de su empresa principal.
VIEW-005 Al crear una solicitud, requested_by se asigna automáticamente al usuario autenticado.
VIEW-006 El beneficiario debe pertenecer a la empresa seleccionada.
```

## Fuera de alcance

- Edición de solicitudes.
- Envío a aprobación desde UI.
- Carga de documentos desde UI.
- Notificaciones.
- Permisos granulares por rol.
MD

printf '%s\n' 'OK: F1-P14 basic payment request views generated.'
printf '%s\n' 'Next: run validations and tests.'
