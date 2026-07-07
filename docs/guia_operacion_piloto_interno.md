# Apps Emisiones - Guia de operacion inicial del piloto interno

## Proposito

Guia practica para operar el piloto interno de Apps Emisiones con control, trazabilidad y soporte basico.

## Roles operativos del piloto

| Rol | Responsabilidad |
| --- | --- |
| Responsable TI | Mantener ambiente, backups, logs y soporte tecnico |
| Usuario solicitante | Crear solicitudes de pago demo o reales controladas |
| Usuario aprobador | Validar flujo de aprobacion/rechazo |
| Cuentas por pagar | Validar bandeja operativa y registro de pago |
| Auditor/administrador | Validar dashboard, reportes, exportacion y auditoria |

## Apertura diaria

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

git status
git log --oneline --max-count=5 --decorate
docker compose ps
docker compose exec backend python manage.py check
```

## Operacion diaria

- Confirmar disponibilidad de la URL piloto.
- Confirmar login de al menos un usuario administrativo.
- Registrar casos UAT ejecutados.
- Registrar errores con evidencia.
- No corregir en caliente sin separar incidente, causa y decision.

## Cierre diario

- Revisar logs.
- Ejecutar backup.
- Registrar hallazgos.
- Clasificar incidentes.
- Definir si el piloto continua, se pausa o requiere correccion.

## Control de cambios durante piloto

Todo cambio debe cumplir:

- Rama identificada.
- Motivo documentado.
- Validacion focal.
- Validacion completa si afecta flujo critico.
- Commit pequeno.
- Push a `develop` si queda aprobado.
- Actualizacion documental si cambia operacion.

## Decision de salida del piloto

Al finalizar el piloto se debe decidir una de estas rutas:

1. Aprobar pase a despliegue controlado.
2. Extender piloto con correcciones menores.
3. Pausar por brechas funcionales.
4. Reabrir fase tecnica especifica.

## Evidencia minima de cierre

- Checklist predespliegue firmado o validado.
- Casos UAT ejecutados.
- Incidentes registrados.
- Backups generados.
- Smoke test final.
- Decision formal del responsable.
