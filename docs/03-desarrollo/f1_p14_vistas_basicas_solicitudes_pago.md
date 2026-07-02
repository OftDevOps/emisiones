# F1-P14 - Vistas básicas de solicitudes de pago

## Objetivo

Agregar una primera capa web para operar solicitudes de pago sin implementar todavía aprobación en pantalla, edición avanzada, adjuntos desde UI o notificaciones.

## Alcance implementado

- Listado autenticado de solicitudes de pago.
- Detalle autenticado de solicitud de pago.
- Creación básica de solicitud de pago.
- Filtro por empresa principal del usuario.
- Protección por login.
- Pruebas transversales de acceso, listado, detalle y creación.

## URLs

```text
/payment-requests/
/payment-requests/new/
/payment-requests/<id>/
```

## Reglas

```text
VIEW-001 El listado requiere autenticación.
VIEW-002 El detalle requiere autenticación.
VIEW-003 La creación requiere autenticación.
VIEW-004 Un usuario no superusuario solo ve solicitudes de su empresa principal.
VIEW-005 Al crear una solicitud, requested_by se asigna automáticamente al usuario autenticado.
VIEW-006 El beneficiario debe pertenecer a la empresa seleccionada.
```

## Fuera de alcance

- Edición de solicitudes.
- Envío a aprobación desde UI.
- Carga de documentos desde UI.
- Notificaciones.
- Permisos granulares por rol.
