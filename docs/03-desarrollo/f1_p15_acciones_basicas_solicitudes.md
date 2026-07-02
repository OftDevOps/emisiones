# F1-P15 Acciones básicas sobre solicitudes

## Objetivo

Agregar acciones operativas mínimas sobre una solicitud de pago desde la capa web.

## Alcance implementado

- Acción `Enviar a aprobación` por POST.
- Acción `Cancelar solicitud` por POST.
- Visualización de ruta de aprobación en el detalle.
- Visualización de historial de acciones en el detalle.
- Protección por login.
- Filtro por empresa principal del usuario.
- Pruebas transversales de acciones.

## Endpoints

```text
POST /payment-requests/<id>/submit/
POST /payment-requests/<id>/cancel/
```

## Reglas

```text
ACT-001 Solo usuarios autenticados pueden ejecutar acciones.
ACT-002 Un usuario no puede accionar solicitudes de otra empresa.
ACT-003 Solo solicitudes DRAFT pueden enviarse a aprobación.
ACT-004 Enviar a aprobación genera ruta base de aprobación.
ACT-005 Solo solicitudes DRAFT pueden cancelarse desde esta acción básica.
ACT-006 La cancelación registra acción de auditoría.
ACT-007 Las acciones se ejecutan por POST, no por GET.
```

## Fuera de alcance

```text
Notificaciones.
Carga de documentos desde UI.
Aprobación/rechazo desde UI.
Permisos finos por rol en vistas.
Dashboard ejecutivo.
```

## Validación esperada

```text
ruff check . OK
python manage.py check OK
python manage.py makemigrations --check --dry-run No changes detected
python manage.py migrate No migrations to apply
python manage.py test ... OK
```
