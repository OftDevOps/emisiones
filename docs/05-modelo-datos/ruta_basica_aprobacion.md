# Modelo de datos - Ruta básica de aprobación

## PaymentApprovalStep

Representa un paso requerido dentro de la ruta de aprobación de una solicitud.

Campos principales:

```text
payment_request
sequence
required_role
status
assigned_to
acted_by
acted_at
comment
created_at
updated_at
```

## PaymentApprovalAction

Representa la bitácora de acciones ejecutadas sobre la ruta.

Campos principales:

```text
payment_request
step
action
performed_by
role
comment
created_at
```

## Estados agregados a PaymentRequest

```text
DRAFT
SUBMITTED
UNIT_REVIEW
FINANCE_REVIEW
MANAGEMENT_REVIEW
APPROVED
REJECTED
CANCELLED
```
