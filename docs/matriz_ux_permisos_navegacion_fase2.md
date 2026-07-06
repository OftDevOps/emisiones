# Matriz UX-permisos de navegacion - Fase 2

## Principio de control

La navegacion por rol es una capa UX. No reemplaza autorizacion backend.

## Mapeo menu-permiso-ruta

| Menu | Ruta Django | Permiso backend |
|---|---|---|
| Solicitudes | `payment_requests:dashboard` | `PERM_VIEW_PAYMENT_REQUEST_DASHBOARD` |
| Listado | `payment_requests:list` | `PERM_VIEW_PAYMENT_REQUESTS` |
| Nueva solicitud | `payment_requests:create` | `PERM_CREATE_PAYMENT_REQUEST` |
| Aprobaciones | `payment_approvals:pending` | `PERM_VIEW_PENDING_APPROVALS` |
| Cuentas por pagar | `payment_requests:accounts_payable` | `PERM_VIEW_ACCOUNTS_PAYABLE` |
| Auditoria | `payment_approvals:audit` | `PERM_VIEW_AUDIT_WORKBENCH` |

## Validacion automatizada

La prueba integrada recorre todos los valores de `UserRole` y compara:

```python
user_has_permission(user, permission)
```

contra el contenido real renderizado dentro de:

```html
<nav class="oftalmi-nav">
```

## Regla corporativa

Si un usuario no tiene permiso, el menu no debe exponer el enlace. Si manipula la URL manualmente, la vista debe mantener el bloqueo por permisos backend.
