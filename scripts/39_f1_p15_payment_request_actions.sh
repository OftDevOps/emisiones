#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' '== F1-P15: Basic payment request actions =='

if [ ! -f "backend/manage.py" ]; then
  printf '%s\n' 'ERROR: run this script from repository root: /home/dchirinos/oftalmiIA/emisiones/emisiones' >&2
  exit 1
fi

mkdir -p backend/apps/payment_requests/tests docs/03-desarrollo

touch backend/apps/payment_requests/tests/__init__.py

cat > backend/apps/payment_requests/views.py <<'PY'
from django.contrib.auth.mixins import LoginRequiredMixin
from django.core.exceptions import ValidationError
from django.shortcuts import get_object_or_404, redirect
from django.urls import reverse_lazy
from django.views import View
from django.views.generic import CreateView, DetailView, ListView

from apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction

from .forms import PaymentRequestCreateForm
from .models import PaymentRequest, PaymentRequestStatus


def scoped_payment_request_queryset(user):
    queryset = PaymentRequest.objects.select_related("company", "beneficiary", "requested_by")

    if not user.is_superuser and getattr(user, "primary_company_id", None):
        queryset = queryset.filter(company=user.primary_company)

    return queryset


class PaymentRequestListView(LoginRequiredMixin, ListView):
    model = PaymentRequest
    template_name = "payment_requests/paymentrequest_list.html"
    context_object_name = "payment_requests"
    paginate_by = 20

    def get_queryset(self):
        return scoped_payment_request_queryset(self.request.user).order_by("-created_at")


class PaymentRequestDetailView(LoginRequiredMixin, DetailView):
    model = PaymentRequest
    template_name = "payment_requests/paymentrequest_detail.html"
    context_object_name = "payment_request"

    def get_queryset(self):
        return scoped_payment_request_queryset(self.request.user).prefetch_related(
            "approval_steps",
            "approval_actions",
        )


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


class PaymentRequestSubmitView(LoginRequiredMixin, View):
    def post(self, request, pk):
        payment_request = get_object_or_404(scoped_payment_request_queryset(request.user), pk=pk)

        try:
            payment_request.submit_for_approval(request.user)
        except ValidationError:
            pass

        return redirect("payment_requests:detail", pk=payment_request.pk)


class PaymentRequestCancelView(LoginRequiredMixin, View):
    def post(self, request, pk):
        payment_request = get_object_or_404(scoped_payment_request_queryset(request.user), pk=pk)

        if payment_request.status == PaymentRequestStatus.DRAFT:
            payment_request.status = PaymentRequestStatus.CANCELLED
            payment_request.save(update_fields=["status", "updated_at"])
            PaymentApprovalAction.objects.create(
                payment_request=payment_request,
                action=ApprovalActionType.CANCEL,
                performed_by=request.user,
                role=request.user.role,
                comment="Solicitud cancelada por el solicitante.",
            )

        return redirect("payment_requests:detail", pk=payment_request.pk)
PY

cat > backend/apps/payment_requests/urls.py <<'PY'
from django.urls import path

from .views import (
    PaymentRequestCancelView,
    PaymentRequestCreateView,
    PaymentRequestDetailView,
    PaymentRequestListView,
    PaymentRequestSubmitView,
)

app_name = "payment_requests"

urlpatterns = [
    path("", PaymentRequestListView.as_view(), name="list"),
    path("new/", PaymentRequestCreateView.as_view(), name="create"),
    path("<int:pk>/", PaymentRequestDetailView.as_view(), name="detail"),
    path("<int:pk>/submit/", PaymentRequestSubmitView.as_view(), name="submit"),
    path("<int:pk>/cancel/", PaymentRequestCancelView.as_view(), name="cancel"),
]
PY

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

{% if payment_request.status == "DRAFT" %}
<section>
    <h2>Acciones</h2>

    <form method="post" action="{% url 'payment_requests:submit' payment_request.pk %}">
        {% csrf_token %}
        <button type="submit">Enviar a aprobación</button>
    </form>

    <form method="post" action="{% url 'payment_requests:cancel' payment_request.pk %}">
        {% csrf_token %}
        <button type="submit">Cancelar solicitud</button>
    </form>
</section>
{% endif %}

<section>
    <h2>Ruta de aprobación</h2>

    {% with steps=payment_request.approval_steps.all %}
        {% if steps %}
        <table>
            <thead>
                <tr>
                    <th>Secuencia</th>
                    <th>Rol requerido</th>
                    <th>Estado</th>
                    <th>Ejecutado por</th>
                    <th>Fecha</th>
                    <th>Comentario</th>
                </tr>
            </thead>
            <tbody>
                {% for step in steps %}
                <tr>
                    <td>{{ step.sequence }}</td>
                    <td>{{ step.get_required_role_display }}</td>
                    <td>{{ step.get_status_display }}</td>
                    <td>{{ step.acted_by|default:"-" }}</td>
                    <td>{{ step.acted_at|date:"Y-m-d H:i"|default:"-" }}</td>
                    <td>{{ step.comment|default:"-" }}</td>
                </tr>
                {% endfor %}
            </tbody>
        </table>
        {% else %}
        <p>La solicitud todavía no tiene ruta de aprobación generada.</p>
        {% endif %}
    {% endwith %}
</section>

<section>
    <h2>Historial de acciones</h2>

    {% with actions=payment_request.approval_actions.all %}
        {% if actions %}
        <table>
            <thead>
                <tr>
                    <th>Acción</th>
                    <th>Usuario</th>
                    <th>Rol</th>
                    <th>Fecha</th>
                    <th>Comentario</th>
                </tr>
            </thead>
            <tbody>
                {% for action in actions %}
                <tr>
                    <td>{{ action.get_action_display }}</td>
                    <td>{{ action.performed_by }}</td>
                    <td>{{ action.get_role_display }}</td>
                    <td>{{ action.created_at|date:"Y-m-d H:i" }}</td>
                    <td>{{ action.comment|default:"-" }}</td>
                </tr>
                {% endfor %}
            </tbody>
        </table>
        {% else %}
        <p>Sin acciones registradas.</p>
        {% endif %}
    {% endwith %}
</section>

<p>
    <a href="{% url 'payment_requests:list' %}">Volver al listado</a>
</p>
{% endblock %}
HTML

cat > backend/apps/payment_requests/tests/test_actions.py <<'PY'
from decimal import Decimal

from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary, BeneficiaryType
from apps.organization.models import Company
from apps.payment_approvals.models import ApprovalActionType
from apps.payment_requests.models import Currency, PaymentRequest, PaymentRequestStatus


class PaymentRequestActionsTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.other_company = Company.objects.create(name="Otra Empresa", code="OTH")
        self.user = CustomUser.objects.create_user(
            email="solicitante.actions@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.company,
        )
        self.other_user = CustomUser.objects.create_user(
            email="otro.actions@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.other_company,
        )
        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Acciones C.A.",
            document_number="J-55555555-5",
            email="proveedor.acciones@example.com",
        )
        self.other_beneficiary = Beneficiary.objects.create(
            company=self.other_company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Externo C.A.",
            document_number="J-66666666-6",
            email="proveedor.externo@example.com",
        )
        self.payment_request = PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.user,
            amount=Decimal("500.00"),
            currency=Currency.VES,
            concept="Pago acciones básicas",
        )
        self.other_payment_request = PaymentRequest.objects.create(
            company=self.other_company,
            beneficiary=self.other_beneficiary,
            requested_by=self.other_user,
            amount=Decimal("900.00"),
            currency=Currency.VES,
            concept="Pago externo acciones",
        )

    def test_submit_requires_login(self):
        response = self.client.post(
            reverse("payment_requests:submit", args=[self.payment_request.pk])
        )

        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response.url)

    def test_authenticated_user_can_submit_draft_request(self):
        self.client.login(email="solicitante.actions@oftalmi.com", password="test-pass-123")
        response = self.client.post(
            reverse("payment_requests:submit", args=[self.payment_request.pk])
        )
        self.payment_request.refresh_from_db()

        self.assertEqual(response.status_code, 302)
        self.assertEqual(self.payment_request.status, PaymentRequestStatus.UNIT_REVIEW)
        self.assertEqual(self.payment_request.approval_steps.count(), 3)
        self.assertTrue(
            self.payment_request.approval_actions.filter(
                action=ApprovalActionType.SUBMIT,
                performed_by=self.user,
            ).exists()
        )

    def test_user_cannot_submit_other_company_request(self):
        self.client.login(email="solicitante.actions@oftalmi.com", password="test-pass-123")
        response = self.client.post(
            reverse("payment_requests:submit", args=[self.other_payment_request.pk])
        )
        self.other_payment_request.refresh_from_db()

        self.assertEqual(response.status_code, 404)
        self.assertEqual(self.other_payment_request.status, PaymentRequestStatus.DRAFT)

    def test_authenticated_user_can_cancel_draft_request(self):
        self.client.login(email="solicitante.actions@oftalmi.com", password="test-pass-123")
        response = self.client.post(
            reverse("payment_requests:cancel", args=[self.payment_request.pk])
        )
        self.payment_request.refresh_from_db()

        self.assertEqual(response.status_code, 302)
        self.assertEqual(self.payment_request.status, PaymentRequestStatus.CANCELLED)
        self.assertTrue(
            self.payment_request.approval_actions.filter(
                action=ApprovalActionType.CANCEL,
                performed_by=self.user,
            ).exists()
        )

    def test_cancel_does_not_affect_non_draft_request(self):
        self.payment_request.submit_for_approval(self.user)
        self.client.login(email="solicitante.actions@oftalmi.com", password="test-pass-123")
        response = self.client.post(
            reverse("payment_requests:cancel", args=[self.payment_request.pk])
        )
        self.payment_request.refresh_from_db()

        self.assertEqual(response.status_code, 302)
        self.assertEqual(self.payment_request.status, PaymentRequestStatus.UNIT_REVIEW)
        self.assertFalse(
            self.payment_request.approval_actions.filter(action=ApprovalActionType.CANCEL).exists()
        )

    def test_detail_shows_approval_route_after_submit(self):
        self.payment_request.submit_for_approval(self.user)
        self.client.login(email="solicitante.actions@oftalmi.com", password="test-pass-123")
        response = self.client.get(
            reverse("payment_requests:detail", args=[self.payment_request.pk])
        )

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Ruta de aprobación")
        self.assertContains(response, "Responsable de unidad")
        self.assertContains(response, "Historial de acciones")
PY

cat > docs/03-desarrollo/f1_p15_acciones_basicas_solicitudes.md <<'MD'
# F1-P15 Acciones básicas sobre solicitudes

## Objetivo

Agregar acciones operativas mínimas sobre una solicitud de pago desde la capa web.

## Alcance implementado

- Acción `Enviar a aprobación` por POST.
- Acción `Cancelar solicitud` por POST.
- Visualización de ruta de aprobación en el detalle.
- Visualización de historial de acciones en el detalle.
- Protección por login.
- Filtro por empresa principal del usuario.
- Pruebas transversales de acciones.

## Endpoints

```text
POST /payment-requests/<id>/submit/
POST /payment-requests/<id>/cancel/
```

## Reglas

```text
ACT-001 Solo usuarios autenticados pueden ejecutar acciones.
ACT-002 Un usuario no puede accionar solicitudes de otra empresa.
ACT-003 Solo solicitudes DRAFT pueden enviarse a aprobación.
ACT-004 Enviar a aprobación genera ruta base de aprobación.
ACT-005 Solo solicitudes DRAFT pueden cancelarse desde esta acción básica.
ACT-006 La cancelación registra acción de auditoría.
ACT-007 Las acciones se ejecutan por POST, no por GET.
```

## Fuera de alcance

```text
Notificaciones.
Carga de documentos desde UI.
Aprobación/rechazo desde UI.
Permisos finos por rol en vistas.
Dashboard ejecutivo.
```

## Validación esperada

```text
ruff check . OK
python manage.py check OK
python manage.py makemigrations --check --dry-run No changes detected
python manage.py migrate No migrations to apply
python manage.py test ... OK
```
MD

cat > docs/03-desarrollo/continuidad_post_f1_p15.md <<'MD'
# Continuidad posterior a F1-P15

## Estado esperado

```text
F1-P15 Acciones básicas sobre solicitudes — COMPLETADO
```

## Próximo bloque recomendado

```text
F1-P16 Aprobación y rechazo desde UI
```

## Objetivo próximo

Permitir que los roles responsables ejecuten aprobación o rechazo desde la interfaz web sobre los pasos pendientes de la ruta.

## Reglas iniciales para F1-P16

```text
APR-UI-001 Solo el rol requerido puede aprobar o rechazar un paso.
APR-UI-002 El rechazo debe exigir comentario.
APR-UI-003 La acción debe actualizar la solicitud.
APR-UI-004 La vista debe respetar aislamiento por empresa.
APR-UI-005 La acción debe quedar registrada en PaymentApprovalAction.
```
MD

printf '%s\n' 'OK: F1-P15 files generated.'
printf '%s\n' 'Next: run Ruff, Django checks, migrations and tests before commit.'
