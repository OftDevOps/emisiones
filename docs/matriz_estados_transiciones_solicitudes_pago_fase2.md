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
