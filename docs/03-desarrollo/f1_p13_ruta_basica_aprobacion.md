# F1-P13 Ruta básica de aprobación

## Objetivo

Agregar una ruta básica y auditable para aprobar solicitudes de pago.

## Alcance implementado

- App `payment_approvals`.
- Modelo `PaymentApprovalStep`.
- Modelo `PaymentApprovalAction`.
- Estados extendidos en `PaymentRequest`.
- Método `submit_for_approval`.
- Método `refresh_approval_status`.
- Admin básico.
- Pruebas de flujo mínimo.

## Flujo base

```text
DRAFT
  -> UNIT_REVIEW
  -> FINANCE_REVIEW
  -> MANAGEMENT_REVIEW
  -> APPROVED
```

Rechazo:

```text
Cualquier paso pendiente rechazado -> REJECTED
```

## Roles de la ruta inicial

```text
1 RESPONSABLE_UNIDAD
2 FINANZAS
3 GERENCIA_GENERAL
```

## Reglas

```text
APP-001 Solo una solicitud en DRAFT puede enviarse a aprobación.
APP-002 El envío genera los pasos base de aprobación.
APP-003 Cada aprobación registra usuario, rol, fecha y comentario opcional.
APP-004 Todo rechazo exige comentario.
APP-005 Un usuario no puede aprobar un paso si no tiene el rol requerido.
APP-006 Si todos los pasos están aprobados, la solicitud pasa a APPROVED.
APP-007 Si cualquier paso es rechazado, la solicitud pasa a REJECTED.
```
