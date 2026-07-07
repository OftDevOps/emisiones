# Apps Emisiones - Plan rollback piloto interno

## Proposito

Definir la reversa operativa si el piloto interno presenta fallas criticas.

## Principios

- No improvisar rollback durante incidente.
- Mantener commit desplegado identificado.
- Mantener backup previo verificado.
- Separar rollback de aplicacion y rollback de datos.

## Disparadores de rollback

Aplicar rollback si ocurre cualquiera de estos casos:

- La aplicacion no permite login a usuarios piloto.
- La base de datos queda inconsistente.
- Hay error recurrente en creacion o aprobacion de solicitudes.
- Hay fuga de permisos entre roles.
- El sistema no inicia despues de despliegue.
- Una correccion rapida implica tocar modelo o migracion fuera del plan.

## Rollback de aplicacion

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

git log --oneline --max-count=10 --decorate

# Reemplazar COMMIT_ESTABLE por el ultimo commit aprobado antes del cambio problematico.
git checkout COMMIT_ESTABLE

docker compose build backend
docker compose up -d

docker compose exec backend python manage.py check
```

Nota: en piloto se puede usar checkout temporal. Para una reversa formal en rama, usar `git revert` sobre `develop` y publicar el commit de reversa.

## Rollback de datos

Ejecutar solo si hay impacto en informacion almacenada.

- Detener uso de la aplicacion.
- Confirmar backup objetivo.
- Restaurar backup segun `docs/backup_restore_postgresql_piloto.md`.
- Ejecutar smoke test.
- Registrar incidente.

## Comunicacion minima

Mensaje interno sugerido:

```text
Se detiene temporalmente el piloto de Apps Emisiones por validacion tecnica. El equipo TI ejecutara reversa controlada y notificara cuando el ambiente vuelva a estar disponible.
```

## Criterio de exito del rollback

- La aplicacion inicia.
- Login funciona.
- Base de datos responde.
- Smoke test minimo pasa.
- Usuarios informados.
- Incidente documentado.
