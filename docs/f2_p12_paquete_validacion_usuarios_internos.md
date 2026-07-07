# F2-P12 - Paquete de validacion con usuarios internos

## Objetivo

Preparar un paquete operativo de validacion interna para que usuarios clave puedan revisar Apps Emisiones antes del cierre tecnico de Fase 2.

Este punto no introduce nuevas funcionalidades de negocio. Su objetivo es ordenar la validacion funcional, de permisos, reportes, exportacion y auditoria con usuarios internos.

## Alcance

Incluye:

- Guia de acceso para usuarios internos.
- Rutas funcionales a validar.
- Usuarios demo de referencia.
- Casos de prueba funcionales por rol.
- Matriz de evidencias esperadas.
- Criterios de aceptacion para continuar hacia F2-P13.
- Riesgos y observaciones para UAT.

No incluye:

- Modelos nuevos.
- Migraciones nuevas.
- Cambios de flujo aprobatorio.
- Cambios de permisos backend.
- Integraciones externas.

## Ambiente de validacion

| Elemento | Valor |
|---|---|
| Proyecto | Apps Emisiones |
| URL local | `http://localhost:8001` |
| Rama base | `develop` |
| Login | `http://localhost:8001/login/` |
| Credencial demo comun | `Demo123456*` |

## Usuarios demo

| Usuario | Rol | Empresa | Uso esperado |
|---|---|---|---|
| `douglas.chirinos@oftalmi.com` | ADMINISTRADOR | Laboratorios Oftalmi | Validacion transversal y supervision general. |
| `solicitante.demo@oftalmi.com` | SOLICITANTE | Laboratorios Oftalmi | Crear, consultar y enviar solicitudes. |
| `responsable.demo@oftalmi.com` | RESPONSABLE_UNIDAD | Laboratorios Oftalmi | Revisar pendientes de aprobacion asignados. |
| `finanzas.demo@oftalmi.com` | FINANZAS | Laboratorios Oftalmi | Revisar aprobaciones, reportes, CxP y visibilidad financiera. |
| `cxp.demo@oftalmi.com` | CUENTAS_POR_PAGAR | Laboratorios Oftalmi | Revisar Cuentas por Pagar y registrar ejecucion de pago. |
| `auditor.demo@oftalmi.com` | AUDITOR | Laboratorios Oftalmi | Revisar auditoria, reportes y trazabilidad. |
| `solicitante.otra.demo@oftalmi.com` | SOLICITANTE | Inversiones Demo Oftalmi | Validar separacion por empresa. |

## Rutas funcionales a validar

| Modulo | Ruta |
|---|---|
| Login | `/login/` |
| Dashboard autenticado | `/dashboard/` |
| Dashboard solicitudes | `/payment-requests/dashboard/` |
| Listado solicitudes | `/payment-requests/` |
| Nueva solicitud | `/payment-requests/new/` |
| Pendientes aprobacion | `/payment-approvals/pending/` |
| Cuentas por pagar | `/payment-requests/accounts-payable/` |
| Reporte operativo | `/payment-requests/reports/basic/` |
| Exportacion reporte CSV | `/payment-requests/reports/basic/export/` |
| Auditoria | `/payment-approvals/audit/` |

## Validacion por rol

### Administrador

- Puede acceder al dashboard y al listado.
- Puede consultar solicitudes visibles.
- Puede acceder a reportes.
- Puede acceder a auditoria.
- Puede validar comportamiento transversal sin romper alcance por empresa.

### Solicitante

- Puede iniciar sesion.
- Puede ver dashboard y listado permitido.
- Puede crear una solicitud.
- No debe ver ni acceder a Cuentas por Pagar.
- No debe ver ni acceder a Auditoria.
- No debe registrar pagos.

### Responsable de unidad

- Puede revisar dashboard y pendientes de aprobacion.
- Puede aprobar o rechazar pasos asignados.
- No debe registrar pagos.
- No debe acceder a Auditoria.

### Finanzas

- Puede revisar dashboard, pendientes y reportes.
- Puede consultar Cuentas por Pagar segun matriz operativa.
- Puede exportar reporte operativo.
- No debe registrar pago si no pertenece a Cuentas por Pagar.
- No debe acceder al workbench de Auditoria salvo decision posterior de negocio.

### Cuentas por Pagar

- Puede revisar Cuentas por Pagar.
- Puede registrar ejecucion de pago sobre solicitudes aprobadas.
- Puede consultar reportes operativos.
- No debe aprobar pasos funcionales.
- No debe acceder al workbench de Auditoria.

### Auditor

- Puede acceder a Auditoria.
- Puede consultar reportes operativos.
- Debe ver trazabilidad por empresa segun alcance.
- No debe crear solicitudes.
- No debe aprobar, rechazar ni registrar pagos.

## Casos funcionales de referencia

| Caso | Usuario | Resultado esperado |
|---|---|---|
| Login correcto | Todos los usuarios demo | Acceso al sistema. |
| Crear solicitud | Solicitante | Solicitud en borrador o flujo inicial. |
| Enviar solicitud | Solicitante | Cambio de estado y generacion de pasos. |
| Revisar pendientes | Responsable / Finanzas | Visualizacion de pasos asignados por rol y empresa. |
| Aprobar solicitud | Responsable / Finanzas | Accion registrada y avance de estado. |
| Rechazar solicitud | Responsable / Finanzas | Rechazo con comentario obligatorio y auditoria. |
| Consultar CxP | Finanzas / CxP | Solicitudes aprobadas pendientes de pago. |
| Registrar pago | CxP | Solicitud pagada y auditoria de pago ejecutado. |
| Consultar reporte | Finanzas / CxP / Auditor | Filtros por estado, empresa y fecha. |
| Exportar CSV | Finanzas / CxP / Auditor | CSV con el mismo alcance del reporte. |
| Consultar auditoria | Auditor / Administrador | Filtros, resumenes y detalle de acciones criticas. |
| Acceso no autorizado | Roles no permitidos | Respuesta 403 o ausencia del enlace en menu. |

## Evidencias recomendadas

Para cada usuario interno que valide, registrar:

- Usuario/rol utilizado.
- Fecha de validacion.
- Navegador usado.
- Ruta validada.
- Resultado esperado.
- Resultado observado.
- Captura de pantalla si aplica.
- Incidencia o comentario.
- Severidad: bloqueante, alta, media, baja.
- Decision: aprobado, aprobado con observaciones, rechazado.

## Criterios de aceptacion de F2-P12

F2-P12 se considera cerrado cuando:

- El paquete de validacion interna queda documentado.
- Las rutas principales quedan listadas.
- Los usuarios demo y roles quedan documentados.
- Los casos de prueba por rol quedan definidos.
- Los criterios de aceptacion quedan claros.
- No se generan migraciones.
- La suite tecnica principal queda en verde antes del commit.

## Resultado esperado

Al finalizar F2-P12, el proyecto queda listo para F2-P13: cierre tecnico de Fase 2, consolidando evidencias, pendientes y condiciones para piloto interno controlado.
