# F2-P10 - Exportacion operativa basica

## Objetivo

Agregar exportacion CSV basica sobre el reporte operativo de solicitudes de pago implementado en F2-P09.

## Alcance implementado

- Nueva ruta `payment_requests:report_export` en `/payment-requests/reports/basic/export/`.
- Nueva vista `PaymentRequestReportExportView`.
- Exportacion CSV con los mismos filtros de estado, empresa y rango de fecha del reporte en pantalla.
- Reutilizacion de `scoped_payment_request_queryset` y del permiso `payment_requests.view_report`.
- Boton `Exportar CSV` en el reporte operativo.
- Pruebas de login, permisos, alcance por empresa, filtros y respuesta CSV.

## Campos exportados

- Empresa.
- Beneficiario.
- Concepto.
- Estado.
- Fecha de vencimiento.
- Monto.
- Moneda.
- Solicitado por.

## Decision tecnica

No se crean modelos ni migraciones. La exportacion usa la misma consulta filtrada del reporte para evitar divergencia de reglas de negocio.
