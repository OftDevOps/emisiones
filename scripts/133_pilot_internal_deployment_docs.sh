#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== Bloque piloto interno: documentacion operativa =="
echo "== Guardas de seguridad =="

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "develop" ]; then
  echo "ERROR: este bloque debe aplicarse sobre develop. Rama actual: $current_branch" >&2
  exit 1
fi

unexpected_status="$(git status --porcelain | grep -Ev '^(\?\? scripts/133_pilot_internal_deployment_docs\.sh|\?\? scripts/134_finalize_pilot_internal_deployment_docs\.sh)$' || true)"
if [ -n "$unexpected_status" ]; then
  echo "ERROR: el arbol de trabajo tiene cambios no esperados. Revise antes de aplicar el bloque piloto interno:" >&2
  printf '%s\n' "$unexpected_status" >&2
  exit 1
fi

echo "== Estado inicial =="
git status --short
git log --oneline --max-count=5 --decorate

mkdir -p docs

echo "== Creando checklist predespliegue =="
cat > docs/checklist_predespliegue_piloto_interno.md <<'EOF'
# Apps Emisiones - Checklist predespliegue piloto interno

## Proposito

Checklist operativo para preparar el despliegue piloto interno de Apps Emisiones despues del cierre tecnico de Fase 2.

Este documento no introduce funcionalidad nueva. Su objetivo es reducir riesgo operativo antes de exponer el sistema a usuarios internos.

## Alcance del piloto

El piloto interno cubre:

- Login de usuarios internos.
- Navegacion por rol.
- Solicitudes de pago.
- Documentos asociados.
- Flujo de aprobaciones.
- Registro de ejecucion de pagos.
- Dashboard operativo.
- Reportes y exportacion basica.
- Auditoria extendida.
- Paquete UAT de validacion interna.

Fuera de alcance:

- Nuevos modelos de datos.
- Nuevas migraciones.
- Cambios funcionales.
- Integraciones externas.
- Automatizacion bancaria.
- Firma digital.
- Alta disponibilidad.

## Precondiciones tecnicas

| Item | Estado esperado | Evidencia |
| --- | --- | --- |
| Rama base | `develop` actualizada | `git log --oneline --max-count=5` |
| Validacion tecnica | OK | `ruff`, `check`, migraciones, tests |
| Migraciones | Sin pendientes | `makemigrations --check --dry-run` |
| Base de datos | PostgreSQL disponible | `docker compose ps` |
| Variables de entorno | Revisadas | `.env` fuera de Git |
| Superusuario | Disponible | Usuario admin validado |
| Usuarios piloto | Creados | Lista interna UAT |
| Roles | Asignados | Matriz de usuarios/roles |
| Backup previo | Ejecutado | Archivo `.dump` o `.sql` |
| Rollback | Documentado | Plan de reversa aprobado |

## Checklist de ambiente

- [ ] Confirmar servidor o equipo destino del piloto.
- [ ] Confirmar puerto publicado.
- [ ] Confirmar URL interna.
- [ ] Confirmar conectividad desde puestos piloto.
- [ ] Confirmar acceso al repositorio Git.
- [ ] Confirmar acceso a Docker y Docker Compose.
- [ ] Confirmar espacio disponible en disco.
- [ ] Confirmar politica de respaldo.
- [ ] Confirmar ventana de despliegue.
- [ ] Confirmar responsables de soporte durante piloto.

## Checklist de seguridad minima

- [ ] `DEBUG=False` en ambiente piloto.
- [ ] `SECRET_KEY` no versionada.
- [ ] `ALLOWED_HOSTS` restringido a host/IP del piloto.
- [ ] Credenciales de base de datos fuera de Git.
- [ ] Usuario admin con clave robusta.
- [ ] Usuarios reales sin claves compartidas.
- [ ] Roles revisados antes de UAT.
- [ ] No exponer puerto de base de datos fuera del host si no es necesario.
- [ ] Backups protegidos fuera del directorio publico.

## Checklist de datos demo/UAT

- [ ] Empresas base disponibles.
- [ ] Beneficiarios de prueba disponibles.
- [ ] Usuarios piloto por rol disponibles.
- [ ] Solicitudes de pago demo creadas.
- [ ] Documentos de prueba adjuntos.
- [ ] Casos aprobados, rechazados y pendientes preparados.
- [ ] Casos de auditoria verificables preparados.
- [ ] Datos sensibles reales minimizados o anonimizados.

## Checklist de validacion funcional

- [ ] Login exitoso.
- [ ] Logout exitoso.
- [ ] Acceso por rol correcto.
- [ ] Usuario sin permiso recibe 403 donde aplique.
- [ ] Creacion de solicitud de pago.
- [ ] Carga de documentos.
- [ ] Envio a aprobacion.
- [ ] Aprobacion por rol autorizado.
- [ ] Rechazo por rol autorizado.
- [ ] Registro de pago por rol autorizado.
- [ ] Dashboard visible para roles permitidos.
- [ ] Reporte operativo filtra por estado, empresa y fecha.
- [ ] Exportacion basica genera archivo.
- [ ] Auditoria registra acciones criticas.

## Criterio de salida del predespliegue

El piloto puede arrancar si:

- La validacion tecnica completa esta en OK.
- El backup previo existe y fue verificado.
- El rollback esta documentado.
- Los usuarios piloto estan definidos.
- Los responsables de soporte conocen el flujo.
- El checklist funcional minimo fue revisado.
EOF

echo "== Creando variables de entorno piloto =="
cat > docs/variables_entorno_piloto_interno.md <<'EOF'
# Apps Emisiones - Variables de entorno para piloto interno

## Proposito

Definir las variables minimas esperadas para ejecutar Apps Emisiones en un ambiente de piloto interno.

Este documento es una guia. No debe contener secretos reales.

## Variables Django

```env
DJANGO_ENV=pilot
DEBUG=False
SECRET_KEY=change-me-with-secure-value
ALLOWED_HOSTS=localhost,127.0.0.1,IP_O_HOST_INTERNO
CSRF_TRUSTED_ORIGINS=http://IP_O_HOST_INTERNO:8001
```

Notas:

- `SECRET_KEY` debe generarse de forma segura y no debe subirse a Git.
- `DEBUG=False` es obligatorio para piloto.
- `ALLOWED_HOSTS` debe restringirse al host real del piloto.
- Si se usa HTTPS, actualizar `CSRF_TRUSTED_ORIGINS` a `https://...`.

## Variables de base de datos

```env
POSTGRES_DB=emisiones
POSTGRES_USER=emisiones_user
POSTGRES_PASSWORD=change-me
POSTGRES_HOST=db
POSTGRES_PORT=5432
```

Notas:

- No usar claves triviales.
- No reutilizar credenciales de desarrollo.
- Documentar quien custodia las credenciales.

## Variables de aplicacion

```env
APP_NAME=Apps Emisiones
APP_PORT=8001
APP_TIMEZONE=America/Caracas
```

Notas:

- El puerto local historico del proyecto es `8001`.
- La URL de login esperada es `/login/`.

## Variables de correo opcionales

```env
EMAIL_HOST=
EMAIL_PORT=587
EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=
EMAIL_USE_TLS=True
DEFAULT_FROM_EMAIL=
```

Notas:

- Mantener vacias si el piloto no usa notificaciones por correo.
- No bloquear el piloto por correo si no es parte del alcance UAT.

## Politica de archivo `.env`

- Debe existir en el servidor o equipo del piloto.
- No debe versionarse.
- Debe tener permisos restrictivos.
- Debe respaldarse de forma segura si se requiere reconstruir el ambiente.
- Cambios de `.env` deben quedar registrados en bitacora operativa.
EOF

echo "== Creando plan backup y restore =="
cat > docs/backup_restore_postgresql_piloto.md <<'EOF'
# Apps Emisiones - Backup y restore PostgreSQL para piloto interno

## Proposito

Definir el procedimiento minimo de respaldo y restauracion de PostgreSQL antes y durante el piloto interno.

## Backup previo al piloto

Ejemplo con Docker Compose:

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

mkdir -p backups

docker compose exec -T db pg_dump \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  --format=custom \
  --file=/tmp/emisiones_pre_piloto.dump

docker compose cp db:/tmp/emisiones_pre_piloto.dump backups/emisiones_pre_piloto_$(date +%Y%m%d_%H%M%S).dump

ls -lh backups/
```

Si las variables no estan disponibles dentro del contenedor, reemplazar por los valores reales definidos en `.env`.

## Backup SQL plano alternativo

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

mkdir -p backups

docker compose exec -T db pg_dump \
  -U emisiones_user \
  -d emisiones \
  > backups/emisiones_pre_piloto_$(date +%Y%m%d_%H%M%S).sql

ls -lh backups/
```

## Verificacion minima del backup

- Confirmar que el archivo existe.
- Confirmar que el archivo pesa mas que cero bytes.
- Registrar fecha y hora.
- Registrar commit desplegado.
- Registrar responsable.

## Restore desde formato custom

Procedimiento destructivo. Debe ejecutarse solo con autorizacion.

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

BACKUP_FILE="backups/emisiones_pre_piloto_YYYYMMDD_HHMMSS.dump"

docker compose cp "$BACKUP_FILE" db:/tmp/restore.dump

docker compose exec -T db dropdb -U emisiones_user emisiones --if-exists
docker compose exec -T db createdb -U emisiones_user emisiones
docker compose exec -T db pg_restore -U emisiones_user -d emisiones --clean --if-exists /tmp/restore.dump
```

## Restore desde SQL plano

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

BACKUP_FILE="backups/emisiones_pre_piloto_YYYYMMDD_HHMMSS.sql"

docker compose exec -T db dropdb -U emisiones_user emisiones --if-exists
docker compose exec -T db createdb -U emisiones_user emisiones
cat "$BACKUP_FILE" | docker compose exec -T db psql -U emisiones_user -d emisiones
```

## Politica minima durante piloto

- Backup antes de iniciar piloto.
- Backup al cierre de cada jornada UAT.
- Backup antes de cualquier ajuste correctivo.
- No borrar backups hasta cierre formal del piloto.
- Copiar backup critico fuera del host si el piloto dura mas de una jornada.
EOF

echo "== Creando plan rollback =="
cat > docs/plan_rollback_piloto_interno.md <<'EOF'
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
EOF

echo "== Creando smoke test piloto =="
cat > docs/smoke_test_piloto_interno.md <<'EOF'
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
EOF

echo "== Creando monitoreo basico =="
cat > docs/monitoreo_basico_piloto_interno.md <<'EOF'
# Apps Emisiones - Monitoreo basico piloto interno

## Proposito

Definir observabilidad minima para operar el piloto interno sin sobredimensionar la plataforma.

## Indicadores tecnicos

- Estado de contenedores.
- Uso de disco.
- Uso de memoria.
- Logs recientes del backend.
- Logs recientes de base de datos.
- Errores HTTP 500.
- Eventos 403 esperados por permisos.
- Tiempo de respuesta percibido por usuarios piloto.

## Comandos base

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

docker compose ps
docker compose logs --tail=100 backend
docker compose logs --tail=100 db
df -h
free -h
```

## Revision de errores

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

docker compose logs backend | grep -i "error\|exception\|traceback" | tail -50
```

Nota: algunos `PermissionDenied` pueden ser esperados durante pruebas de permisos. El foco operativo son errores 500, excepciones no controladas y fallas recurrentes.

## Frecuencia sugerida durante piloto

- Inicio de jornada: revisar contenedores, espacio y logs.
- Durante UAT: revisar logs despues de pruebas criticas.
- Cierre de jornada: generar backup y registrar hallazgos.

## Registro minimo de incidentes

| Fecha | Usuario | Rol | Accion | Error | Evidencia | Decision |
| --- | --- | --- | --- | --- | --- | --- |
| YYYY-MM-DD | Nombre | Rol | Accion ejecutada | Error observado | Captura/log | Pendiente/Corregido/Descartado |

## Criterio de escalamiento

Escalar si:

- Hay error 500 reproducible.
- Un usuario accede a una vista no autorizada.
- Una solicitud cambia a estado incorrecto.
- La exportacion falla de forma consistente.
- La auditoria no registra acciones criticas.
- La base de datos presenta errores de escritura.
EOF

echo "== Creando guia de operacion inicial =="
cat > docs/guia_operacion_piloto_interno.md <<'EOF'
# Apps Emisiones - Guia de operacion inicial del piloto interno

## Proposito

Guia practica para operar el piloto interno de Apps Emisiones con control, trazabilidad y soporte basico.

## Roles operativos del piloto

| Rol | Responsabilidad |
| --- | --- |
| Responsable TI | Mantener ambiente, backups, logs y soporte tecnico |
| Usuario solicitante | Crear solicitudes de pago demo o reales controladas |
| Usuario aprobador | Validar flujo de aprobacion/rechazo |
| Cuentas por pagar | Validar bandeja operativa y registro de pago |
| Auditor/administrador | Validar dashboard, reportes, exportacion y auditoria |

## Apertura diaria

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

git status
git log --oneline --max-count=5 --decorate
docker compose ps
docker compose exec backend python manage.py check
```

## Operacion diaria

- Confirmar disponibilidad de la URL piloto.
- Confirmar login de al menos un usuario administrativo.
- Registrar casos UAT ejecutados.
- Registrar errores con evidencia.
- No corregir en caliente sin separar incidente, causa y decision.

## Cierre diario

- Revisar logs.
- Ejecutar backup.
- Registrar hallazgos.
- Clasificar incidentes.
- Definir si el piloto continua, se pausa o requiere correccion.

## Control de cambios durante piloto

Todo cambio debe cumplir:

- Rama identificada.
- Motivo documentado.
- Validacion focal.
- Validacion completa si afecta flujo critico.
- Commit pequeno.
- Push a `develop` si queda aprobado.
- Actualizacion documental si cambia operacion.

## Decision de salida del piloto

Al finalizar el piloto se debe decidir una de estas rutas:

1. Aprobar pase a despliegue controlado.
2. Extender piloto con correcciones menores.
3. Pausar por brechas funcionales.
4. Reabrir fase tecnica especifica.

## Evidencia minima de cierre

- Checklist predespliegue firmado o validado.
- Casos UAT ejecutados.
- Incidentes registrados.
- Backups generados.
- Smoke test final.
- Decision formal del responsable.
EOF

echo "== Creando documento maestro del bloque piloto =="
cat > docs/despliegue_piloto_interno.md <<'EOF'
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
EOF

echo "== Verificando alcance documental/scripts =="
invalid_paths="$(git status --porcelain | awk '{print $2}' | grep -Ev '^(docs/|scripts/)' || true)"
if [ -n "$invalid_paths" ]; then
  echo "ERROR: se detectaron cambios fuera de docs/ y scripts/:" >&2
  printf '%s\n' "$invalid_paths" >&2
  exit 1
fi

echo "== Estado generado =="
git status --short

echo "== Diff documental resumido =="
git diff --stat

echo "== Validando diff whitespace =="
git diff --check

echo "== Django check sin cambios funcionales =="
docker compose exec backend python manage.py check

echo "== Verificando que no hay migraciones pendientes =="
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== Bloque piloto interno aplicado a documentacion =="
echo "Siguiente paso sugerido: revisar salida y luego ejecutar scripts/134_finalize_pilot_internal_deployment_docs.sh"
