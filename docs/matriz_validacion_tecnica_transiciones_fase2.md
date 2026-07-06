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
