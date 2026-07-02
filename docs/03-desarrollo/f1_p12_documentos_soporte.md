# F1-P12 Documentos soporte

## Objetivo

Agregar documentos soporte a las solicitudes de pago sin adelantar todavía el flujo formal de aprobación.

## App creada

```text
payment_documents
```

## Modelo principal

```text
PaymentRequestDocument
```

## Campos clave

```text
payment_request
 document_type
 file
 original_filename
 uploaded_by
 notes
 is_required
 is_active
 created_at
 updated_at
```

## Tipos de documento

```text
INVOICE          Factura
PURCHASE_ORDER   Orden de compra
DELIVERY_NOTE    Nota de entrega
TAX_DOCUMENT     Documento fiscal
SUPPORT          Soporte general
OTHER            Otro
```

## Reglas

```text
DOC-001 Todo documento debe pertenecer a una solicitud de pago.
DOC-002 Todo documento debe tener usuario que lo cargó.
DOC-003 El archivo es obligatorio.
DOC-004 No se elimina físicamente: se desactiva con is_active=False.
DOC-005 La ruta de carga queda organizada por solicitud.
```

## Validaciones

```bash
python manage.py check
python manage.py makemigrations --check --dry-run
python manage.py migrate
python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests apps.payment_documents
```
