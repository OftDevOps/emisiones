# F2-P11 - Auditoria extendida

## Objetivo

Extender el workbench de auditoria transversal sin crear modelos nuevos ni migraciones, reforzando trazabilidad operativa para revision interna.

## Alcance implementado

- Se reutiliza `PaymentApprovalAction` como fuente de auditoria transversal.
- Se mantiene la ruta `payment_approvals:audit` en `/payment-approvals/audit/`.
- Se agregan filtros por usuario ejecutor y concepto de solicitud.
- Se agregan resumenes por accion y por empresa sobre el resultado filtrado.
- Se agrega columna de concepto de solicitud al historial transversal.
- Se mantiene alcance por empresa para usuarios no superuser.
- Se mantiene permiso centralizado `payment_approvals.view_audit`.

## Roles autorizados

- Administrador.
- Auditor.

## Decision tecnica

No se crean modelos ni migraciones. La auditoria extendida mejora la explotacion del registro transversal existente y evita introducir una segunda fuente de verdad.

## Validacion esperada

- `ruff check` sin errores.
- `manage.py check` sin errores.
- `makemigrations --check --dry-run` sin cambios.
- Pruebas focales de auditoria en verde.
- Suite principal en verde antes del commit.
