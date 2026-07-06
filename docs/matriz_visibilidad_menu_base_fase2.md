# Matriz de visibilidad de menu - Fase 2

## Fuente

La visibilidad depende de `role_nav`, inyectado por:

```python
apps.accounts.context_processors.role_navigation
```

## Variables usadas

| Variable | Enlace |
|---|---|
| `role_nav.can_view_payment_dashboard` | Solicitudes |
| `role_nav.can_view_payment_requests` | Listado |
| `role_nav.can_create_payment_request` | Nueva solicitud |
| `role_nav.can_view_pending_approvals` | Aprobaciones |
| `role_nav.can_view_accounts_payable` | Cuentas por pagar |
| `role_nav.can_view_audit_workbench` | Auditoria |

## Regla corporativa

El menu solo refleja accesos permitidos. La autorizacion real sigue estando en las vistas Django y en la matriz de permisos backend.
