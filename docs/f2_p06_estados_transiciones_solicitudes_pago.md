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
