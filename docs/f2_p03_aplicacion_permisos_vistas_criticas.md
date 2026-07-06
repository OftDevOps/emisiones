# F2-P03 - Aplicacion efectiva de permisos por rol en vistas criticas

## Objetivo

Aplicar de forma efectiva la matriz de acceso operativa de Fase 2 sobre vistas criticas del MVP de Apps Emisiones, reduciendo reglas dispersas y evitando autorizaciones implicitas por accidente.

## Alcance

Este punto introduce una politica centralizada de permisos operativos por rol y pruebas de contrato para validar que las rutas criticas respetan el modelo esperado.

Vistas y capacidades cubiertas:

- Dashboard/listado de solicitudes de pago.
- Creacion y envio de solicitudes.
- Bandeja de aprobaciones pendientes.
- Ejecucion de acciones de aprobacion.
- Workbench de auditoria.
- Cuentas por pagar.
- Registro de ejecucion de pago.

## Cambios tecnicos

Archivos incorporados:

```text
backend/apps/accounts/role_permissions.py
backend/apps/accounts/mixins.py
backend/apps/accounts/tests/test_role_permissions.py
docs/f2_p03_aplicacion_permisos_vistas_criticas.md
```

Archivos potencialmente ajustados por el script:

```text
backend/apps/payment_requests/views.py
backend/apps/payment_approvals/views.py
backend/apps/payment_execution/views.py
```

## Politica operativa base

| Permiso | Roles autorizados |
|---|---|
| Ver dashboard/listado de solicitudes | ADMINISTRADOR, SOLICITANTE, RESPONSABLE_UNIDAD, FINANZAS, CUENTAS_POR_PAGAR, AUDITOR |
| Crear/enviar solicitudes | ADMINISTRADOR, SOLICITANTE, RESPONSABLE_UNIDAD, FINANZAS |
| Ver aprobaciones pendientes | ADMINISTRADOR, RESPONSABLE_UNIDAD, FINANZAS |
| Ejecutar aprobacion/rechazo | ADMINISTRADOR, RESPONSABLE_UNIDAD, FINANZAS |
| Ver auditoria | ADMINISTRADOR, AUDITOR |
| Ver Cuentas por Pagar | ADMINISTRADOR, CUENTAS_POR_PAGAR, FINANZAS |
| Registrar ejecucion de pago | ADMINISTRADOR, CUENTAS_POR_PAGAR |

## Criterios de aceptacion

- La matriz de permisos queda centralizada en `apps.accounts.role_permissions`.
- Las vistas criticas consumen la politica centralizada donde aplique.
- Los permisos desconocidos fallan cerrado.
- No se crean modelos.
- No se crean migraciones.
- La suite completa mantiene verde.

## Validacion esperada

```bash
nordvpn disconnect
sleep 3

git status
git log --oneline --max-count=5

docker compose exec backend ruff check .
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests apps.payment_documents apps.payment_approvals apps.payment_execution

nordvpn connect United_States
nordvpn status
```

## Riesgo controlado

El endurecimiento se mantiene en permisos operativos de aplicacion. No reemplaza todavia permisos nativos Django, grupos, ni asignaciones administrativas avanzadas. Ese salto debe tratarse como un punto separado si el negocio lo requiere.
