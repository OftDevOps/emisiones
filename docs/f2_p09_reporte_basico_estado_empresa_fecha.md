# F2-P09 - Reporte basico por estado, empresa y fecha

## Objetivo

Incorporar un reporte operativo basico de solicitudes de pago filtrable por estado, empresa y fecha de vencimiento.

## Alcance implementado

- Nueva vista `PaymentRequestReportView`.
- Nueva ruta `payment_requests:report` en `/payment-requests/reports/basic/`.
- Filtros por estado, empresa disponible y rango de fecha.
- Resumen por empresa y estado.
- Detalle operativo limitado al alcance empresarial del usuario.
- Permiso centralizado `payment_requests.view_report`.
- Visibilidad UX desde `role_nav.can_view_payment_request_report`.
- Pruebas focales de acceso, autorizacion, alcance por empresa y filtros.

## Roles autorizados

- Administrador.
- Finanzas.
- Cuentas por Pagar.
- Auditor.

## Decision tecnica

No se crean modelos ni migraciones. El reporte reutiliza `PaymentRequest`, `scoped_payment_request_queryset` y la matriz de permisos centralizada.

## Relacion con F2-P10

F2-P09 deja la consulta operativa en pantalla. F2-P10 debe agregar exportacion operativa basica sobre este mismo criterio de filtros, evitando duplicar reglas de negocio.
