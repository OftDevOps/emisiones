#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' '== F1-P16: Approval and rejection from UI =='

if [ ! -f "backend/manage.py" ]; then
  printf '%s\n' 'ERROR: run this script from repository root: /home/dchirinos/oftalmiIA/emisiones/emisiones' >&2
  exit 1
fi

current_branch="$(git branch --show-current 2>/dev/null || true)"
if [ "$current_branch" = "develop" ]; then
  printf '%s\n' 'ERROR: do not run this feature script on develop. Create/switch to feature/approval-actions-ui first.' >&2
  exit 1
fi

mkdir -p backend/apps/payment_approvals/tests backend/templates/payment_approvals docs/03-desarrollo

cat > backend/apps/payment_approvals/forms.py <<'PY'
from django import forms

from .models import ApprovalActionType


class ApprovalActionForm(forms.Form):
    action = forms.ChoiceField(
        choices=(
            (ApprovalActionType.APPROVE, "Aprobar"),
            (ApprovalActionType.REJECT, "Rechazar"),
        ),
        label="Acción",
    )
    comment = forms.CharField(
        label="Comentario",
        required=False,
        widget=forms.Textarea(attrs={"rows": 3}),
    )

    def clean(self):
        cleaned_data = super().clean()
        action = cleaned_data.get("action")
        comment = (cleaned_data.get("comment") or "").strip()

        if action == ApprovalActionType.REJECT and not comment:
            self.add_error("comment", "El comentario es obligatorio para rechazar una solicitud.")

        cleaned_data["comment"] = comment
        return cleaned_data
PY

cat > backend/apps/payment_approvals/urls.py <<'PY'
from django.urls import path

from . import views

app_name = "payment_approvals"

urlpatterns = [
    path("steps/<int:pk>/action/", views.ApprovalStepActionView.as_view(), name="step_action"),
]
PY

cat > backend/apps/payment_approvals/views.py <<'PY'
from django.contrib import messages
from django.contrib.auth.mixins import LoginRequiredMixin
from django.core.exceptions import PermissionDenied, ValidationError
from django.shortcuts import redirect
from django.views import View

from .forms import ApprovalActionForm
from .models import ApprovalActionType, PaymentApprovalStep


class ApprovalStepActionView(LoginRequiredMixin, View):
    http_method_names = ["post"]

    def get_step(self):
        user = self.request.user
        queryset = PaymentApprovalStep.objects.select_related("payment_request", "payment_request__company")
        step = queryset.get(pk=self.kwargs["pk"])

        if step.payment_request.company_id != user.primary_company_id:
            raise PermissionDenied("No tiene acceso a esta solicitud.")

        if step.required_role != user.role:
            raise PermissionDenied("Su rol no permite ejecutar este paso de aprobación.")

        return step

    def post(self, request, *args, **kwargs):
        step = self.get_step()
        form = ApprovalActionForm(request.POST)
        payment_request = step.payment_request

        if not form.is_valid():
            for field_errors in form.errors.values():
                for error in field_errors:
                    messages.error(request, error)
            return redirect("payment_requests:detail", pk=payment_request.pk)

        action = form.cleaned_data["action"]
        comment = form.cleaned_data["comment"]

        try:
            if action == ApprovalActionType.APPROVE:
                step.approve(user=request.user, comment=comment)
                messages.success(request, "Paso aprobado correctamente.")
            elif action == ApprovalActionType.REJECT:
                step.reject(user=request.user, comment=comment)
                messages.success(request, "Solicitud rechazada correctamente.")
            else:
                messages.error(request, "Acción no válida.")
        except ValidationError as exc:
            if hasattr(exc, "messages"):
                for error in exc.messages:
                    messages.error(request, error)
            else:
                messages.error(request, str(exc))

        return redirect("payment_requests:detail", pk=payment_request.pk)
PY

# Include approval URLs in project URL configuration.
python3 - <<'PY'
from pathlib import Path

path = Path("backend/config/urls.py")
text = path.read_text()

if "payment_approvals.urls" not in text:
    text = text.replace(
        "path(\"payment-requests/\", include(\"apps.payment_requests.urls\")),",
        "path(\"payment-requests/\", include(\"apps.payment_requests.urls\")),\n    path(\"payment-approvals/\", include(\"apps.payment_approvals.urls\")),",
    )

path.write_text(text)
PY

# Patch payment request detail template to show actionable approval buttons for the current user's pending step.
python3 - <<'PY'
from pathlib import Path

path = Path("backend/templates/payment_requests/paymentrequest_detail.html")
text = path.read_text()

marker = "{% endblock %}"
block = r'''

<h2>Acciones de aprobación</h2>
{% if approval_steps %}
<table>
    <thead>
        <tr>
            <th>Orden</th>
            <th>Rol requerido</th>
            <th>Estado</th>
            <th>Aprobador</th>
            <th>Fecha</th>
            <th>Acción</th>
        </tr>
    </thead>
    <tbody>
        {% for step in approval_steps %}
        <tr>
            <td>{{ step.order }}</td>
            <td>{{ step.get_required_role_display }}</td>
            <td>{{ step.get_status_display }}</td>
            <td>{{ step.acted_by|default:"-" }}</td>
            <td>{{ step.acted_at|date:"Y-m-d H:i"|default:"-" }}</td>
            <td>
                {% if step.can_current_user_act %}
                <form method="post" action="{% url 'payment_approvals:step_action' step.pk %}">
                    {% csrf_token %}
                    <textarea name="comment" rows="2" placeholder="Comentario"></textarea><br>
                    <button type="submit" name="action" value="APPROVE">Aprobar</button>
                    <button type="submit" name="action" value="REJECT">Rechazar</button>
                </form>
                {% else %}
                -
                {% endif %}
            </td>
        </tr>
        {% endfor %}
    </tbody>
</table>
{% else %}
<p>No hay ruta de aprobación generada.</p>
{% endif %}
'''

if "<h2>Acciones de aprobación</h2>" not in text:
    text = text.replace(marker, block + "\n" + marker)

path.write_text(text)
PY

# Patch payment request detail view context to expose approval_steps and can_current_user_act flag.
python3 - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_requests/views.py")
text = path.read_text()

if "PaymentApprovalStep" not in text:
    text = text.replace(
        "from .models import PaymentRequest",
        "from apps.payment_approvals.models import ApprovalStepStatus, PaymentApprovalStep\n\nfrom .models import PaymentRequest",
    )

old = '''class PaymentRequestDetailView(LoginRequiredMixin, DetailView):
    model = PaymentRequest
    template_name = "payment_requests/paymentrequest_detail.html"
    context_object_name = "payment_request"

    def get_queryset(self):
        return PaymentRequest.objects.filter(company=self.request.user.primary_company)
'''

new = '''class PaymentRequestDetailView(LoginRequiredMixin, DetailView):
    model = PaymentRequest
    template_name = "payment_requests/paymentrequest_detail.html"
    context_object_name = "payment_request"

    def get_queryset(self):
        return PaymentRequest.objects.filter(company=self.request.user.primary_company)

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        approval_steps = list(
            PaymentApprovalStep.objects.filter(payment_request=self.object).order_by("order")
        )
        for step in approval_steps:
            step.can_current_user_act = (
                step.status == ApprovalStepStatus.PENDING
                and step.required_role == self.request.user.role
                and self.object.company_id == self.request.user.primary_company_id
            )
        context["approval_steps"] = approval_steps
        return context
'''

if old in text:
    text = text.replace(old, new)
elif "def get_context_data" not in text and "class PaymentRequestDetailView" in text:
    raise SystemExit("ERROR: PaymentRequestDetailView structure was not recognized. Inspect views.py manually.")

path.write_text(text)
PY

cat > backend/apps/payment_approvals/tests/test_views.py <<'PY'
from decimal import Decimal

from django.core.exceptions import PermissionDenied
from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary, BeneficiaryType
from apps.organization.models import Company
from apps.payment_approvals.models import ApprovalActionType, ApprovalStepStatus, PaymentApprovalAction, PaymentApprovalStep
from apps.payment_requests.models import Currency, PaymentRequest, PaymentRequestStatus


class ApprovalActionViewsTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.other_company = Company.objects.create(name="Otra Empresa", code="OTH")
        self.requester = CustomUser.objects.create_user(
            email="solicitante.approval.ui@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.company,
        )
        self.unit_approver = CustomUser.objects.create_user(
            email="unidad.approval.ui@oftalmi.com",
            password="test-pass-123",
            role=UserRole.RESPONSABLE_UNIDAD,
            primary_company=self.company,
        )
        self.finance_approver = CustomUser.objects.create_user(
            email="finanzas.approval.ui@oftalmi.com",
            password="test-pass-123",
            role=UserRole.FINANZAS,
            primary_company=self.company,
        )
        self.other_approver = CustomUser.objects.create_user(
            email="unidad.otra@oftalmi.com",
            password="test-pass-123",
            role=UserRole.RESPONSABLE_UNIDAD,
            primary_company=self.other_company,
        )
        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor UI Approval C.A.",
            document_number="J-33333333-3",
        )
        self.payment_request = PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.requester,
            amount=Decimal("350.00"),
            currency=Currency.VES,
            concept="Pago para aprobación UI",
            status=PaymentRequestStatus.UNIT_REVIEW,
        )
        self.step = PaymentApprovalStep.objects.create(
            payment_request=self.payment_request,
            order=1,
            required_role=UserRole.RESPONSABLE_UNIDAD,
            status=ApprovalStepStatus.PENDING,
        )

    def test_login_required_to_act_on_step(self):
        response = self.client.post(reverse("payment_approvals:step_action", args=[self.step.pk]), {"action": ApprovalActionType.APPROVE})
        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response.url)

    def test_required_role_can_approve_pending_step(self):
        self.client.force_login(self.unit_approver)
        response = self.client.post(
            reverse("payment_approvals:step_action", args=[self.step.pk]),
            {"action": ApprovalActionType.APPROVE, "comment": "Conforme"},
        )

        self.assertEqual(response.status_code, 302)
        self.step.refresh_from_db()
        self.payment_request.refresh_from_db()
        self.assertEqual(self.step.status, ApprovalStepStatus.APPROVED)
        self.assertEqual(self.step.acted_by, self.unit_approver)
        self.assertTrue(
            PaymentApprovalAction.objects.filter(
                step=self.step,
                action=ApprovalActionType.APPROVE,
                acted_by=self.unit_approver,
            ).exists()
        )

    def test_reject_requires_comment(self):
        self.client.force_login(self.unit_approver)
        response = self.client.post(
            reverse("payment_approvals:step_action", args=[self.step.pk]),
            {"action": ApprovalActionType.REJECT, "comment": ""},
        )

        self.assertEqual(response.status_code, 302)
        self.step.refresh_from_db()
        self.payment_request.refresh_from_db()
        self.assertEqual(self.step.status, ApprovalStepStatus.PENDING)
        self.assertEqual(self.payment_request.status, PaymentRequestStatus.UNIT_REVIEW)

    def test_required_role_can_reject_with_comment(self):
        self.client.force_login(self.unit_approver)
        response = self.client.post(
            reverse("payment_approvals:step_action", args=[self.step.pk]),
            {"action": ApprovalActionType.REJECT, "comment": "No procede"},
        )

        self.assertEqual(response.status_code, 302)
        self.step.refresh_from_db()
        self.payment_request.refresh_from_db()
        self.assertEqual(self.step.status, ApprovalStepStatus.REJECTED)
        self.assertEqual(self.payment_request.status, PaymentRequestStatus.REJECTED)

    def test_wrong_role_cannot_act_on_step(self):
        self.client.force_login(self.finance_approver)
        with self.assertRaises(PermissionDenied):
            self.client.post(reverse("payment_approvals:step_action", args=[self.step.pk]), {"action": ApprovalActionType.APPROVE})

    def test_other_company_user_cannot_act_on_step(self):
        self.client.force_login(self.other_approver)
        with self.assertRaises(PermissionDenied):
            self.client.post(reverse("payment_approvals:step_action", args=[self.step.pk]), {"action": ApprovalActionType.APPROVE})

    def test_detail_marks_current_user_actionable_step(self):
        self.client.force_login(self.unit_approver)
        response = self.client.get(reverse("payment_requests:detail", args=[self.payment_request.pk]))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Aprobar")
        self.assertContains(response, "Rechazar")
PY

cat > docs/03-desarrollo/f1_p16_aprobacion_rechazo_ui.md <<'MD'
# F1-P16 Aprobación y rechazo desde UI

## Objetivo

Permitir que un usuario con rol aprobador ejecute desde la interfaz web una acción sobre su paso pendiente de aprobación.

## Alcance implementado

- Acción web `POST` para aprobar un paso.
- Acción web `POST` para rechazar un paso.
- Validación de usuario autenticado.
- Validación de empresa principal del usuario.
- Validación de rol requerido por el paso.
- Comentario obligatorio para rechazo.
- Visualización de la ruta de aprobación en el detalle de la solicitud.
- Botones de aprobación/rechazo cuando el paso corresponde al usuario actual.

## Rutas

```text
/payment-approvals/steps/<id>/action/
```

## Reglas

```text
APP-008 Solo el rol requerido puede actuar sobre un paso pendiente.
APP-009 Un usuario no puede actuar sobre solicitudes de otra empresa.
APP-010 Aprobar registra acción, usuario, fecha y comentario opcional.
APP-011 Rechazar exige comentario y cambia la solicitud a REJECTED.
APP-012 La interfaz solo muestra acciones cuando el paso corresponde al usuario actual.
```

## Fuera de alcance

```text
Notificaciones.
Delegaciones.
Reasignación de aprobadores.
Aprobación masiva.
Firma electrónica.
Dashboard ejecutivo.
```
MD

cat > docs/03-desarrollo/continuidad_post_f1_p16.md <<'MD'
# Continuidad posterior a F1-P16

## Estado alcanzado

El sistema permite crear solicitudes, enviarlas a aprobación y ejecutar aprobación/rechazo desde la interfaz web según rol y empresa.

## Siguiente bloque recomendado

```text
F1-P17 Carga de documentos desde UI
```

## Objetivo siguiente

Permitir adjuntar soportes desde la pantalla de detalle de una solicitud de pago.

## Validación estándar

```bash
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
```
MD

printf '%s\n' 'OK: F1-P16 approval/rejection UI files generated.'
printf '%s\n' 'Next: run validation block, commit, push and merge after tests pass.'
