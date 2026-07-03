#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
DOCS_DIR="$ROOT_DIR/docs"
DOC_FILE="$DOCS_DIR/validacion_visual_funcional_fase1.md"

cd "$ROOT_DIR"

mkdir -p "$DOCS_DIR"

cat > "$DOC_FILE" <<'MD'
# F1-P28 - Validación visual funcional del MVP operativo

## Estado del punto

**Estado:** En validación / checklist funcional  
**Fase:** Fase 1 - MVP operativo de rutas de pago  
**Tipo de cambio:** Documentación de QA funcional y revisión visual  
**Impacto técnico:** No modifica lógica de negocio, modelos ni migraciones.

---

## Objetivo

Documentar una revisión visual y funcional del MVP operativo de Apps Emisiones usando los datos demo disponibles, antes de entrar a una fase formal de branding institucional.

Este punto busca separar dos temas:

1. **Validación funcional visual:** confirmar que el flujo se puede navegar y operar.
2. **Branding institucional:** queda como pendiente posterior para mejorar estética, identidad visual, colores, navegación y experiencia de usuario.

---

## Ambiente local confirmado

| Sistema | URL local | Observación |
|---|---:|---|
| SGD-OFTALMI | `http://localhost:8000` | Proyecto separado |
| Apps Emisiones | `http://localhost:8001` | Proyecto actual |

Ruta real de login para Apps Emisiones:

```text
http://localhost:8001/login/
```

No usar:

```text
http://localhost:8001/accounts/login/
```

---

## Usuarios demo para validación

Todos los usuarios demo usan la clave:

```text
Demo123456*
```

| Usuario | Rol | Uso esperado |
|---|---|---|
| `douglas.chirinos@oftalmi.com` | Administrador | Revisión general del flujo |
| `solicitante.demo@oftalmi.com` | Solicitante | Crear y consultar solicitudes |
| `responsable.demo@oftalmi.com` | Responsable de unidad | Revisar/aprobar según flujo |
| `finanzas.demo@oftalmi.com` | Finanzas | Revisar/aprobar según flujo |
| `cxp.demo@oftalmi.com` | Cuentas por pagar | Revisar pagos pendientes y ejecutar pago |
| `auditor.demo@oftalmi.com` | Auditor | Revisar trazabilidad/auditoría |
| `solicitante.otra.demo@oftalmi.com` | Solicitante otra empresa | Validar aislamiento por empresa |

---

## Rutas funcionales actuales

| Pantalla | URL | Validación esperada |
|---|---|---|
| Login | `http://localhost:8001/login/` | Permite autenticación por correo |
| Dashboard principal | `http://localhost:8001/dashboard/` | Muestra usuario, rol, empresa y unidad |
| Dashboard solicitudes | `http://localhost:8001/payment-requests/dashboard/` | Muestra resumen, accesos y últimas solicitudes |
| Solicitudes | `http://localhost:8001/payment-requests/` | Lista solicitudes y permite acceso al detalle |
| Pendientes por aprobar | `http://localhost:8001/payment-approvals/pending/` | Lista pasos pendientes para el rol autorizado |
| Auditoría | `http://localhost:8001/payment-approvals/audit/` | Permite revisar acciones críticas y aplicar filtros |
| Cuentas por pagar | `http://localhost:8001/payment-requests/accounts-payable/` | Muestra solicitudes aprobadas pendientes de pago |

---

## Flujo operativo esperado

```text
Solicitud de pago
  -> envío a aprobación
  -> revisión por responsables
  -> aprobación o rechazo
  -> Cuentas por Pagar
  -> registro de ejecución de pago
  -> auditoría transversal
```

Estados demo relevantes:

| Estado | Uso visual esperado |
|---|---|
| `DRAFT` | Solicitud borrador |
| `SUBMITTED` | Solicitud pendiente de aprobación |
| `APPROVED` | Solicitud aprobada pendiente de pago |
| `PAID` | Solicitud pagada con trazabilidad |
| `REJECTED` | Solicitud rechazada con auditoría |

---

## Checklist visual funcional por ruta

### 1. Login

URL:

```text
http://localhost:8001/login/
```

Validar:

- [ ] El formulario se muestra correctamente.
- [ ] El campo de usuario permite ingresar correo.
- [ ] La clave demo permite iniciar sesión.
- [ ] Al autenticar, redirige a una pantalla útil.
- [ ] El mensaje de error por credenciales inválidas es comprensible.

Hallazgo actual esperado:

```text
Funcional, pero visualmente básico. Debe entrar al backlog de branding.
```

---

### 2. Dashboard principal

URL:

```text
http://localhost:8001/dashboard/
```

Validar:

- [ ] Muestra el correo del usuario.
- [ ] Muestra el rol.
- [ ] Muestra la empresa principal.
- [ ] Muestra la unidad organizativa cuando aplique.
- [ ] Tiene salida clara hacia solicitudes/dashboard operativo.

Hallazgo actual esperado:

```text
Funcional como panel base, pero requiere mejor navegación global.
```

---

### 3. Dashboard operativo de solicitudes

URL:

```text
http://localhost:8001/payment-requests/dashboard/
```

Validar:

- [ ] Muestra accesos operativos.
- [ ] Muestra resumen por estado.
- [ ] Muestra pendientes de aprobación para el rol.
- [ ] Muestra últimas solicitudes.
- [ ] Los enlaces a auditoría, pendientes y CxP funcionan.

Hallazgo actual esperado:

```text
Es la pantalla más importante del MVP, pero requiere jerarquía visual, cards y mejor navegación.
```

---

### 4. Listado de solicitudes

URL:

```text
http://localhost:8001/payment-requests/
```

Validar:

- [ ] Lista solicitudes demo.
- [ ] Permite crear nueva solicitud.
- [ ] Permite entrar al detalle.
- [ ] Muestra empresa, beneficiario, concepto, monto, moneda y estado.
- [ ] Las fechas son legibles.

Hallazgo actual esperado:

```text
Funcional, pero la tabla requiere formato visual, badges de estado y mejores acciones.
```

---

### 5. Pendientes por aprobar

URL:

```text
http://localhost:8001/payment-approvals/pending/
```

Validar con usuarios de aprobación:

- [ ] Muestra solo pendientes autorizados para el rol.
- [ ] No muestra solicitudes de empresas no permitidas.
- [ ] Permite revisar la solicitud antes de aprobar/rechazar.
- [ ] Los mensajes de acceso denegado son coherentes.

Hallazgo actual esperado:

```text
Funcional. Conviene mejorar la explicación del paso de aprobación y estado de la solicitud.
```

---

### 6. Auditoría de acciones críticas

URL:

```text
http://localhost:8001/payment-approvals/audit/
```

Validar:

- [ ] Muestra historial transversal.
- [ ] Permite filtrar por acción.
- [ ] Permite filtrar por empresa.
- [ ] Permite filtrar por fecha desde/hasta.
- [ ] Enlaza a la solicitud asociada.
- [ ] Muestra usuario, rol y comentario.

Hallazgo actual esperado:

```text
Funcionalmente sólida. Es candidata a una mejora visual importante en branding.
```

---

### 7. Cuentas por pagar

URL:

```text
http://localhost:8001/payment-requests/accounts-payable/
```

Validar con usuario:

```text
cxp.demo@oftalmi.com
```

Validar:

- [ ] Muestra solicitudes aprobadas pendientes de pago.
- [ ] No permite acceso a roles no autorizados.
- [ ] Permite acceder al flujo de ejecución de pago.
- [ ] Luego de ejecutar pago, la solicitud cambia a estado pagado.
- [ ] La acción queda en auditoría.

Hallazgo actual esperado:

```text
Funcional. Requiere claridad visual para separar pendientes, pagadas y acciones ejecutables.
```

---

## Hallazgos visuales generales

| Área | Hallazgo | Prioridad |
|---|---|---:|
| Navegación global | El menú superior todavía es limitado | Alta |
| Branding | Falta identidad visual institucional Oftalmi | Alta |
| Tablas | Son funcionales pero visualmente básicas | Media |
| Estados | Faltan badges o etiquetas visuales por estado | Media |
| Botones | Falta consistencia entre acciones primarias/secundarias | Media |
| Mensajes | Los mensajes técnicos pueden mejorar para usuario operativo | Media |
| Dashboard | Necesita jerarquía visual ejecutiva | Alta |
| Auditoría | Funcional, pero debe verse más gerencial | Media |

---

## Pendientes antes de branding formal

Antes de entrar a branding institucional, conviene confirmar:

- [ ] Todas las rutas principales cargan sin errores.
- [ ] Los usuarios demo pueden validar su rol.
- [ ] El solicitante puede crear y enviar solicitud.
- [ ] Los aprobadores pueden ejecutar aprobación/rechazo.
- [ ] CxP puede registrar ejecución de pago.
- [ ] Auditor puede revisar trazabilidad.
- [ ] Las restricciones de acceso por rol son comprensibles.
- [ ] Las rutas documentadas coinciden con las rutas reales.

---

## Branding institucional pendiente

El branding queda fuera de F1-P28.

Debe abordarse en un punto posterior con alcance propio:

```text
Branding base institucional Oftalmi para Apps Emisiones
```

Alcance sugerido posterior:

- Crear CSS institucional reutilizable.
- Sacar estilos embebidos de `base.html`.
- Estandarizar header, navegación, cards, tablas y botones.
- Aplicar paleta institucional.
- Agregar badges por estado.
- Mejorar experiencia del dashboard operativo.
- Mantener lógica intacta.

---

## Criterio de cierre F1-P28

F1-P28 puede cerrarse cuando:

- [ ] Este documento queda creado en `docs/validacion_visual_funcional_fase1.md`.
- [ ] No hay cambios de modelos.
- [ ] No hay migraciones nuevas.
- [ ] La validación local estándar pasa correctamente.
- [ ] Backend CI en `develop` queda verde.

---

## Validación técnica estándar

Comandos recomendados:

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

Resultado esperado:

```text
ruff check . -> OK
System check -> OK
makemigrations --check --dry-run -> No changes detected
migrate -> No migrations to apply
tests -> OK
CI develop -> success
```

---

## Conclusión

El MVP operativo de Apps Emisiones ya tiene una base funcional suficiente para validación interna. El flujo principal existe, los datos demo permiten recorrerlo y la auditoría transversal da trazabilidad.

La principal brecha actual no es lógica sino de experiencia visual: navegación, jerarquía, identidad institucional, tablas, botones y estados. Esa brecha debe abordarse en un punto posterior de branding para no mezclar QA funcional con diseño institucional.
MD

printf '== F1-P28: Validacion visual funcional ==\n'
printf 'OK: documento creado en %s\n' "$DOC_FILE"
printf '\n== Archivos ==\n'
ls -la "$DOC_FILE"
