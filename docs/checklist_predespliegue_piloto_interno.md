# Apps Emisiones - Checklist predespliegue piloto interno

## Proposito

Checklist operativo para preparar el despliegue piloto interno de Apps Emisiones despues del cierre tecnico de Fase 2.

Este documento no introduce funcionalidad nueva. Su objetivo es reducir riesgo operativo antes de exponer el sistema a usuarios internos.

## Alcance del piloto

El piloto interno cubre:

- Login de usuarios internos.
- Navegacion por rol.
- Solicitudes de pago.
- Documentos asociados.
- Flujo de aprobaciones.
- Registro de ejecucion de pagos.
- Dashboard operativo.
- Reportes y exportacion basica.
- Auditoria extendida.
- Paquete UAT de validacion interna.

Fuera de alcance:

- Nuevos modelos de datos.
- Nuevas migraciones.
- Cambios funcionales.
- Integraciones externas.
- Automatizacion bancaria.
- Firma digital.
- Alta disponibilidad.

## Precondiciones tecnicas

| Item | Estado esperado | Evidencia |
| --- | --- | --- |
| Rama base | `develop` actualizada | `git log --oneline --max-count=5` |
| Validacion tecnica | OK | `ruff`, `check`, migraciones, tests |
| Migraciones | Sin pendientes | `makemigrations --check --dry-run` |
| Base de datos | PostgreSQL disponible | `docker compose ps` |
| Variables de entorno | Revisadas | `.env` fuera de Git |
| Superusuario | Disponible | Usuario admin validado |
| Usuarios piloto | Creados | Lista interna UAT |
| Roles | Asignados | Matriz de usuarios/roles |
| Backup previo | Ejecutado | Archivo `.dump` o `.sql` |
| Rollback | Documentado | Plan de reversa aprobado |

## Checklist de ambiente

- [ ] Confirmar servidor o equipo destino del piloto.
- [ ] Confirmar puerto publicado.
- [ ] Confirmar URL interna.
- [ ] Confirmar conectividad desde puestos piloto.
- [ ] Confirmar acceso al repositorio Git.
- [ ] Confirmar acceso a Docker y Docker Compose.
- [ ] Confirmar espacio disponible en disco.
- [ ] Confirmar politica de respaldo.
- [ ] Confirmar ventana de despliegue.
- [ ] Confirmar responsables de soporte durante piloto.

## Checklist de seguridad minima

- [ ] `DEBUG=False` en ambiente piloto.
- [ ] `SECRET_KEY` no versionada.
- [ ] `ALLOWED_HOSTS` restringido a host/IP del piloto.
- [ ] Credenciales de base de datos fuera de Git.
- [ ] Usuario admin con clave robusta.
- [ ] Usuarios reales sin claves compartidas.
- [ ] Roles revisados antes de UAT.
- [ ] No exponer puerto de base de datos fuera del host si no es necesario.
- [ ] Backups protegidos fuera del directorio publico.

## Checklist de datos demo/UAT

- [ ] Empresas base disponibles.
- [ ] Beneficiarios de prueba disponibles.
- [ ] Usuarios piloto por rol disponibles.
- [ ] Solicitudes de pago demo creadas.
- [ ] Documentos de prueba adjuntos.
- [ ] Casos aprobados, rechazados y pendientes preparados.
- [ ] Casos de auditoria verificables preparados.
- [ ] Datos sensibles reales minimizados o anonimizados.

## Checklist de validacion funcional

- [ ] Login exitoso.
- [ ] Logout exitoso.
- [ ] Acceso por rol correcto.
- [ ] Usuario sin permiso recibe 403 donde aplique.
- [ ] Creacion de solicitud de pago.
- [ ] Carga de documentos.
- [ ] Envio a aprobacion.
- [ ] Aprobacion por rol autorizado.
- [ ] Rechazo por rol autorizado.
- [ ] Registro de pago por rol autorizado.
- [ ] Dashboard visible para roles permitidos.
- [ ] Reporte operativo filtra por estado, empresa y fecha.
- [ ] Exportacion basica genera archivo.
- [ ] Auditoria registra acciones criticas.

## Criterio de salida del predespliegue

El piloto puede arrancar si:

- La validacion tecnica completa esta en OK.
- El backup previo existe y fue verificado.
- El rollback esta documentado.
- Los usuarios piloto estan definidos.
- Los responsables de soporte conocen el flujo.
- El checklist funcional minimo fue revisado.
