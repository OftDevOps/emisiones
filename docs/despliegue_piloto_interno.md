# Apps Emisiones - Bloque de despliegue piloto interno

## Estado

Documento operativo posterior al cierre tecnico de Fase 2.

La Fase 2 queda como baseline funcional/documental para iniciar piloto interno. Este bloque no agrega funcionalidad; prepara operacion, seguridad minima, respaldo, rollback, smoke test y monitoreo.

## Objetivo

Habilitar un piloto interno controlado de Apps Emisiones con bajo riesgo operativo y trazabilidad suficiente para decidir si el sistema puede pasar a despliegue controlado.

## Documentos del bloque

| Documento | Uso |
| --- | --- |
| `docs/checklist_predespliegue_piloto_interno.md` | Validar readiness antes de abrir piloto |
| `docs/variables_entorno_piloto_interno.md` | Guiar configuracion `.env` sin exponer secretos |
| `docs/backup_restore_postgresql_piloto.md` | Respaldo y restauracion PostgreSQL |
| `docs/plan_rollback_piloto_interno.md` | Reversa controlada ante fallo critico |
| `docs/smoke_test_piloto_interno.md` | Validacion rapida post despliegue |
| `docs/monitoreo_basico_piloto_interno.md` | Observabilidad minima durante piloto |
| `docs/guia_operacion_piloto_interno.md` | Operacion diaria y control de cambios |

## Secuencia recomendada

1. Confirmar commit base desplegable.
2. Preparar `.env` del piloto.
3. Levantar ambiente.
4. Ejecutar migraciones controladas.
5. Crear usuarios y roles piloto.
6. Cargar datos demo/UAT.
7. Ejecutar backup previo.
8. Ejecutar smoke test.
9. Abrir piloto con usuarios internos.
10. Registrar incidentes y decisiones.
11. Cerrar piloto con evidencia.

## Validacion tecnica completa recomendada

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

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

## Criterio de avance

El proyecto puede pasar de documentacion de piloto a ejecucion de piloto cuando:

- `develop` esta limpio y publicado.
- Variables de entorno estan definidas.
- Backup previo existe.
- Rollback esta documentado.
- Smoke test inicial pasa.
- Usuarios piloto y roles estan listos.
- Responsable operativo acepta abrir la ventana piloto.

## Restricciones

- No introducir funcionalidad nueva en este bloque.
- No crear modelos.
- No crear migraciones.
- No modificar flujos de negocio.
- No omitir backup previo.
- No abrir piloto sin rollback definido.
