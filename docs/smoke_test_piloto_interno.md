# Apps Emisiones - Smoke test piloto interno

## Proposito

Validar rapidamente que el ambiente piloto esta operativo despues del despliegue o rollback.

## Smoke test tecnico

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

docker compose ps
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py migrate --plan
```

Resultado esperado:

- Contenedores arriba.
- `manage.py check` sin errores.
- Sin migraciones pendientes no controladas.
- Plan de migraciones revisado.

## Smoke test web

URLs minimas:

- `http://localhost:8001/login/`
- Dashboard o home posterior al login.
- Vista de solicitudes de pago.
- Vista de aprobaciones si el rol aplica.
- Reporte operativo si el rol aplica.
- Auditoria si el rol aplica.

## Smoke test funcional minimo

- Login con usuario administrador.
- Login con usuario solicitante.
- Login con usuario aprobador.
- Login con usuario cuentas por pagar.
- Crear solicitud demo.
- Adjuntar documento demo.
- Enviar solicitud a aprobacion.
- Aprobar o rechazar segun rol.
- Registrar pago demo si aplica.
- Consultar dashboard.
- Consultar reporte.
- Exportar reporte.
- Consultar auditoria.

## Smoke test de permisos

- Usuario sin permiso no debe acceder a cuentas por pagar.
- Usuario sin permiso no debe acceder a dashboard operativo.
- Usuario sin permiso no debe exportar reporte operativo.
- Usuario sin permiso no debe ejecutar aprobacion fuera de su rol.

## Criterio de aprobacion

El smoke test se considera aprobado si:

- No hay error 500.
- Los errores 403 esperados ocurren donde aplica.
- Los flujos basicos completan.
- La auditoria registra acciones criticas.
- No hay migraciones pendientes inesperadas.
