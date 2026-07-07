# Checklist de validacion interna - Apps Emisiones Fase 2

## Datos de la sesion

| Campo | Valor |
|---|---|
| Validador |  |
| Area |  |
| Rol usado |  |
| Usuario usado |  |
| Fecha |  |
| Navegador |  |
| Ambiente | Local / UAT |

## Checklist general

| Item | Resultado | Observacion |
|---|---|---|
| Puede iniciar sesion con usuario asignado |  |  |
| El menu muestra solo opciones permitidas para el rol |  |  |
| Las rutas no autorizadas devuelven bloqueo controlado |  |  |
| El dashboard carga sin errores visibles |  |  |
| El listado de solicitudes respeta el alcance del usuario |  |  |
| Los datos de otra empresa no aparecen indebidamente |  |  |

## Solicitudes de pago

| Item | Resultado | Observacion |
|---|---|---|
| Crear solicitud funciona para rol autorizado |  |  |
| Enviar solicitud funciona para rol autorizado |  |  |
| El detalle muestra datos principales correctamente |  |  |
| La trazabilidad de acciones se muestra en el detalle |  |  |
| La cancelacion o rechazo exige motivo cuando aplica |  |  |

## Aprobaciones

| Item | Resultado | Observacion |
|---|---|---|
| La bandeja de pendientes carga para roles autorizados |  |  |
| Solo aparecen pendientes del rol/empresa correspondiente |  |  |
| Aprobar registra accion correctamente |  |  |
| Rechazar registra accion y comentario correctamente |  |  |
| Roles no autorizados no pueden aprobar por URL directa |  |  |

## Cuentas por Pagar

| Item | Resultado | Observacion |
|---|---|---|
| La bandeja de CxP carga para roles autorizados |  |  |
| Solo aparecen solicitudes aprobadas pendientes de pago |  |  |
| Registrar pago funciona para CxP |  |  |
| El pago cambia la solicitud a pagada |  |  |
| La referencia bancaria queda visible en trazabilidad |  |  |
| Roles no autorizados no pueden registrar pago |  |  |

## Reportes y exportacion

| Item | Resultado | Observacion |
|---|---|---|
| El reporte operativo carga para roles autorizados |  |  |
| Filtrar por estado funciona |  |  |
| Filtrar por empresa respeta alcance |  |  |
| Filtrar por fecha funciona |  |  |
| Exportar CSV respeta los mismos filtros |  |  |
| El CSV abre correctamente en Excel/LibreOffice |  |  |

## Auditoria

| Item | Resultado | Observacion |
|---|---|---|
| Auditoria carga para Auditor/Administrador |  |  |
| Filtro por accion funciona |  |  |
| Filtro por empresa funciona |  |  |
| Filtro por usuario funciona |  |  |
| Filtro por concepto funciona |  |  |
| Resumenes por accion/empresa son coherentes |  |  |
| El detalle muestra fecha, solicitud, empresa, concepto, accion, usuario, rol y comentario |  |  |

## Decision de validacion

Seleccione una opcion:

- [ ] Aprobado sin observaciones.
- [ ] Aprobado con observaciones menores.
- [ ] Requiere correcciones antes de piloto.
- [ ] Rechazado por bloqueo funcional.

## Observaciones generales

```text

```

## Incidencias detectadas

| Severidad | Modulo | Descripcion | Evidencia | Responsable sugerido |
|---|---|---|---|---|
|  |  |  |  |  |
