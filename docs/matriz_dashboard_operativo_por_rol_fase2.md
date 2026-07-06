# Matriz de dashboard operativo por rol - Fase 2

## Regla base

El dashboard usa `role_nav` para visibilidad UX y permisos backend para autorizacion efectiva.

## Paneles y accesos

| Elemento | Variable / permiso | Resultado |
|---|---|---|
| Perfil operativo | usuario autenticado | Muestra rol y alcance |
| Pendientes por aprobar | `role_nav.can_view_pending_approvals` | Enlace a bandeja de aprobaciones |
| Cuentas por Pagar | `role_nav.can_view_accounts_payable` | Enlace y panel de aprobadas pendientes de pago |
| Auditoria operativa | `role_nav.can_view_audit_workbench` | Enlace y total de acciones auditables |
| Ultimas solicitudes | alcance por empresa | Listado acotado al usuario |

## Criterio de control

- Solicitante: sin accesos operativos adicionales.
- Finanzas: aprobaciones y Cuentas por Pagar, segun matriz vigente.
- Auditor: auditoria operativa.
- Cuentas por Pagar: panel operativo de solicitudes aprobadas pendientes.
