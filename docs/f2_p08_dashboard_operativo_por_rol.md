# F2-P08 - Dashboard operativo mejorado por rol

## Objetivo

Mejorar el dashboard operativo de solicitudes para que los indicadores y accesos visibles respondan al rol del usuario y a la matriz UX-permisos de Fase 2.

## Alcance implementado

- Se agrego perfil operativo visible: rol y alcance empresarial.
- Los accesos operativos del dashboard ahora se muestran segun `role_nav`.
- El panel de Cuentas por Pagar solo aparece para roles con permiso visual/operativo.
- El panel de Auditoria solo aparece para roles con permiso de auditoria.
- Se agregaron pruebas especificas para Solicitante, Finanzas y Auditor.
- Se alineo el acceso backend de Cuentas por Pagar con `PERM_VIEW_ACCOUNTS_PAYABLE`.

## Decision tecnica

El dashboard no sustituye permisos backend. La plantilla solo mejora la experiencia y reduce enlaces rotos. Las vistas siguen siendo la fuente de autorizacion real.

## Hallazgo corregido

La matriz de permisos permitia `payment_requests.view_accounts_payable` a roles definidos en `PERM_VIEW_ACCOUNTS_PAYABLE`, pero la vista de Cuentas por Pagar estaba acoplada a `CUENTAS_POR_PAGAR`.

F2-P08 alinea esa vista con la matriz centralizada.
