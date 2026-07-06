# Roadmap de Fase 2 - Apps Emisiones

## Enfoque ejecutivo

La Fase 2 convierte el MVP de Apps Emisiones en una plataforma mas controlada, auditable y preparada para validacion interna.

Prioridad estrategica: primero control y permisos; luego reportes; finalmente validacion con usuarios.

## Secuencia propuesta

| Orden | Punto | Resultado esperado |
|---|---|---|
| 1 | F2-P01 | Arranque tecnico y gobierno de Fase 2 documentado |
| 2 | F2-P02 | Matriz de roles, permisos y visibilidad |
| 3 | F2-P03 | Permisos reforzados en vistas criticas |
| 4 | F2-P04 | Tests integrados de permisos |
| 5 | F2-P05 | Estados y transiciones documentadas |
| 6 | F2-P06 | Validacion tecnica de transiciones |
| 7 | F2-P07 | Dashboard operativo mejorado por rol |
| 8 | F2-P08 | Reporte basico por estado, empresa y fecha |
| 9 | F2-P09 | Exportacion operativa basica |
| 10 | F2-P10 | Auditoria extendida |
| 11 | F2-P11 | Paquete de validacion con usuarios internos |
| 12 | F2-P12 | Cierre tecnico de Fase 2 |

## Decision de arquitectura

Fase 2 no debe arrancar creando funcionalidades sueltas. Debe arrancar por matriz de permisos porque impacta seguridad, visibilidad, dashboards, reportes y auditoria.

## Siguiente accion

Ejecutar F2-P02 con foco en:

- Roles existentes.
- Acciones permitidas por rol.
- Visibilidad por empresa.
- Visibilidad por estado de solicitud.
- Rutas criticas.
- Pruebas esperadas.
