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

