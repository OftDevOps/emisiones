# F2-P01 - Definicion y arranque tecnico de Fase 2

## Proposito

Este documento formaliza el arranque tecnico de la Fase 2 de Apps Emisiones, despues del cierre funcional de Fase 1 y del bloque F1-BR01 de branding base institucional Oftalmi.

La Fase 2 debe evolucionar el MVP operativo hacia una solucion mas robusta para control interno, gestion financiera, trazabilidad, permisos, reportes y gobierno operacional.

## Estado de entrada

La Fase 2 inicia con estas bases ya cerradas:

- Fase 1 cerrada tecnicamente hasta F1-P30.
- Branding base institucional cerrado en F1-BR01.
- Rama estable: `develop`.
- Flujo Git: `feature/* -> develop -> main`.
- Puerto local de Apps Emisiones: `http://localhost:8001`.
- Login correcto: `/login/`.
- CI verde en `develop` al cierre de Fase 1.

## Reglas operativas obligatorias

- No usar Codex para continuar fases de este proyecto.
- Trabajar con comandos directos de terminal y scripts ejecutables.
- Los scripts deben ubicarse directamente en:

```bash
/home/dchirinos/oftalmiIA/emisiones/emisiones/scripts/
```

- Antes de validar con Docker, desconectar NordVPN.
- Al terminar validacion, reconectar NordVPN a United States.
- No mezclar rutas ni puertos de otros proyectos.

## Alcance macro de Fase 2

La Fase 2 debe priorizar madurez operacional, control y usabilidad ejecutiva sobre expansion desordenada de funcionalidades.

Ejes principales:

1. Seguridad y permisos por rol.
2. Endurecimiento del flujo de solicitudes.
3. Mejoras de aprobacion y rechazo.
4. Reportes operativos y financieros.
5. Auditoria y trazabilidad extendida.
6. Mejoras visuales puntuales sobre branding base.
7. Preparacion para validacion con usuarios internos.
8. Documentacion tecnica viva.

## Objetivos funcionales

- Consolidar reglas de visibilidad por rol, empresa y estado.
- Mejorar el control de transiciones del ciclo de vida de solicitudes.
- Preparar reportes para supervision financiera y auditoria.
- Reducir ambiguedades operativas en bandejas, dashboards y acciones.
- Fortalecer trazabilidad de decisiones y ejecuciones.
- Crear base documental suficiente para validacion ejecutiva.

## Objetivos tecnicos

- Mantener el backend validado con `ruff`, `check`, `makemigrations --check`, `migrate` y tests.
- Evitar migraciones innecesarias.
- Mantener cambios pequenos, verificables y con documentacion por punto.
- No introducir deuda visual ni reglas de negocio ocultas en templates.
- Mantener permisos en vistas, pruebas y documentacion.

## Backlog inicial propuesto

| Punto | Nombre | Tipo | Prioridad |
|---|---|---|---|
| F2-P01 | Definicion y arranque tecnico de Fase 2 | Documentacion/Gobierno | Alta |
| F2-P02 | Matriz formal de roles, permisos y visibilidad | Seguridad/Documentacion | Alta |
| F2-P03 | Endurecimiento de permisos por rol en vistas criticas | Seguridad/Codigo | Alta |
| F2-P04 | Pruebas integradas de permisos por rol y empresa | Calidad/Codigo | Alta |
| F2-P05 | Estados y transiciones formales del ciclo de solicitud | Negocio/Documentacion | Alta |
| F2-P06 | Validacion tecnica de transiciones permitidas | Negocio/Codigo | Alta |
| F2-P07 | Mejoras del dashboard operativo por rol | UX/Codigo | Media |
| F2-P08 | Reporte basico de solicitudes por estado, empresa y fecha | Reportes/Codigo | Media |
| F2-P09 | Exportacion CSV/Excel operativa basica | Reportes/Codigo | Media |
| F2-P10 | Auditoria extendida para eventos de Fase 2 | Auditoria/Codigo | Media |
| F2-P11 | Preparacion de validacion con usuarios internos | Gestion/Documentacion | Media |
| F2-P12 | Cierre tecnico de Fase 2 | Documentacion/Gobierno | Alta |

## Criterios de aceptacion de Fase 2

La Fase 2 podra considerarse cerrada cuando:

- Exista matriz de roles/permisos documentada y probada.
- Las vistas criticas respeten rol, empresa y estado.
- Las transiciones principales del flujo esten documentadas y validadas.
- Existan reportes operativos basicos para supervision.
- La auditoria cubra acciones criticas nuevas o reforzadas.
- Existan pruebas automatizadas suficientes para permisos y flujo.
- La documentacion tecnica y operativa este actualizada.
- `develop` este limpio y con validacion verde.

## Fuera de alcance inicial

Queda fuera de F2-P01 y debe evaluarse en puntos posteriores:

- Integracion bancaria real.
- Firma electronica avanzada.
- API publica externa.
- Multiempresa avanzada con parametrizacion completa.
- Workflow dinamico configurable por usuario final.
- Despliegue productivo definitivo.

## Riesgos iniciales

| Riesgo | Impacto | Mitigacion |
|---|---|---|
| Crecimiento funcional sin matriz de permisos formal | Alto | Iniciar Fase 2 con roles y permisos |
| Templates con logica de negocio dispersa | Medio | Centralizar reglas en vistas/modelos/servicios |
| Reportes sin definicion ejecutiva clara | Medio | Empezar con reportes basicos y validables |
| Confusion entre proyectos locales | Medio | Mantener puerto 8001 y rutas documentadas |
| Dependencia de validacion manual | Alto | Reforzar tests integrados por rol/estado |

## Bloque de validacion estandar

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

## Siguiente punto recomendado

Despues de cerrar F2-P01, el siguiente paso logico es:

```text
F2-P02 -> Matriz formal de roles, permisos y visibilidad
```

Objetivo de F2-P02: documentar con precision que puede ver y hacer cada rol antes de tocar codigo de permisos.
