#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
DOCS_DIR="$PROJECT_ROOT/docs"
OUTPUT_FILE="$DOCS_DIR/continuidad_fase1_cierre_arranque_fase2.md"

cd "$PROJECT_ROOT"
mkdir -p "$DOCS_DIR"

cat > "$OUTPUT_FILE" <<'MD'
# Apps Emisiones - Continuidad para nuevo chat

## Proposito del documento

Este documento consolida el estado final de la Fase 1 del proyecto **Apps Emisiones** y sirve como punto de arranque para continuar en un nuevo chat sin depender del contexto acumulado de la conversacion anterior.

Debe usarse como primer insumo del proximo chat para retomar el proyecto con precision operativa, tecnica y de gestion.

---

## Contexto general del proyecto

- Proyecto: **Apps Emisiones**
- Repositorio local: `/home/dchirinos/oftalmiIA/emisiones/emisiones`
- Repositorio GitHub: `OftDevOps/emisiones`
- Rama estable de integracion: `develop`
- Flujo de trabajo: `feature/* -> develop -> main`
- Modo de ejecucion acordado: instrucciones directas en terminal/scripts del proyecto.
- No usar Codex para continuar las fases de este proyecto.
- Los scripts descargables deben ubicarse directamente en:

```bash
/home/dchirinos/oftalmiIA/emisiones/emisiones/scripts/
```

---

## Estado final de Fase 1

La **Fase 1** queda cerrada funcional y tecnicamente hasta el punto **F1-P29**, con CI verde en `develop`.

### Ultimo estado confirmado

- Rama estable: `develop`
- Ultimo cierre: **F1-P29 - Cierre tecnico de Fase 1**
- Commit de cierre: `docs: add phase 1 technical closure`
- Backend CI en `develop`: `success`
- Run ID CI: `28682932912`
- Duracion CI: `35s`

---

## Puntos cerrados recientes

| Punto | Descripcion | Estado |
|---|---|---|
| F1-P23 | Auditoria transversal base de acciones criticas | Cerrado |
| F1-P24 | Workbench de auditoria transversal | Cerrado |
| F1-P25 | Navegacion al workbench de auditoria desde dashboard | Cerrado |
| F1-P26 | Datos demo para validacion visual del flujo operativo | Cerrado |
| F1-P27 | Documentacion operativa del MVP actual | Cerrado |
| F1-P28 | Validacion visual funcional del MVP operativo | Cerrado |
| F1-P29 | Cierre tecnico de Fase 1 | Cerrado |
| F1-P30 | Documento de continuidad para nuevo chat / arranque Fase 2 | En preparacion/cierre |

---

## Ultimos commits relevantes

Referencia observada al cierre de Fase 1:

```text
01d1b28 docs: add visual functional review checklist
9e895ad docs: add operational MVP guide
a3436ed chore: add demo seed data for payment workflow
13fbcd6 feat: add audit navigation to payment dashboard
0bd7faa feat: add cross action audit workbench
5f6ba0b feat: add cross action audit trail
85e3a98 feat: show payment execution traceability
656c7b9 feat: add basic payment execution registration
0178fab feat: add accounts payable workbench
ed9e662 feat: add pending approval workbench
```

Luego de F1-P29 debe existir adicionalmente:

```text
docs: add phase 1 technical closure
```

---

## Puertos locales correctos

Importante para evitar confusion con otros proyectos:

| Proyecto | URL local |
|---|---|
| Apps Emisiones | `http://localhost:8001` |
| SGD-OFTALMI | `http://localhost:8000` |

Apps Emisiones usa externamente el puerto **8001**.

---

## Rutas funcionales actuales

Rutas verificadas funcionales en Apps Emisiones:

```text
Login:
http://localhost:8001/login/

Dashboard principal:
http://localhost:8001/dashboard/

Dashboard solicitudes:
http://localhost:8001/payment-requests/dashboard/

Solicitudes:
http://localhost:8001/payment-requests/

Pendientes por aprobar:
http://localhost:8001/payment-approvals/pending/

Auditoria:
http://localhost:8001/payment-approvals/audit/

Cuentas por pagar:
http://localhost:8001/payment-requests/accounts-payable/
```

Nota: la ruta correcta de login es `/login/`, no `/accounts/login/`.

---

## Usuarios demo

Seed demo creado en F1-P26.

Clave comun para usuarios demo:

```text
Demo123456*
```

Usuarios creados por el seed:

| Usuario | Rol | Empresa |
|---|---|---|
| `douglas.chirinos@oftalmi.com` | ADMINISTRADOR | Laboratorios Oftalmi |
| `solicitante.demo@oftalmi.com` | SOLICITANTE | Laboratorios Oftalmi |
| `responsable.demo@oftalmi.com` | RESPONSABLE_UNIDAD | Laboratorios Oftalmi |
| `finanzas.demo@oftalmi.com` | FINANZAS | Laboratorios Oftalmi |
| `cxp.demo@oftalmi.com` | CUENTAS_POR_PAGAR | Laboratorios Oftalmi |
| `auditor.demo@oftalmi.com` | AUDITOR | Laboratorios Oftalmi |
| `solicitante.otra.demo@oftalmi.com` | SOLICITANTE | Inversiones Demo Oftalmi |

---

## Solicitudes demo esperadas

El seed F1-P26 crea solicitudes para validar visualmente varios estados:

| Estado | Descripcion demo |
|---|---|
| DRAFT | Solicitud borrador |
| SUBMITTED | Pendiente de aprobacion |
| APPROVED | Aprobada pendiente de pago |
| PAID | Pagada con trazabilidad |
| REJECTED | Rechazada con auditoria |
| APPROVED | Otra empresa no visible |

---

## Flujo operativo MVP validado

Flujo funcional de referencia:

```text
Solicitud de pago
  -> envio / submit
  -> aprobacion o rechazo
  -> bandeja de pendientes
  -> cuentas por pagar
  -> registro de pago
  -> trazabilidad / auditoria transversal
```

Capacidades actuales:

- Login por correo.
- Dashboard autenticado.
- Dashboard operativo de solicitudes.
- Listado y detalle de solicitudes.
- Bandeja de aprobaciones pendientes.
- Workbench de Cuentas por Pagar.
- Registro basico de ejecucion de pago.
- Trazabilidad de ejecucion de pago.
- Auditoria transversal de acciones criticas.
- Datos demo para validar flujo visual.
- Documentacion operativa y checklist visual funcional.

---

## Documentos creados en Fase 1

Documentos principales generados:

```text
docs/mvp_operativo_fase1.md
docs/validacion_visual_funcional_fase1.md
docs/cierre_tecnico_fase1.md
```

Documento de continuidad esperado por F1-P30:

```text
docs/continuidad_fase1_cierre_arranque_fase2.md
```

---

## Scripts recientes

Scripts asociados a los puntos finales:

```text
scripts/73_f1_p26_seed_demo_data.sh
scripts/seed_f1_p26_demo_data.py
scripts/74_f1_p27_operational_docs.sh
scripts/75_f1_p28_visual_functional_review.sh
scripts/76_f1_p29_phase1_technical_closure.sh
scripts/77_f1_p30_continuity_new_chat.sh
```

---

## Validaciones estandar

Para validar cambios en Apps Emisiones usar el bloque completo:

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

Notas:

- Los mensajes `Forbidden` y `Not Found` durante los tests pueden ser esperados si el resultado final es `OK`.
- Antes de validar con Docker, desconectar NordVPN porque puede interferir con puertos locales.
- Al final reconectar con `nordvpn connect United_States` y confirmar con `nordvpn status`.

---

## Branding institucional

Decision tomada al cierre de Fase 1:

- El branding institucional queda **postergado**.
- La aplicacion es funcional, pero visualmente aun requiere mejora.
- Se debe abordar como bloque separado, idealmente antes de validacion ejecutiva o usuarios finales.

Colores recordados/recomendados para Oftalmi:

```text
Azul institucional principal: #0d6efd
Verde exito/accion positiva: #198754
Gris de fondo: #f7f7f7
Azul oscuro institucional: #172033 aproximado
Azul claro de apoyo visual institucional
```

Pendiente sugerido:

```text
F2 o bloque separado -> Branding base institucional Oftalmi para Apps Emisiones
```

Alcance futuro de branding:

- Crear CSS institucional reutilizable.
- Mejorar `base.html`.
- Corregir navegacion global.
- Aplicar paleta institucional.
- Mejorar cards, tablas, botones, mensajes y layout.
- No cambiar reglas de negocio.

---

## Recomendacion para el siguiente chat

El proximo chat debe iniciar con este documento y decidir una de dos rutas:

### Ruta A - Arranque Fase 2 funcional

Avanzar con nuevas capacidades de negocio, control, seguridad o flujo operativo.

Recomendado si el objetivo es seguir construyendo funcionalidad.

### Ruta B - Branding institucional antes de Fase 2

Aplicar identidad visual Oftalmi al MVP ya funcional.

Recomendado si el objetivo es mostrar la aplicacion a usuarios, jefatura o validadores internos.

---

## Punto siguiente sugerido

Opcion 1:

```text
F2-P01 -> Definicion y arranque tecnico de Fase 2
```

Opcion 2:

```text
F1-BR01 -> Branding base institucional Oftalmi para MVP Emisiones
```

Recomendacion tecnica: si el sistema sera mostrado a usuarios internos, hacer primero el bloque de branding. Si solo se seguira desarrollo interno, arrancar Fase 2.

---

## Comandos iniciales recomendados en nuevo chat

Al abrir el nuevo chat, ejecutar y pegar salida:

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

git switch develop
git pull origin develop
git status --short
git log --oneline --max-count=12 --decorate

find docs -maxdepth 2 -type f | sort
find scripts -maxdepth 1 -type f | sort | tail -30
```

---

## Criterio de cierre de Fase 1

Fase 1 se considera cerrada porque:

- El flujo operativo base existe.
- Hay rutas funcionales verificadas.
- Hay usuarios y datos demo.
- Hay trazabilidad de acciones criticas.
- Hay workbench de auditoria.
- Hay workbench de Cuentas por Pagar.
- Hay documentacion operativa.
- Hay checklist visual funcional.
- Hay cierre tecnico documentado.
- CI en `develop` esta verde.

---

## Nota para el asistente del proximo chat

No asumir rutas de otros proyectos. Para Apps Emisiones usar siempre:

```text
http://localhost:8001
```

No usar Codex para continuar fases. Dar comandos directos de terminal y scripts ejecutables dentro del proyecto.

Los scripts deben quedar directamente en:

```text
/home/dchirinos/oftalmiIA/emisiones/emisiones/scripts/
```
MD

printf '== F1-P30: Documento de continuidad para nuevo chat ==\n'
printf 'OK: documento creado en %s\n' "$OUTPUT_FILE"
printf '\n== Archivos ==\n'
ls -l "$OUTPUT_FILE"
