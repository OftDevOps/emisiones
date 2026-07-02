# F1-P11 - Solicitudes de pago

## Objetivo

Crear la base operativa mínima de solicitudes de pago del Sistema de Rutas de Pago Oftalmi.

Este punto no implementa todavía aprobación, documentos soporte, workflow ni bandejas por rol. Su alcance es dejar el modelo principal estable para construir encima.

## App creada

```text
apps.payment_requests
```

## Modelo creado

```text
PaymentRequest
```

## Campos principales

```text
company
beneficiary
requested_by
amount
currency
concept
description
due_date
status
created_at
updated_at
```

## Estados iniciales

```text
DRAFT      Borrador
SUBMITTED  Enviada
CANCELLED  Cancelada
```

## Reglas implementadas

```text
PAY-001 Toda solicitud debe pertenecer a una empresa.
PAY-002 Toda solicitud debe tener beneficiario.
PAY-003 Toda solicitud debe tener usuario solicitante.
PAY-004 El monto debe ser mayor que cero.
PAY-005 Toda solicitud nace en estado DRAFT.
PAY-006 El beneficiario debe pertenecer a la misma empresa de la solicitud.
```

## Validaciones esperadas

```bash
python manage.py check
python manage.py makemigrations --check --dry-run
python manage.py migrate
python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests
```

## Resultado esperado

```text
System check identified no issues
No changes detected
Applying payment_requests.0001_initial... OK
Tests OK
```
