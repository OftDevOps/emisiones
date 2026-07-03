#!/usr/bin/env bash
set -euo pipefail

echo "== F1-P27: documentacion operativa MVP Fase 1 =="
echo "== Rama actual =="
git branch --show-current

echo "== Estado inicial =="
git status --short

mkdir -p docs

cat > docs/mvp_operativo_fase1.md <<'DOC'
# Apps Emisiones - MVP operativo Fase 1

## Estado del proyecto

Este documento resume el estado operativo del MVP de Apps Emisiones al cierre de F1-P26.

Estado confirmado:

- `develop` estable.
- Backend CI verde.
- Login funcional con correo electronico.
- Aplicacion visible localmente en `http://localhost:8001`.
- SGD-OFTALMI usa `http://localhost:8000`, por lo tanto Apps Emisiones no debe usarse en ese puerto.

## Puertos locales

| Aplicacion | URL local |
|---|---|
| SGD-OFTALMI | `http://localhost:8000` |
| Apps Emisiones | `http://localhost:8001` |

## Rutas operativas actuales

| Funcion | Ruta |
|---|---|
| Login | `http://localhost:8001/login/` |
| Dashboard principal | `http://localhost:8001/dashboard/` |
| Dashboard operativo de solicitudes | `http://localhost:8001/payment-requests/dashboard/` |
| Solicitudes de pago | `http://localhost:8001/payment-requests/` |
| Pendientes por aprobar | `http://localhost:8001/payment-approvals/pending/` |
| Auditoria de acciones criticas | `http://localhost:8001/payment-approvals/audit/` |
| Cuentas por Pagar | `http://localhost:8001/payment-requests/accounts-payable/` |
| Admin Django | `http://localhost:8001/admin/` |
| Healthcheck | `http://localhost:8001/health/` |

## Usuarios demo

Los usuarios demo se crean con:

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones
chmod +x scripts/73_f1_p26_seed_demo_data.sh
./scripts/73_f1_p26_seed_demo_data.sh
```

Clave comun de usuarios demo:

```text
Demo123456*
```

| Correo | Rol | Empresa |
|---|---|---|
| `douglas.chirinos@oftalmi.com` | ADMINISTRADOR | Laboratorios Oftalmi |
| `solicitante.demo@oftalmi.com` | SOLICITANTE | Laboratorios Oftalmi |
| `responsable.demo@oftalmi.com` | RESPONSABLE_UNIDAD | Laboratorios Oftalmi |
| `finanzas.demo@oftalmi.com` | FINANZAS | Laboratorios Oftalmi |
| `cxp.demo@oftalmi.com` | CUENTAS_POR_PAGAR | Laboratorios Oftalmi |
| `auditor.demo@oftalmi.com` | AUDITOR | Laboratorios Oftalmi |
| `solicitante.otra.demo@oftalmi.com` | SOLICITANTE | Inversiones Demo Oftalmi |

## Flujo operativo validable

### 1. Solicitud de pago

Ruta:

```text
/payment-requests/
```

Permite listar solicitudes existentes y acceder al detalle.

### 2. Dashboard operativo

Ruta:

```text
/payment-requests/dashboard/
```

Muestra:

- resumen ejecutivo por estado;
- accesos operativos;
- pendientes de aprobacion para el rol del usuario;
- ultimas solicitudes.

### 3. Pendientes por aprobar

Ruta:

```text
/payment-approvals/pending/
```

Muestra pasos pendientes segun:

- usuario autenticado;
- rol requerido;
- empresa principal del usuario;
- estado pendiente.

### 4. Cuentas por Pagar

Ruta:

```text
/payment-requests/accounts-payable/
```

Muestra solicitudes aprobadas pendientes de ejecucion de pago.

Reglas relevantes:

- solo rol CUENTAS_POR_PAGAR o superusuario;
- scope por empresa;
- excluye solicitudes ya pagadas.

### 5. Registro de pago

Desde Cuentas por Pagar se registra la ejecucion del pago.

Al registrar pago:

- se crea `PaymentExecution`;
- la solicitud pasa a estado `PAID`;
- se registra accion transversal `PAYMENT_EXECUTED` en `PaymentApprovalAction`;
- el detalle muestra trazabilidad del pago.

### 6. Auditoria transversal

Ruta:

```text
/payment-approvals/audit/
```

Muestra acciones criticas:

- envio a aprobacion;
- aprobacion;
- rechazo;
- cancelacion;
- ejecucion de pago.

Filtros disponibles:

- accion;
- empresa;
- fecha desde;
- fecha hasta.

Reglas de visibilidad:

- superusuario ve todas las empresas;
- usuario comun ve acciones de su empresa principal.

## Solicitudes demo esperadas

El seed F1-P26 crea solicitudes demo con estos estados:

| Estado | Descripcion |
|---|---|
| DRAFT | Solicitud borrador |
| SUBMITTED | Pendiente de aprobacion |
| APPROVED | Aprobada pendiente de pago |
| PAID | Pagada con trazabilidad |
| REJECTED | Rechazada con auditoria |
| APPROVED otra empresa | Solicitud fuera del scope de Laboratorios Oftalmi |

## Validacion local estandar

Antes de cerrar cualquier punto funcional ejecutar:

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

Los mensajes `Forbidden` y `Not Found` durante los tests son normales cuando el resultado final de la suite es `OK`.

## Comandos utiles

### Levantar stack

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones
docker compose up -d --build
docker compose ps
```

### Aplicar migraciones

```bash
docker compose exec backend python manage.py migrate
```

### Crear superusuario

El usuario de login es el correo electronico.

```bash
docker compose exec backend python manage.py createsuperuser
```

### Ver contenedores y puertos

```bash
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

## Puntos cerrados recientes

| Punto | Estado | Commit |
|---|---|---|
| F1-P23 | Auditoria transversal base | `feat: add cross action audit trail` |
| F1-P24 | Workbench de auditoria transversal | `feat: add cross action audit workbench` |
| F1-P25 | Navegacion al workbench de auditoria | `feat: add audit navigation to payment dashboard` |
| F1-P26 | Datos demo para validacion visual | `chore: add demo seed data for payment workflow` |

## Pendientes recomendados

### Branding institucional

Pendiente para una fase posterior.

Base tecnica disponible:

- `backend/static/css/`
- `backend/static/img/`
- `backend/static/js/`
- `backend/templates/base.html`

Objetivo futuro:

- mover CSS embebido de `base.html` a CSS institucional;
- aplicar paleta Oftalmi;
- mejorar navegacion global;
- normalizar cards, tablas, botones y formularios.

### Proximos puntos funcionales sugeridos

- endurecer permisos por rol para auditoria y navegacion;
- mejorar filtros operativos;
- exportar auditoria a CSV o Excel;
- agregar pruebas de flujo end-to-end por rol;
- documentar criterios de cierre de Fase 1.
DOC

echo "== Documento creado =="
ls -lh docs/mvp_operativo_fase1.md

echo "== Validacion de archivos =="
git status --short

echo "== OK F1-P27 aplicado. Ejecutar validacion completa antes de commit. =="
