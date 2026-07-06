# Matriz efectiva de permisos - Vistas criticas

## Proposito

Documento operativo para auditar que cada vista critica del MVP tiene una decision explicita de acceso por rol.

## Roles

- ADMINISTRADOR
- SOLICITANTE
- RESPONSABLE_UNIDAD
- FINANZAS
- CUENTAS_POR_PAGAR
- AUDITOR

## Reglas efectivas

| Vista/capacidad | Administrador | Solicitante | Responsable Unidad | Finanzas | Cuentas por Pagar | Auditor |
|---|---:|---:|---:|---:|---:|---:|
| Dashboard solicitudes | Si | Si | Si | Si | Si | Si |
| Listado solicitudes | Si | Si | Si | Si | Si | Si |
| Crear solicitud | Si | Si | Si | Si | No | No |
| Enviar solicitud | Si | Si | Si | Si | No | No |
| Ver aprobaciones pendientes | Si | No | Si | Si | No | No |
| Aprobar/Rechazar | Si | No | Si | Si | No | No |
| Ver Cuentas por Pagar | Si | No | No | Si | Si | No |
| Registrar pago | Si | No | No | No | Si | No |
| Ver auditoria | Si | No | No | No | No | Si |

## Decision de diseno

La politica queda expresada en codigo mediante claves de permiso operativo. Esto evita que cada vista mantenga listas manuales de roles no auditables.

## Pendiente posterior recomendado

- F2-P04: Pruebas integradas por rol sobre rutas HTTP criticas.
- F2-P05: Navegacion condicionada por permisos efectivos.
- F2-P06: Gobierno administrativo de usuarios y roles.
