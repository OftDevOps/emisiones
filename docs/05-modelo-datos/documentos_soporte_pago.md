# Modelo de datos - Documentos soporte de pago

## Entidad

```text
PaymentRequestDocument
```

## Relación principal

```text
PaymentRequest 1 ─── N PaymentRequestDocument
CustomUser      1 ─── N PaymentRequestDocument(uploaded_by)
```

## Estrategia de eliminación

No se elimina físicamente el documento desde la lógica funcional. Se usa:

```text
is_active = False
```

Esto permite trazabilidad, auditoría y control posterior.

## Ruta de archivo

```text
payment_requests/<payment_request_id>/documents/document.<ext>
```

## Notas de diseño

Este módulo queda desacoplado de la aprobación. La ruta formal de aprobación se implementará en el siguiente bloque funcional.
