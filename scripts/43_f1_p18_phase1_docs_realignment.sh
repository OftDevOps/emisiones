#!/usr/bin/env bash
set -euo pipefail

# F1-P18 - Realineación documental y backlog vivo de Fase 1
# Proyecto: OftDevOps/emisiones
#
# Ruta del proyecto:
#   /home/dchirinos/oftalmiIA/emisiones/emisiones
#
# Ruta destino del playbook:
#   /home/dchirinos/oftalmiIA/emisiones/emisiones/scripts/43_f1_p18_phase1_docs_realignment.sh
#
# Uso:
#   cd /home/dchirinos/oftalmiIA/emisiones/emisiones
#   chmod +x scripts/43_f1_p18_phase1_docs_realignment.sh
#   ./scripts/43_f1_p18_phase1_docs_realignment.sh
#
# Alcance:
# - Solo documentación.
# - No toca modelos.
# - No toca migraciones.
# - No toca vistas, URLs, templates funcionales ni tests.
# - No hace commit.
# - No hace push.

EXPECTED_BRANCH="feature/phase1-docs-realignment"

echo "== F1-P18: Realineación documental y backlog vivo de Fase 1 =="

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "ERROR: este directorio no parece ser un repositorio Git."
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

CURRENT_BRANCH="$(git branch --show-current)"
if [ "$CURRENT_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ERROR: rama incorrecta."
  echo "Actual:   $CURRENT_BRANCH"
  echo "Esperada: $EXPECTED_BRANCH"
  echo
  echo "Crea la rama con:"
  echo "  git switch develop"
  echo "  git pull origin develop"
  echo "  git switch -c $EXPECTED_BRANCH"
  exit 1
fi

echo "== Git status antes de aplicar documentación =="
git status --short

BACKEND_CHANGES="$(git status --short -- backend || true)"
if [ -n "$BACKEND_CHANGES" ]; then
  echo "ERROR: hay cambios en backend/. Este playbook es solo documental."
  echo "$BACKEND_CHANGES"
  exit 1
fi

mkdir -p docs/03-desarrollo docs/06-backlog

cat > docs/06-backlog/fase1_plan_trabajo.md <<'EOF'
# Fase 1 - Plan de trabajo vivo

**Proyecto:** Sistema de Rutas de Pago Oftalmi  
**Fase:** Fase 1 - Núcleo operativo del MVP  
**Estado:** En ejecución  
**Documento maestro vigente:** `docs/00-alcance/alcance_reglas_rutas_pago_oftalmi_v2.md`  
**Última realineación:** F1-P18  

---

## 1. Propósito

Este documento mantiene la secuencia real de implementación técnica de la Fase 1.

La Fase 1 no se maneja como una lista cerrada rígida de tareas, sino como una descomposición técnica progresiva del núcleo operativo del MVP. Su objetivo funcional es permitir crear solicitudes de pago, adjuntar documentos, enviarlas a una ruta básica, aprobar, rechazar, devolver, pasar a Cuentas por Pagar, registrar pago y consultar trazabilidad básica.

---

## 2. Fuente funcional de referencia

La fuente principal es el documento:

```text
docs/00-alcance/alcance_reglas_rutas_pago_oftalmi_v2.md
```

Ese documento establece que el MVP estricto incluye Fase 0 + Fase 1 y que Fase 1 debe cubrir:

- Login por correo.
- Roles básicos.
- Usuarios por unidad.
- Solicitud de pago.
- Carga y visualización de documentos.
- Adelantos.
- Ruta básica.
- Aprobación.
- Devolución.
- Rechazo.
- Bandejas básicas.
- Cuentas por Pagar.
- Registro de pago.
- Auditoría básica.
- Validaciones mínimas de seguridad en backend.
- Docker Compose base.
- Configuración por ambiente mediante `.env`.
- Pruebas mínimas de flujos críticos.
- Branding Oftalmi.

---

## 3. Secuencia técnica real de Fase 1

| Punto | Nombre | Estado | Observación |
|---|---|---|---|
| F1-P01 | Django base project | Completado | Base inicial del backend Django. |
| F1-P02 | Settings por ambiente | Completado | Configuración separada por ambiente. |
| F1-P03 | Docker Compose backend + PostgreSQL | Completado | Ejecución reproducible local. |
| F1-P04 | CustomUser por email | Completado | Email como identificador de usuario. |
| F1-P05 | Roles base | Completado | Roles mínimos del MVP. |
| F1-P06 | App organization | Completado | Base organizativa. |
| F1-P07 | Relación usuario / empresa / unidad | Completado | Scope inicial por empresa/unidad. |
| F1-P08 | Login básico | Completado | Autenticación inicial. |
| F1-P09 | Pruebas mínimas transversales | Completado | Validación base. |
| F1-P10 | Beneficiarios / proveedores | Completado | Catálogo inicial de beneficiarios. |
| F1-P11 | Solicitudes de pago | Completado | Modelo principal de solicitud. |
| F1-P12 | Documentos soporte | Completado | Carga y relación documental base. |
| F1-P13 | Ruta básica de aprobación | Completado | Pasos de aprobación iniciales. |
| F1-P14 | Vistas básicas de solicitudes de pago | Completado | Listado, detalle y creación. |
| F1-P15 | Acciones básicas sobre solicitudes | Completado | Enviar/cancelar según reglas iniciales. |
| F1-P16 | Aprobación y rechazo desde UI | Completado | Acciones de aprobación/rechazo desde interfaz. |
| F1-P17 | Dashboard operativo de solicitudes | Completado | KPIs, últimas solicitudes y pendientes por rol. |
| F1-P18 | Realineación documental y backlog vivo de Fase 1 | En curso | Corrección de trazabilidad documental. |
| F1-P19 | Bandeja de trabajo: pendientes por aprobar | Pendiente | Bandeja enfocada por rol/nodo. |
| F1-P20 | Cuentas por Pagar: pagos aprobados pendientes por ejecutar | Pendiente | Bandeja para solicitudes aprobadas. |
| F1-P21 | Registro básico de ejecución de pago | Pendiente | Registro operativo del pago. |
| F1-P22 | Auditoría básica transversal / trazabilidad de solicitud | Pendiente | Consulta de eventos y cambios críticos. |
| F1-P23 | Cierre técnico de Fase 1 | Pendiente | Validación, documentación y preparación para Fase 2. |

---

## 4. Corrección de desalineación

Antes de F1-P18 existía una planificación documental previa donde algunos puntos finales de Fase 1 no coincidían con la implementación real.

La secuencia corregida es:

```text
F1-P15 = Acciones básicas sobre solicitudes
F1-P16 = Aprobación y rechazo desde UI
F1-P17 = Dashboard operativo de solicitudes
F1-P18 = Realineación documental y backlog vivo de Fase 1
```

Por tanto, los puntos de Cuentas por Pagar, ejecución de pago y auditoría transversal pasan a la continuidad real:

```text
F1-P20 = Cuentas por Pagar
F1-P21 = Registro básico de ejecución de pago
F1-P22 = Auditoría básica transversal
```

---

## 5. Criterios de control para los próximos puntos

### F1-P19 - Bandeja de trabajo: pendientes por aprobar

Debe incluir:

- Vista de pendientes por aprobar.
- Scope por empresa del usuario.
- Scope por rol/nodo del usuario.
- Acceso autenticado.
- Enlace a solicitud.
- Pruebas de login, empresa y rol.
- Sin migraciones si se reutiliza `PaymentApprovalStep`.

### F1-P20 - Cuentas por Pagar

Debe incluir:

- Bandeja de pagos aprobados pendientes por ejecutar.
- Acceso para rol `CUENTAS_POR_PAGAR`.
- Restricción por empresa.
- Validación de que solo solicitudes completamente aprobadas pasan a esta bandeja.
- Pruebas de permisos.

### F1-P21 - Registro básico de ejecución de pago

Debe incluir:

- Registro mínimo de fecha, referencia, monto, observación y usuario.
- Validación de solicitud aprobada.
- Restricción por rol.
- Pruebas de ejecución permitida/prohibida.

### F1-P22 - Auditoría básica transversal

Debe incluir:

- Consulta de trazabilidad básica por solicitud.
- Eventos mínimos de creación, envío, aprobación, rechazo, cancelación, carga documental y ejecución de pago.
- Protección de acceso.

### F1-P23 - Cierre técnico de Fase 1

Debe incluir:

- Validación completa local.
- CI verde en `develop`.
- Documentación actualizada.
- Lista de brechas para Fase 2.
- Revisión de que Fase 1 cumple el MVP estricto.

---

## 6. Regla operativa

Todo punto técnico nuevo debe:

1. Crearse desde `develop`.
2. Trabajarse en rama `feature/*`.
3. Tener playbook en `scripts/`.
4. Validar rama antes de modificar archivos.
5. Ejecutar pruebas.
6. No tocar `main` directamente.
7. Actualizar documentación cuando cambie el alcance o la secuencia real.

EOF

cat > docs/03-desarrollo/f1_p16_aprobacion_rechazo_ui.md <<'EOF'
# F1-P16 - Aprobación y rechazo desde UI

**Proyecto:** Sistema de Rutas de Pago Oftalmi  
**Fase:** Fase 1 - Núcleo operativo del MVP  
**Estado:** Completado  
**Rama de trabajo:** `feature/approval-actions-ui`  
**Integrado a:** `develop`  

---

## 1. Objetivo

Permitir que los usuarios autorizados ejecuten acciones de aprobación y rechazo desde la interfaz, respetando el rol del usuario, la empresa asociada y el paso de aprobación correspondiente.

---

## 2. Alcance implementado

Se implementó la acción sobre pasos de aprobación existentes mediante la vista de acción de aprobación.

La funcionalidad permite:

- Aprobar un paso pendiente.
- Rechazar un paso pendiente.
- Exigir comentario cuando aplica.
- Validar acceso por empresa.
- Validar acceso por rol requerido del paso.
- Mantener actualización del estado de la solicitud según la ruta básica.

---

## 3. Corrección relevante

Durante F1-P16 se corrigió la obtención del paso de aprobación para evitar errores incorrectos ante IDs inexistentes.

La vista `ApprovalStepActionView.get_step()` fue ajustada para usar `get_object_or_404`, manteniendo luego las validaciones de seguridad:

- Si el paso no existe, responde 404.
- Si el usuario no pertenece a la empresa de la solicitud, responde 403.
- Si el rol del usuario no corresponde al rol requerido del paso, responde 403.

---

## 4. Validaciones ejecutadas

Validación local ejecutada:

```bash
nordvpn disconnect
sleep 3

git status
git log --oneline --max-count=5

docker compose exec backend ruff check .
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests apps.payment_documents apps.payment_approvals

nordvpn connect United_States
nordvpn status
```

Resultado:

```text
Ruff OK
Django check OK
Sin cambios de migración
Migrate OK
Tests OK
```

---

## 5. Consideraciones

Los mensajes `Not Found` y `Forbidden` durante pruebas son esperados cuando los tests validan 404 y 403.

La señal de cierre correcta es que el suite finalice con `OK`.

---

## 6. Relación con el documento maestro

F1-P16 soporta las reglas de Fase 1 asociadas a:

- Acciones de nodo.
- Aprobación.
- Rechazo.
- Validación de permisos en backend.
- Control por rol y empresa.
- Trazabilidad futura de decisiones.

EOF

cat > docs/03-desarrollo/f1_p17_dashboard_operativo_solicitudes.md <<'EOF'
# F1-P17 - Dashboard operativo de solicitudes

**Proyecto:** Sistema de Rutas de Pago Oftalmi  
**Fase:** Fase 1 - Núcleo operativo del MVP  
**Estado:** Completado  
**Rama de trabajo:** `feature/payment-request-dashboard`  
**Integrado a:** `develop`  

---

## 1. Objetivo

Agregar un dashboard operativo para visualizar el estado general de las solicitudes de pago y facilitar el seguimiento diario de trabajo.

---

## 2. Alcance implementado

Se agregó una vista de dashboard para solicitudes de pago.

La vista muestra:

- Total de solicitudes visibles para el usuario.
- Conteo por estado.
- Últimas solicitudes.
- Pasos pendientes de aprobación asociados al rol del usuario.
- Enlaces hacia el detalle de solicitudes.

---

## 3. Ruta funcional

Ruta agregada:

```text
/payment-requests/dashboard/
```

Nombre de URL:

```text
payment_requests:dashboard
```

---

## 4. Archivos principales modificados

```text
backend/apps/payment_requests/views.py
backend/apps/payment_requests/urls.py
backend/templates/payment_requests/paymentrequest_list.html
backend/templates/payment_requests/paymentrequest_dashboard.html
backend/apps/payment_requests/tests/test_dashboard.py
scripts/42_f1_p17_payment_request_dashboard.sh
```

---

## 5. Reglas de seguridad aplicadas

El dashboard respeta el scope de solicitudes mediante `scoped_payment_request_queryset(user)`.

Reglas aplicadas:

- El superusuario puede ver todas las solicitudes.
- Un usuario no superusuario con `primary_company_id` solo ve solicitudes de su empresa.
- Un usuario no superusuario sin empresa asociada no ve solicitudes.
- Los pendientes de aprobación se filtran por:
  - empresa visible para el usuario;
  - rol requerido del paso;
  - estado pendiente del paso.

---

## 6. Validaciones ejecutadas

Validación local ejecutada:

```bash
nordvpn disconnect
sleep 3

git status
git log --oneline --max-count=5

docker compose exec backend ruff check .
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests apps.payment_documents apps.payment_approvals

nordvpn connect United_States
nordvpn status
```

Resultado registrado:

```text
Rama: feature/payment-request-dashboard
Ruff: OK
Django check: OK
Makemigrations check: OK
Migrate: OK
Tests: 61 OK
NordVPN: reconectado y activo
```

---

## 7. Observaciones

Los mensajes `Not Found` y `Forbidden` vistos durante pruebas corresponden a validaciones esperadas de rutas inexistentes y restricciones de permisos.

La señal válida de cierre fue:

```text
Ran 61 tests
OK
```

---

## 8. Relación con el documento maestro

F1-P17 apoya las reglas de Fase 1 relacionadas con:

- Bandejas de trabajo.
- Mis solicitudes.
- Pendientes por aprobar.
- Control por empresa.
- Control por rol.
- Seguimiento operativo básico.
- Validaciones mínimas de seguridad en backend.

EOF

cat > docs/03-desarrollo/continuidad_post_f1_p17.md <<'EOF'
# Continuidad posterior a F1-P17

**Proyecto:** Sistema de Rutas de Pago Oftalmi  
**Último punto funcional cerrado:** F1-P17 - Dashboard operativo de solicitudes  
**Siguiente punto ejecutado:** F1-P18 - Realineación documental y backlog vivo de Fase 1  
**Documento maestro vigente:** `docs/00-alcance/alcance_reglas_rutas_pago_oftalmi_v2.md`  

---

## 1. Estado funcional actual

Al cierre de F1-P17, el sistema cuenta con:

- Proyecto Django base.
- Configuración por ambiente.
- Docker Compose con backend y PostgreSQL.
- Usuario personalizado con email.
- Roles base.
- Estructura organizativa.
- Beneficiarios/proveedores.
- Solicitudes de pago.
- Documentos soporte.
- Ruta básica de aprobación.
- Vistas básicas de solicitudes.
- Envío/cancelación de solicitudes.
- Aprobación y rechazo desde UI.
- Dashboard operativo de solicitudes.

---

## 2. Última validación local conocida

```text
Ruff OK
Django check OK
Makemigrations check OK
Migrate OK
Tests: 61 OK
```

---

## 3. Decisión de realineación

Se detectó que la documentación de backlog previa no coincidía con la secuencia real ejecutada.

Por decisión de control del proyecto, antes de continuar con nuevas funcionalidades se ejecutó F1-P18 para:

- Actualizar el backlog vivo.
- Documentar F1-P16.
- Documentar F1-P17.
- Crear una continuidad clara para F1-P19 en adelante.
- Evitar pérdida de trazabilidad.

---

## 4. Próxima secuencia recomendada

```text
F1-P19 Bandeja de trabajo: pendientes por aprobar
F1-P20 Cuentas por Pagar: pagos aprobados pendientes por ejecutar
F1-P21 Registro básico de ejecución de pago
F1-P22 Auditoría básica transversal / trazabilidad de solicitud
F1-P23 Cierre técnico de Fase 1
```

---

## 5. F1-P19 - Criterios iniciales

La bandeja de pendientes por aprobar debe:

- Mostrar únicamente pasos pendientes.
- Filtrar por empresa del usuario.
- Filtrar por rol requerido del usuario.
- Requerir autenticación.
- Enlazar al detalle de solicitud.
- Tener pruebas de:
  - login requerido;
  - usuario autenticado;
  - scope por empresa;
  - scope por rol;
  - exclusión de pasos no pendientes.

Ruta sugerida:

```text
/payment-approvals/pending/
```

Rama sugerida:

```text
feature/approval-pending-workbench
```

Playbook sugerido:

```text
scripts/44_f1_p19_approval_pending_workbench.sh
```

---

## 6. Regla operativa de validación

Para cambios con Docker Compose se debe usar el bloque completo:

```bash
nordvpn disconnect
sleep 3

git status
git log --oneline --max-count=5

docker compose exec backend ruff check .
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests apps.payment_documents apps.payment_approvals

nordvpn connect United_States
nordvpn status
```

---

## 7. Restricción

No desarrollar directamente sobre `develop` ni sobre `main`.

Todo cambio debe salir de una rama `feature/*` creada desde `develop`.

EOF

if [ ! -s docs/README.md ]; then
  cat > docs/README.md <<'EOF'
# Documentación - Sistema de Rutas de Pago Oftalmi

Este directorio contiene la documentación funcional, técnica, de seguridad, DevOps, backlog y continuidad del Sistema de Rutas de Pago Oftalmi.

## Documento maestro vigente

```text
docs/00-alcance/alcance_reglas_rutas_pago_oftalmi_v2.md
```

Ese documento concentra el alcance funcional, reglas de negocio, ciberseguridad, ingeniería de software, DevOps, estrategia Git, fases del MVP y decisiones arquitectónicas consolidadas.

## Estructura

```text
docs/
├── 00-alcance/
├── 01-arquitectura/
├── 02-reglas-negocio/
├── 03-desarrollo/
├── 03-seguridad/
├── 04-devops/
├── 05-modelo-datos/
├── 06-backlog/
├── 07-branding/
└── 08-operacion/
```

## Regla de documentación viva

Toda funcionalidad crítica debe dejar evidencia documental cuando:

- cambie el alcance;
- cambie la secuencia del backlog;
- se cierre un punto de Fase 1;
- se modifique una regla de negocio;
- se agregue una decisión técnica relevante;
- se prepare una continuidad para el siguiente punto.

## Estado de referencia

La secuencia técnica real de Fase 1 se mantiene en:

```text
docs/06-backlog/fase1_plan_trabajo.md
```

La continuidad más reciente se mantiene en:

```text
docs/03-desarrollo/continuidad_post_f1_p17.md
```

EOF
else
  echo "INFO: docs/README.md ya existe y no está vacío; no se sobrescribe."
fi

echo "== Validación de archivos documentales generados =="
test -s docs/06-backlog/fase1_plan_trabajo.md
test -s docs/03-desarrollo/f1_p16_aprobacion_rechazo_ui.md
test -s docs/03-desarrollo/f1_p17_dashboard_operativo_solicitudes.md
test -s docs/03-desarrollo/continuidad_post_f1_p17.md
test -s docs/README.md

echo "== Archivos modificados/creados =="
git status --short

cat <<'NEXT'

Siguiente validación documental sugerida:

git status
git log --oneline --max-count=5
git diff -- docs/06-backlog/fase1_plan_trabajo.md
git diff -- docs/03-desarrollo/f1_p16_aprobacion_rechazo_ui.md
git diff -- docs/03-desarrollo/f1_p17_dashboard_operativo_solicitudes.md
git diff -- docs/03-desarrollo/continuidad_post_f1_p17.md
git diff -- docs/README.md

Si todo está correcto:

git add docs/06-backlog/fase1_plan_trabajo.md \
  docs/03-desarrollo/f1_p16_aprobacion_rechazo_ui.md \
  docs/03-desarrollo/f1_p17_dashboard_operativo_solicitudes.md \
  docs/03-desarrollo/continuidad_post_f1_p17.md \
  docs/README.md \
  scripts/43_f1_p18_phase1_docs_realignment.sh

git commit -m "docs: realign phase 1 backlog and continuity"
git push -u origin feature/phase1-docs-realignment

NEXT
