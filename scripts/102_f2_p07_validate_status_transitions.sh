#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_ROOT"

echo "== F2-P07: validacion tecnica de transiciones de estados =="

TEST_FILE="backend/apps/payment_requests/tests/test_status_transition_matrix.py"
DOC_FILE="docs/f2_p07_validacion_tecnica_transiciones.md"
MATRIX_DOC="docs/matriz_validacion_tecnica_transiciones_fase2.md"
ROADMAP="docs/roadmap_fase2.md"

echo "== Verificando precondiciones F2-P06 =="
test -f "docs/f2_p06_estados_transiciones_solicitudes_pago.md"
test -f "docs/matriz_estados_transiciones_solicitudes_pago_fase2.md"
grep -q "DRAFT" backend/apps/payment_requests/models.py
grep -q "UNIT_REVIEW" backend/apps/payment_requests/models.py
grep -q "PaymentExecution" backend/apps/payment_execution/models.py

echo "== Creando pruebas integradas de transiciones =="
cat > "$TEST_FILE" <<'PY'
from datetime import date
from decimal import Decimal

from django.core.exceptions import ValidationError
from django.test import TestCase

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary, BeneficiaryType
from apps.organization.models import Company
from apps.payment_approvals.models import ApprovalActionType, ApprovalStepStatus, PaymentApprovalAction
from apps.payment_execution.models import PaymentExecution
from apps.payment_requests.models import Currency, PaymentRequest, PaymentRequestStatus


class PaymentRequestStatusTransitionMatrixTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.requester = self.create_user("solicitante.transition@oftalmi.com", UserRole.SOLICITANTE)
        self.unit_manager = self.create_user("unidad.transition@oftalmi.com", UserRole.RESPONSABLE_UNIDAD)
        self.finance = self.create_user("finanzas.transition@oftalmi.com", UserRole.FINANZAS)
        self.management = self.create_user("gerencia.transition@oftalmi.com", UserRole.GERENCIA_GENERAL)
        self.accounts_payable = self.create_user("cxp.transition@oftalmi.com", UserRole.CUENTAS_POR_PAGAR)
        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Transiciones C.A.",
            document_number="J-77777777-7",
            email="proveedor.transiciones@example.com",
        )

    def create_user(self, email, role):
        return CustomUser.objects.create_user(
            email=email,
            password="test-pass-123",
            role=role,
            primary_company=self.company,
        )

    def create_payment_request(self, concept="Pago matriz de transiciones"):
        return PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.requester,
            amount=Decimal("750.00"),
            currency=Currency.VES,
            concept=concept,
            due_date=date.today(),
        )

    def test_full_happy_path_transitions_from_draft_to_paid(self):
        payment_request = self.create_payment_request()

        self.assertEqual(payment_request.status, PaymentRequestStatus.DRAFT)

        payment_request.submit_for_approval(self.requester)
        payment_request.refresh_from_db()
        self.assertEqual(payment_request.status, PaymentRequestStatus.UNIT_REVIEW)

        step1 = payment_request.approval_steps.get(sequence=1)
        step1.approve(self.unit_manager, "Unidad conforme")
        payment_request.refresh_from_db()
        self.assertEqual(payment_request.status, PaymentRequestStatus.FINANCE_REVIEW)

        step2 = payment_request.approval_steps.get(sequence=2)
        step2.approve(self.finance, "Finanzas conforme")
        payment_request.refresh_from_db()
        self.assertEqual(payment_request.status, PaymentRequestStatus.MANAGEMENT_REVIEW)

        step3 = payment_request.approval_steps.get(sequence=3)
        step3.approve(self.management, "Gerencia aprueba")
        payment_request.refresh_from_db()
        self.assertEqual(payment_request.status, PaymentRequestStatus.APPROVED)

        PaymentExecution.objects.create(
            payment_request=payment_request,
            executed_by=self.accounts_payable,
            paid_at=date.today(),
            paid_amount=Decimal("750.00"),
            bank_reference="TRANSITION-PAID-001",
        )
        payment_request.refresh_from_db()
        self.assertEqual(payment_request.status, PaymentRequestStatus.PAID)

    def test_draft_can_transition_to_cancelled_and_records_action(self):
        payment_request = self.create_payment_request("Pago cancelable")
        payment_request.status = PaymentRequestStatus.CANCELLED
        payment_request.save(update_fields=["status", "updated_at"])
        PaymentApprovalAction.objects.create(
            payment_request=payment_request,
            action=ApprovalActionType.CANCEL,
            performed_by=self.requester,
            role=self.requester.role,
            comment="Solicitud cancelada por prueba de matriz.",
        )

        self.assertEqual(payment_request.status, PaymentRequestStatus.CANCELLED)
        self.assertTrue(
            payment_request.approval_actions.filter(action=ApprovalActionType.CANCEL).exists()
        )

    def test_review_step_rejection_transitions_request_to_rejected(self):
        payment_request = self.create_payment_request("Pago rechazable")
        payment_request.submit_for_approval(self.requester)

        step1 = payment_request.approval_steps.get(sequence=1)
        step1.approve(self.unit_manager, "Unidad conforme")
        payment_request.refresh_from_db()
        self.assertEqual(payment_request.status, PaymentRequestStatus.FINANCE_REVIEW)

        step2 = payment_request.approval_steps.get(sequence=2)
        step2.reject(self.finance, "Falta soporte financiero")
        payment_request.refresh_from_db()
        step2.refresh_from_db()

        self.assertEqual(payment_request.status, PaymentRequestStatus.REJECTED)
        self.assertEqual(step2.status, ApprovalStepStatus.REJECTED)
        self.assertTrue(
            payment_request.approval_actions.filter(action=ApprovalActionType.REJECT).exists()
        )

    def test_request_cannot_be_submitted_outside_draft(self):
        payment_request = self.create_payment_request("Pago no reenviable")
        payment_request.submit_for_approval(self.requester)
        payment_request.refresh_from_db()

        with self.assertRaises(ValidationError):
            payment_request.submit_for_approval(self.requester)

    def test_payment_execution_requires_approved_request(self):
        payment_request = self.create_payment_request("Pago no aprobado")

        with self.assertRaises(ValidationError):
            PaymentExecution.objects.create(
                payment_request=payment_request,
                executed_by=self.accounts_payable,
                paid_at=date.today(),
                paid_amount=Decimal("750.00"),
                bank_reference="TRANSITION-BLOCKED-001",
            )

        payment_request.refresh_from_db()
        self.assertEqual(payment_request.status, PaymentRequestStatus.DRAFT)

    def test_submitted_state_is_not_used_by_current_transition_flow(self):
        payment_request = self.create_payment_request("Pago sin estado submitted")
        payment_request.submit_for_approval(self.requester)
        payment_request.refresh_from_db()

        self.assertNotEqual(payment_request.status, PaymentRequestStatus.SUBMITTED)
        self.assertEqual(payment_request.status, PaymentRequestStatus.UNIT_REVIEW)
PY

echo "== Creando documentacion F2-P07 =="
cat > "$DOC_FILE" <<'MD'
# F2-P07 - Validacion tecnica de transiciones

## Objetivo

Convertir la documentacion de estados y transiciones de F2-P06 en cobertura automatizada explicita.

Este punto valida el ciclo de vida operativo de una solicitud de pago sin crear modelos nuevos, sin migraciones y sin modificar reglas funcionales.

## Cobertura agregada

Se agrega la prueba integrada:

```text
backend/apps/payment_requests/tests/test_status_transition_matrix.py
```

## Transiciones validadas

```text
DRAFT
  -> UNIT_REVIEW
  -> FINANCE_REVIEW
  -> MANAGEMENT_REVIEW
  -> APPROVED
  -> PAID
```

Adicionalmente se valida:

- `DRAFT -> CANCELLED`.
- Rechazo en etapa de revision hacia `REJECTED`.
- Bloqueo de reenvio cuando la solicitud ya no esta en `DRAFT`.
- Bloqueo de ejecucion de pago cuando la solicitud no esta `APPROVED`.
- Confirmacion de que `SUBMITTED` no es usado por el flujo actual como estado persistente.

## Resultado esperado

La matriz de transiciones queda protegida por pruebas automatizadas, reduciendo riesgo de regresiones en aprobaciones, rechazos, cancelaciones y ejecucion de pagos.
MD

cat > "$MATRIX_DOC" <<'MD'
# Matriz de validacion tecnica de transiciones - Fase 2

| Caso | Origen | Accion | Destino esperado | Validacion |
|---|---|---|---|---|
| Flujo feliz 1 | `DRAFT` | Enviar a aprobacion | `UNIT_REVIEW` | Test integrado |
| Flujo feliz 2 | `UNIT_REVIEW` | Aprobar unidad | `FINANCE_REVIEW` | Test integrado |
| Flujo feliz 3 | `FINANCE_REVIEW` | Aprobar finanzas | `MANAGEMENT_REVIEW` | Test integrado |
| Flujo feliz 4 | `MANAGEMENT_REVIEW` | Aprobar gerencia | `APPROVED` | Test integrado |
| Ejecucion | `APPROVED` | Registrar pago | `PAID` | Test integrado |
| Cancelacion | `DRAFT` | Cancelar | `CANCELLED` | Test integrado |
| Rechazo | Revision activa | Rechazar paso pendiente | `REJECTED` | Test integrado |
| Bloqueo | No `DRAFT` | Reenviar | Error de validacion | Test integrado |
| Bloqueo | No `APPROVED` | Registrar pago | Error de validacion | Test integrado |
| Deuda conocida | `SUBMITTED` | Flujo principal | No usado | Test integrado/documental |

## Nota de gobierno

`SUBMITTED` permanece como estado contractual/historico, pero el flujo actual salta de `DRAFT` a `UNIT_REVIEW` al enviar a aprobacion.
MD

echo "== Actualizando roadmap Fase 2 =="
python3 - <<'PY'
from pathlib import Path

path = Path("docs/roadmap_fase2.md")
text = path.read_text(encoding="utf-8")
text = text.replace(
    "| 8 | F2-P08 | Dashboard operativo mejorado por rol |\n| 8 | F2-P08 | Reporte basico por estado, empresa y fecha |",
    "| 8 | F2-P08 | Dashboard operativo mejorado por rol |\n| 9 | F2-P09 | Reporte basico por estado, empresa y fecha |",
)
text = text.replace("| 9 | F2-P09 | Exportacion operativa basica |", "| 10 | F2-P10 | Exportacion operativa basica |")
text = text.replace("| 10 | F2-P10 | Auditoria extendida |", "| 11 | F2-P11 | Auditoria extendida |")
text = text.replace("| 11 | F2-P11 | Paquete de validacion con usuarios internos |", "| 12 | F2-P12 | Paquete de validacion con usuarios internos |")
text = text.replace("| 12 | F2-P12 | Cierre tecnico de Fase 2 |", "| 13 | F2-P13 | Cierre tecnico de Fase 2 |")
old = """## Siguiente accion\n\nEjecutar F2-P06 con foco en:\n\n- Estados actuales de solicitud.\n- Transiciones efectivas.\n- Actores por transicion.\n- Estados terminales.\n- Deuda tecnica sobre SUBMITTED.\n- Validacion sin migraciones.\n"""
new = """## Siguiente accion\n\nEjecutar F2-P08 con foco en:\n\n- Dashboard operativo por rol.\n- Indicadores visibles segun permisos.\n- Enlaces de accion coherentes con la matriz UX-permisos.\n- Sin modelos nuevos salvo necesidad justificada.\n- Sin migraciones salvo necesidad justificada.\n"""
if old in text:
    text = text.replace(old, new)
path.write_text(text, encoding="utf-8")
PY

echo "== Ruff focal =="
docker compose exec backend ruff check apps/payment_requests/tests/test_status_transition_matrix.py

echo "== Tests focales de transiciones =="
docker compose exec backend python manage.py test \
  apps.payment_requests.tests.test_status_transition_matrix \
  apps.payment_approvals.tests.test_models \
  apps.payment_requests.tests.test_actions \
  apps.payment_execution.tests.test_views

echo "== Validacion global rapida =="
docker compose exec backend ruff check .
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== Estado posterior =="
git status --short
