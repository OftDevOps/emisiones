#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== F2-P13: cierre tecnico documental de Fase 2 =="

echo "== Guardas de seguridad =="
current_branch="$(git branch --show-current)"
if [ "$current_branch" != "develop" ]; then
  echo "ERROR: este cierre debe aplicarse sobre develop. Rama actual: $current_branch" >&2
  exit 1
fi

# El arbol debe estar limpio excepto por los scripts F2-P13 descargados.
unexpected_status="$(git status --porcelain | grep -Ev '^(\?\? scripts/131_f2_p13_technical_closure\.sh|\?\? scripts/132_finalize_f2_p13_commit\.sh)$' || true)"
if [ -n "$unexpected_status" ]; then
  echo "ERROR: el arbol de trabajo tiene cambios no esperados. Revise antes de aplicar F2-P13:" >&2
  printf '%s
' "$unexpected_status" >&2
  exit 1
fi

echo "== Estado inicial =="
git status --short
git log --oneline --max-count=5 --decorate

mkdir -p docs

echo "== Creando documento de cierre tecnico F2-P13 =="
cat > docs/f2_p13_cierre_tecnico_fase2.md <<'MD'
# F2-P13 - Cierre tecnico de Fase 2

## Proposito

Este documento formaliza el cierre tecnico de la **Fase 2** de Apps Emisiones, consolidando el avance documental, funcional, de seguridad, QA y operacion construido sobre el flujo de solicitudes de pago.

El cierre es deliberadamente documental: no incorpora modelos, migraciones ni cambios de logica funcional.

## Alcance del cierre

F2-P13 consolida:

- Roadmap de Fase 2 actualizado.
- Rutas operativas actuales.
- Permisos aplicados por rol.
- Evidencias de validacion tecnica.
- Controles de navegacion y visibilidad.
- Reportes y exportacion operativa.
- Auditoria extendida.
- Paquete de validacion con usuarios internos.
- Pendientes para piloto interno, despliegue controlado y Fase 3.

## Estado ejecutivo

La Fase 2 queda cerrada a nivel tecnico con una base consistente para iniciar piloto interno controlado.

Resultado de negocio:

- Mayor trazabilidad del ciclo de solicitud, aprobacion y ejecucion de pagos.
- Separacion mas clara de responsabilidades por rol.
- Mejor visibilidad operacional para usuarios autorizados.
- Preparacion documental para validacion interna con usuarios clave.
- Base lista para planificar despliegue piloto sin agregar deuda funcional critica.

## Puntos cerrados de Fase 2

| Punto | Resultado |
|---|---|
| F2-P01 | Arranque tecnico de Fase 2 |
| F2-P02 | Matriz de roles y visibilidad |
| F2-P03 | Permisos en vistas criticas |
| F2-P04 | Context processor de navegacion operacional |
| F2-P04B | Visibilidad real de menu por rol |
| F2-P05 | Pruebas integradas de navegacion |
| F2-P06 | Documentacion de transiciones de estado |
| F2-P07 | Validacion de transiciones de estado |
| F2-P08 | Dashboard operativo mejorado por rol |
| F2-P09 | Reporte basico por estado, empresa y fecha |
| F2-P10 | Exportacion operativa basica |
| F2-P11 | Auditoria extendida |
| F2-P12 | Paquete de validacion con usuarios internos |
| F2-P13 | Cierre tecnico de Fase 2 |

## Rutas operativas documentadas

Rutas principales disponibles segun permisos:

- `/payment-requests/`
- `/payment-requests/create/`
- `/payment-requests/<id>/`
- `/payment-requests/<id>/submit/`
- `/payment-requests/dashboard/`
- `/payment-requests/accounts-payable/`
- `/payment-requests/reports/basic/`
- `/payment-requests/reports/basic/export/`
- `/payment-approvals/pending/`
- `/payment-approvals/steps/<id>/action/`
- `/payment-approvals/audit/`
- `/payment-requests/<id>/execute-payment/`

Las rutas anteriores se mantienen bajo control de autenticacion y restricciones operativas por rol.

## Permisos y roles consolidados

Roles de referencia usados en Fase 2:

- `ADMINISTRADOR`
- `SOLICITANTE`
- `RESPONSABLE_UNIDAD`
- `FINANZAS`
- `GERENCIA_GENERAL`
- `JUNTA_DIRECTIVA`
- `AUDITOR`

Criterios de control aplicados:

- El usuario autenticado solo ve opciones de menu coherentes con su rol.
- Las vistas criticas validan permisos en servidor, no solo en plantilla.
- Usuarios sin rol operativo reciben bloqueo por `PermissionDenied` cuando intentan acceder a rutas restringidas.
- La auditoria operativa se reserva a roles autorizados.
- La ejecucion de pagos se restringe a perfiles con responsabilidad financiera.
- Las acciones de aprobacion validan acceso al paso y rol autorizado antes de procesar la accion.

## Evidencias tecnicas consolidadas

Durante Fase 2 se ejecutaron validaciones recurrentes sobre:

- Calidad estatica con `ruff check .`.
- Integridad Django con `python manage.py check`.
- Control de migraciones con `makemigrations --check --dry-run`.
- Aplicacion de migraciones con `migrate`.
- Pruebas automatizadas por apps criticas.
- Validacion de navegacion por rol.
- Validacion de permisos de vistas criticas.
- Validacion de transiciones de estado.
- Validacion de reportes y exportacion.
- Validacion de auditoria extendida.

Comando operativo completo de cierre recomendado:

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

## Observaciones sobre mensajes esperados en pruebas

Durante el test suite pueden aparecer trazas `Forbidden` o `Not Found` en consola. No representan falla si el resultado final indica `OK`.

Estos mensajes cubren casos negativos esperados, por ejemplo:

- Usuario sin permiso intentando acceder a Cuentas por Pagar.
- Usuario sin permiso intentando acceder al dashboard operativo.
- Usuario sin permiso intentando acceder a auditoria.
- Acceso a solicitudes o pasos inexistentes.
- Intento de ejecutar pagos con rol no autorizado.

## Paquete de validacion interna

F2-P12 dejo preparado el paquete de validacion con usuarios internos, incluyendo checklist y guia de validacion.

Uso esperado:

- Ejecutar piloto con usuarios internos por rol.
- Registrar hallazgos funcionales.
- Separar defectos reales de ajustes de UX o capacitacion.
- No mezclar validacion interna con desarrollo de nuevas funcionalidades.

## Pendientes para piloto interno

Antes del despliegue controlado:

- Definir usuarios internos por rol.
- Cargar datos de prueba representativos.
- Confirmar responsables de aprobacion.
- Confirmar flujo de pagos reales versus pagos simulados.
- Preparar plan de rollback.
- Preparar respaldo de base de datos.
- Revisar variables `.env` por ambiente.
- Confirmar dominio, SSL y acceso interno.
- Definir horario de ventana de validacion.
- Documentar incidencias y severidad.

## Pendientes para Fase 3

La Fase 3 deberia enfocarse en despliegue piloto y endurecimiento operacional:

- Preparacion de ambiente piloto.
- Variables de entorno por ambiente.
- Nginx/Gunicorn o stack final de publicacion.
- Backup y restore verificado.
- Observabilidad basica.
- Plan de rollback.
- Datos demo o datos UAT controlados.
- Manual operativo para soporte.
- Cierre de hallazgos UAT priorizados.

## Restricciones de este cierre

F2-P13 no debe incluir:

- Nuevos modelos.
- Nuevas migraciones.
- Cambios en vistas.
- Cambios en URLs.
- Cambios en templates.
- Cambios en permisos funcionales.
- Cambios de flujo de negocio.
- Refactors tecnicos no relacionados con documentacion.

## Criterio de salida

Fase 2 queda cerrada cuando:

- Este documento existe en `docs/`.
- `docs/roadmap_fase2.md` refleja F2-P13 como cierre tecnico.
- La validacion completa termina en `OK`.
- El commit documental se publica en `origin/develop`.

Commit sugerido:

```text
docs: close phase 2 technical baseline
```
MD

echo "== Actualizando roadmap_fase2.md =="
python3 - <<'PY'
from pathlib import Path
import re

path = Path("docs/roadmap_fase2.md")
if not path.exists():
    raise SystemExit("ERROR: docs/roadmap_fase2.md no existe")

text = path.read_text(encoding="utf-8")
original = text

# Normaliza cualquier checklist simple de F2-P13 si existe.
text = re.sub(r"(?im)^\s*[-*]\s*\[\s\]\s*(F2-P13\b.*)$", r"- [x] \1", text)
text = re.sub(r"(?im)^\s*[-*]\s*\[x\]\s*(F2-P13\b.*)$", r"- [x] \1", text)

# Marca estados textuales comunes si ya existe una linea F2-P13.
text = re.sub(r"(?im)^(.*F2-P13.*?)(pendiente|por hacer|en curso)(.*)$", r"\1cerrado\3", text)

marker_start = "<!-- F2-P13-CIERRE-TECNICO:START -->"
marker_end = "<!-- F2-P13-CIERRE-TECNICO:END -->"
block = f"""{marker_start}

## F2-P13 - Cierre tecnico de Fase 2

Estado: **cerrado documentalmente**.

Alcance aplicado:

- Se consolida cierre tecnico de Fase 2.
- Se documentan rutas operativas actuales.
- Se documentan permisos aplicados por rol.
- Se consolidan validaciones tecnicas ejecutadas.
- Se registran pendientes para piloto interno, despliegue controlado y Fase 3.
- No se crean modelos.
- No se crean migraciones.
- No se modifica logica funcional.

Documento asociado:

- `docs/f2_p13_cierre_tecnico_fase2.md`

{marker_end}"""

if marker_start in text and marker_end in text:
    text = re.sub(
        rf"{re.escape(marker_start)}.*?{re.escape(marker_end)}",
        block,
        text,
        flags=re.S,
    )
else:
    if not text.endswith("\n"):
        text += "\n"
    text += "\n" + block + "\n"

if text == original:
    raise SystemExit("ERROR: roadmap_fase2.md no cambio; revise estructura")

path.write_text(text, encoding="utf-8")
PY

echo "== Verificando que solo existan cambios documentales/scripts =="
changed_files="$(git status --porcelain | awk '{print $2}')"
if [ -z "$changed_files" ]; then
  echo "ERROR: no se generaron cambios" >&2
  exit 1
fi

bad_files="$(printf '%s\n' "$changed_files" | grep -Ev '^(docs/|scripts/)' || true)"
if [ -n "$bad_files" ]; then
  echo "ERROR: F2-P13 solo permite cambios en docs/ y scripts/. Archivos no permitidos:" >&2
  printf '%s\n' "$bad_files" >&2
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

echo "== F2-P13 aplicado a documentacion =="
echo "Siguiente paso sugerido: ejecutar validacion completa y cierre con scripts/132_finalize_f2_p13_commit.sh"
