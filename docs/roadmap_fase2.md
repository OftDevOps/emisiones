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
| 4 | F2-P04 | Context processor de navegacion por rol |
| 4B | F2-P04B | Visibilidad real de menu por rol en base.html |
| 5 | F2-P05 | Pruebas integradas de navegacion por rol / matriz UX-permisos |
| 6 | F2-P06 | Estados y transiciones documentadas |
| 7 | F2-P07 | Validacion tecnica de transiciones |
| 8 | F2-P08 | Dashboard operativo mejorado por rol |
| 9 | F2-P09 | Cerrado - Reporte basico por estado, empresa y fecha |
| 10 | F2-P10 | Cerrado - Exportacion operativa basica |
| 11 | F2-P11 | Cerrado - Auditoria extendida |
| 12 | F2-P12 | Paquete de validacion con usuarios internos |
| 13 | F2-P13 | Cierre tecnico de Fase 2 |

## Decision de arquitectura

Fase 2 no debe arrancar creando funcionalidades sueltas. Debe arrancar por matriz de permisos porque impacta seguridad, visibilidad, dashboards, reportes y auditoria.

## Siguiente accion

Ejecutar F2-P12 con foco en:

- Paquete de validacion con usuarios internos.
- Escenarios operativos por rol.
- Evidencias de flujos criticos.
- Checklist UAT para piloto interno.
- Sin modelos nuevos salvo necesidad justificada.
- Sin migraciones salvo necesidad justificada.
