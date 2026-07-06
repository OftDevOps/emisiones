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
