# F2-P05 - Pruebas integradas de navegacion por rol / matriz UX-permisos

## Objetivo

Validar que la navegacion visible en `base.html` refleje la matriz de permisos backend para todos los roles definidos en `UserRole`.

## Alcance

- Probar la visibilidad integrada del menu por rol.
- Verificar que cada enlace visible tenga una ruta resoluble.
- Confirmar que ocultar enlaces no sustituye los controles backend.
- Documentar la matriz UX-permisos aplicada a navegacion.

## Criterio tecnico

La fuente de verdad sigue siendo la matriz de permisos backend expuesta mediante:

```python
apps.accounts.role_permissions.user_has_permission
```

La capa visual usa:

```python
role_nav
```

inyectado por:

```python
apps.accounts.context_processors.role_navigation
```

## Pruebas agregadas

Archivo:

```text
backend/apps/accounts/tests/test_role_navigation_integrated_matrix.py
```

Casos cubiertos:

1. La navegacion visible coincide con permisos backend para todos los roles.
2. Los enlaces ocultos siguen protegidos por permisos backend si se accede por URL directa.
3. Las rutas usadas por el menu son resolubles por Django.

## Fuera de alcance

- No se modifican modelos.
- No se crean migraciones.
- No se cambian permisos backend.
- No se cambian reglas funcionales de aprobacion, pagos o auditoria.

## Ajuste derivado por prueba integrada

Durante F2-P05 se detecto que la vista `payment_approvals:audit` estaba visible/alcanzable para un rol sin permiso operativo de auditoria.

La matriz backend define `payment_approvals.view_audit` solo para:

- ADMINISTRADOR
- AUDITOR

Se corrigio `CrossActionAuditWorkbenchView` para aplicar `_require_operational_permission` en `dispatch`, manteniendo backend como fuente autoritativa de control de acceso.
