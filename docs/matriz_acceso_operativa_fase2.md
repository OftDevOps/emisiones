# Matriz de acceso operativa - Apps Emisiones Fase 2

## Objetivo

Este documento funciona como contrato operativo de permisos para Apps Emisiones durante la Fase 2.

Debe consultarse antes de crear nuevas vistas, acciones, workbenches o endpoints.

---

## Roles

```text
ADMINISTRADOR
SOLICITANTE
RESPONSABLE_UNIDAD
FINANZAS
CUENTAS_POR_PAGAR
AUDITOR
```

---

## Acciones criticas

| Accion critica | Roles permitidos | Resultado esperado si no tiene permiso |
|---|---|---|
| Crear solicitud | ADMINISTRADOR, SOLICITANTE | 403 o redireccion controlada |
| Enviar solicitud | ADMINISTRADOR, SOLICITANTE propietario | 403 / 404 segun exposicion |
| Aprobar solicitud | ADMINISTRADOR, RESPONSABLE_UNIDAD, FINANZAS segun paso | 403 |
| Rechazar solicitud | ADMINISTRADOR, RESPONSABLE_UNIDAD, FINANZAS segun paso | 403 |
| Ver pendientes de aprobacion | ADMINISTRADOR, RESPONSABLE_UNIDAD, FINANZAS | 403 |
| Ver cuentas por pagar | ADMINISTRADOR, FINANZAS, CUENTAS_POR_PAGAR | 403 |
| Registrar pago | ADMINISTRADOR, CUENTAS_POR_PAGAR | 403 |
| Ver auditoria | ADMINISTRADOR, AUDITOR | 403 |

---

## Politica practica

- El rol `ADMINISTRADOR` puede operar transversalmente.
- El rol `SOLICITANTE` no debe aprobar, pagar ni consultar auditoria transversal.
- El rol `RESPONSABLE_UNIDAD` participa en aprobaciones, no en pagos.
- El rol `FINANZAS` puede tener visibilidad financiera y aprobacion financiera si el flujo lo exige.
- El rol `CUENTAS_POR_PAGAR` ejecuta pagos, no aprueba pasos funcionales salvo decision posterior.
- El rol `AUDITOR` consulta trazabilidad, no ejecuta acciones de negocio.

---

## Regla para desarrollo futuro

Toda nueva funcionalidad debe declarar:

1. Roles permitidos.
2. Accion principal.
3. Nivel de acceso: lectura, escritura, aprobacion, ejecucion o auditoria.
4. Resultado esperado para acceso no autorizado.
5. Prueba automatizada minima.
