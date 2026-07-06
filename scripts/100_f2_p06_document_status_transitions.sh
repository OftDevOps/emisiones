#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_ROOT"

echo "== F2-P06: documentar estados y transiciones de solicitudes de pago =="

DOC_FILE="docs/f2_p06_estados_transiciones_solicitudes_pago.md"
MATRIX_FILE="docs/matriz_estados_transiciones_solicitudes_pago_fase2.md"
ROADMAP_FILE="docs/roadmap_fase2.md"

if [ ! -f "backend/apps/payment_requests/models.py" ]; then
  echo "ERROR: no existe backend/apps/payment_requests/models.py"
  exit 1
fi

if [ ! -f "backend/apps/payment_approvals/models.py" ]; then
  echo "ERROR: no existe backend/apps/payment_approvals/models.py"
  exit 1
fi

if [ ! -f "backend/apps/payment_execution/models.py" ]; then
  echo "ERROR: no existe backend/apps/payment_execution/models.py"
  exit 1
fi

mkdir -p docs

echo "== Verificando estados existentes =="
grep -q 'class PaymentRequestStatus' backend/apps/payment_requests/models.py
grep -q 'DRAFT = "DRAFT"' backend/apps/payment_requests/models.py
grep -q 'UNIT_REVIEW = "UNIT_REVIEW"' backend/apps/payment_requests/models.py
grep -q 'FINANCE_REVIEW = "FINANCE_REVIEW"' backend/apps/payment_requests/models.py
grep -q 'MANAGEMENT_REVIEW = "MANAGEMENT_REVIEW"' backend/apps/payment_requests/models.py
grep -q 'APPROVED = "APPROVED"' backend/apps/payment_requests/models.py
grep -q 'PAID = "PAID"' backend/apps/payment_requests/models.py
grep -q 'REJECTED = "REJECTED"' backend/apps/payment_requests/models.py
grep -q 'CANCELLED = "CANCELLED"' backend/apps/payment_requests/models.py

echo "== Verificando transiciones existentes =="
grep -q 'def submit_for_approval' backend/apps/payment_requests/models.py
grep -q 'self.status = PaymentRequestStatus.UNIT_REVIEW' backend/apps/payment_requests/models.py
grep -q 'def refresh_approval_status' backend/apps/payment_requests/models.py
grep -q 'self.status = PaymentRequestStatus.REJECTED' backend/apps/payment_requests/models.py
grep -q 'self.status = PaymentRequestStatus.APPROVED' backend/apps/payment_requests/models.py
grep -q 'self.status = PaymentRequestStatus.FINANCE_REVIEW' backend/apps/payment_requests/models.py
grep -q 'self.status = PaymentRequestStatus.MANAGEMENT_REVIEW' backend/apps/payment_requests/models.py
grep -q 'payment_request.status = PaymentRequestStatus.CANCELLED' backend/apps/payment_requests/views.py
grep -q 'PaymentRequestStatus.PAID' backend/apps/payment_execution/models.py

cat > "$DOC_FILE" <<'MD'
# F2-P06 - Estados y transiciones de solicitudes de pago

## Objetivo

Documentar el ciclo de vida operativo de una solicitud de pago en Apps Emisiones, dejando trazabilidad clara de estados, transiciones, actores y restricciones actuales.

Este punto no introduce cambios de modelo, migraciones ni reglas de negocio. Su foco es gobierno funcional y QA de proceso.

## Estados actuales

Los estados efectivos de `PaymentRequestStatus` son:

| Estado | Etiqueta | Uso operativo |
|---|---|---|
| `DRAFT` | Borrador | Solicitud creada, editable y aun no enviada a aprobacion. |
| `SUBMITTED` | Enviada | Estado historico/de contrato, actualmente no usado por el flujo principal. |
| `UNIT_REVIEW` | Revision unidad | Solicitud enviada a aprobacion; primer paso pendiente del responsable de unidad. |
| `FINANCE_REVIEW` | Revision finanzas | Paso de unidad aprobado; queda pendiente Finanzas. |
| `MANAGEMENT_REVIEW` | Revision gerencia | Paso de Finanzas aprobado; queda pendiente Gerencia General. |
| `APPROVED` | Aprobada | Todos los pasos de aprobacion fueron aprobados. Lista para Cuentas por Pagar. |
| `PAID` | Pagada | Pago registrado mediante ejecucion de pago. |
| `REJECTED` | Rechazada | Un paso de aprobacion fue rechazado. |
| `CANCELLED` | Cancelada | Borrador cancelado por el solicitante. |

## Flujo principal aprobado

```text
DRAFT
  -> UNIT_REVIEW
  -> FINANCE_REVIEW
  -> MANAGEMENT_REVIEW
  -> APPROVED
  -> PAID
```

## Transiciones actuales

| Origen | Accion | Destino | Implementacion |
|---|---|---|---|
| `DRAFT` | Enviar a aprobacion | `UNIT_REVIEW` | `PaymentRequest.submit_for_approval()` |
| `DRAFT` | Cancelar | `CANCELLED` | `PaymentRequestCancelView.post()` |
| `UNIT_REVIEW` | Aprobar responsable unidad | `FINANCE_REVIEW` | `PaymentApprovalStep.approve()` + `PaymentRequest.refresh_approval_status()` |
| `FINANCE_REVIEW` | Aprobar finanzas | `MANAGEMENT_REVIEW` | `PaymentApprovalStep.approve()` + `PaymentRequest.refresh_approval_status()` |
| `MANAGEMENT_REVIEW` | Aprobar gerencia | `APPROVED` | `PaymentApprovalStep.approve()` + `PaymentRequest.refresh_approval_status()` |
| Cualquier revision con paso pendiente | Rechazar | `REJECTED` | `PaymentApprovalStep.reject()` |
| `APPROVED` | Registrar pago | `PAID` | `PaymentExecution.save()` |

## Restricciones funcionales actuales

- Solo solicitudes en `DRAFT` pueden enviarse a aprobacion.
- Solo solicitudes en `DRAFT` pueden cancelarse por el flujo actual.
- Solo el rol requerido del paso puede aprobar o rechazar, salvo superusuario.
- El rechazo exige comentario.
- Cuentas por Pagar solo trabaja solicitudes `APPROVED` sin ejecucion de pago registrada.
- La ejecucion de pago solo puede crearse sobre solicitudes `APPROVED`.
- Al registrarse la ejecucion de pago, la solicitud pasa a `PAID`.

## Observaciones de gobierno

- `SUBMITTED` permanece en el contrato de estados, pero el flujo efectivo no lo usa como estado persistente intermedio.
- Esta decision debe mantenerse documentada hasta que negocio confirme si `SUBMITTED` debe eliminarse, usarse como estado visible o conservarse por compatibilidad historica.
- La seguridad operativa se apoya en permisos backend, no solo en visibilidad de menu.

## Criterios de aceptacion F2-P06

- Estados actuales documentados.
- Transiciones actuales documentadas.
- Restricciones funcionales documentadas.
- Deuda tecnica sobre `SUBMITTED` explicitada.
- Sin modelos nuevos.
- Sin migraciones nuevas.
- Validacion tecnica sin cambios pendientes de migracion.
MD

cat > "$MATRIX_FILE" <<'MD'
# Matriz de estados y transiciones - Fase 2

## Solicitud de pago

| Estado origen | Evento | Estado destino | Actor/Rol | Evidencia tecnica |
|---|---|---|---|---|
| `DRAFT` | Crear solicitud | `DRAFT` | Usuario autorizado para crear | `PaymentRequest.status default` |
| `DRAFT` | Enviar a aprobacion | `UNIT_REVIEW` | Solicitante / rol autorizado | `PaymentRequest.submit_for_approval()` |
| `DRAFT` | Cancelar | `CANCELLED` | Usuario con acceso a la solicitud | `PaymentRequestCancelView.post()` |
| `UNIT_REVIEW` | Aprobar paso 1 | `FINANCE_REVIEW` | `RESPONSABLE_UNIDAD` | `PaymentApprovalStep.approve()` |
| `FINANCE_REVIEW` | Aprobar paso 2 | `MANAGEMENT_REVIEW` | `FINANZAS` | `PaymentApprovalStep.approve()` |
| `MANAGEMENT_REVIEW` | Aprobar paso 3 | `APPROVED` | `GERENCIA_GENERAL` | `PaymentApprovalStep.approve()` |
| `UNIT_REVIEW` / `FINANCE_REVIEW` / `MANAGEMENT_REVIEW` | Rechazar paso pendiente | `REJECTED` | Rol requerido del paso | `PaymentApprovalStep.reject()` |
| `APPROVED` | Registrar ejecucion de pago | `PAID` | `CUENTAS_POR_PAGAR` | `PaymentExecution.save()` |

## Estados terminales operativos

| Estado | Terminal | Observacion |
|---|---:|---|
| `PAID` | Si | Cierre por ejecucion de pago. |
| `REJECTED` | Si | Cierre por rechazo de aprobacion. |
| `CANCELLED` | Si | Cierre por cancelacion desde borrador. |

## Estado pendiente de decision

| Estado | Situacion actual | Recomendacion |
|---|---|---|
| `SUBMITTED` | Declarado en enum/migraciones, no usado por el flujo principal actual. | Mantener documentado hasta decision funcional: usarlo, deprecarlo o removerlo en una fase posterior controlada. |

## Reglas de control

- No registrar pagos sobre solicitudes distintas de `APPROVED`.
- No aprobar ni rechazar pasos ya cerrados.
- No rechazar sin comentario.
- No exponer workbenches por rol solo desde UX; el backend debe seguir bloqueando accesos no autorizados.
MD

python3 - <<'PY'
from pathlib import Path

path = Path("docs/roadmap_fase2.md")
if not path.exists():
    raise SystemExit("ERROR: no existe docs/roadmap_fase2.md")

text = path.read_text(encoding="utf-8")
old_rows = """| 4 | F2-P04 | Tests integrados de permisos |
| 5 | F2-P05 | Estados y transiciones documentadas |
| 6 | F2-P06 | Validacion tecnica de transiciones |
| 7 | F2-P07 | Dashboard operativo mejorado por rol |"""
new_rows = """| 4 | F2-P04 | Context processor de navegacion por rol |
| 4B | F2-P04B | Visibilidad real de menu por rol en base.html |
| 5 | F2-P05 | Pruebas integradas de navegacion por rol / matriz UX-permisos |
| 6 | F2-P06 | Estados y transiciones documentadas |
| 7 | F2-P07 | Validacion tecnica de transiciones |
| 8 | F2-P08 | Dashboard operativo mejorado por rol |"""
if old_rows in text:
    text = text.replace(old_rows, new_rows)
else:
    print("WARN: no se encontro bloque exacto del roadmap para reemplazo automatico; se agregara nota de actualizacion.")
    marker = "## Siguiente accion\n"
    note = """\n## Actualizacion de secuencia real\n\n- F2-P04: Context processor de navegacion por rol.\n- F2-P04B: Visibilidad real de menu por rol en base.html.\n- F2-P05: Pruebas integradas de navegacion por rol / matriz UX-permisos.\n- F2-P06: Estados y transiciones documentadas.\n\n"""
    if "## Actualizacion de secuencia real" not in text:
        text = text.replace(marker, note + marker)

text = text.replace("Ejecutar F2-P02 con foco en:", "Ejecutar F2-P06 con foco en:")
text = text.replace("- Roles existentes.\n- Acciones permitidas por rol.\n- Visibilidad por empresa.\n- Visibilidad por estado de solicitud.\n- Rutas criticas.\n- Pruebas esperadas.", "- Estados actuales de solicitud.\n- Transiciones efectivas.\n- Actores por transicion.\n- Estados terminales.\n- Deuda tecnica sobre SUBMITTED.\n- Validacion sin migraciones.")

path.write_text(text, encoding="utf-8")
PY

echo "== Validando docs generados =="
grep -q 'F2-P06 - Estados y transiciones' "$DOC_FILE"
grep -q 'SUBMITTED' "$DOC_FILE"
grep -q 'Matriz de estados y transiciones' "$MATRIX_FILE"
grep -q 'F2-P06 | Estados y transiciones documentadas' "$ROADMAP_FILE"

echo "== Ruff global =="
docker compose exec backend ruff check .

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== Migraciones dry-run =="
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== Estado posterior =="
git status --short
