# F2-P04B - Visibilidad real de menu por rol en base.html

## Objetivo

Aplicar visibilidad real de navegacion por rol en `backend/templates/base.html`, usando el context processor creado en F2-P04.

## Implementacion

La plantilla base usa el objeto:

```python
role_nav
```

Este objeto es inyectado por:

```python
apps.accounts.context_processors.role_navigation
```

## Alcance

- Mostrar u ocultar enlaces del menu segun permisos efectivos por rol.
- Mantener los permisos backend como fuente real de seguridad.
- Reducir exposicion visual de opciones que terminan en `403`.
- Agregar pruebas de renderizado de menu por rol.

## Enlaces condicionados

- Solicitudes
- Listado
- Nueva solicitud
- Aprobaciones
- Cuentas por pagar
- Auditoria

## Criterio de seguridad

La visibilidad del menu es UX. No sustituye controles backend.

Si un usuario manipula manualmente una URL protegida, la vista debe seguir devolviendo `403` cuando no tenga permiso.
