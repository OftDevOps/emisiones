# DevOps - Sistema de Rutas de Pago Oftalmi

## Principios

El proyecto debe abordarse con ingeniería DevOps desde el inicio.

## Alcance DevOps inicial

- Docker Compose para desarrollo.
- Separación de ambientes.
- Variables en `.env`.
- `.env.example` versionado.
- Healthchecks.
- Logs centralizados.
- Scripts de backup y restore.
- Preparación para CI/CD.
- Documentación operativa.

## Ambientes

- development
- staging
- production

## Reglas

- No se versionan secretos.
- Todo cambio debe pasar por Git.
- Toda configuración sensible va en variables de entorno.
- La base de datos debe tener backup y restore documentado.
- El despliegue debe ser repetible.
