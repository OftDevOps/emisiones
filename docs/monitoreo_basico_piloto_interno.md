# Apps Emisiones - Monitoreo basico piloto interno

## Proposito

Definir observabilidad minima para operar el piloto interno sin sobredimensionar la plataforma.

## Indicadores tecnicos

- Estado de contenedores.
- Uso de disco.
- Uso de memoria.
- Logs recientes del backend.
- Logs recientes de base de datos.
- Errores HTTP 500.
- Eventos 403 esperados por permisos.
- Tiempo de respuesta percibido por usuarios piloto.

## Comandos base

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

docker compose ps
docker compose logs --tail=100 backend
docker compose logs --tail=100 db
df -h
free -h
```

## Revision de errores

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

docker compose logs backend | grep -i "error\|exception\|traceback" | tail -50
```

Nota: algunos `PermissionDenied` pueden ser esperados durante pruebas de permisos. El foco operativo son errores 500, excepciones no controladas y fallas recurrentes.

## Frecuencia sugerida durante piloto

- Inicio de jornada: revisar contenedores, espacio y logs.
- Durante UAT: revisar logs despues de pruebas criticas.
- Cierre de jornada: generar backup y registrar hallazgos.

## Registro minimo de incidentes

| Fecha | Usuario | Rol | Accion | Error | Evidencia | Decision |
| --- | --- | --- | --- | --- | --- | --- |
| YYYY-MM-DD | Nombre | Rol | Accion ejecutada | Error observado | Captura/log | Pendiente/Corregido/Descartado |

## Criterio de escalamiento

Escalar si:

- Hay error 500 reproducible.
- Un usuario accede a una vista no autorizada.
- Una solicitud cambia a estado incorrecto.
- La exportacion falla de forma consistente.
- La auditoria no registra acciones criticas.
- La base de datos presenta errores de escritura.
