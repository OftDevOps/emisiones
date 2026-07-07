# Apps Emisiones - Variables de entorno para piloto interno

## Proposito

Definir las variables minimas esperadas para ejecutar Apps Emisiones en un ambiente de piloto interno.

Este documento es una guia. No debe contener secretos reales.

## Variables Django

```env
DJANGO_ENV=pilot
DEBUG=False
SECRET_KEY=change-me-with-secure-value
ALLOWED_HOSTS=localhost,127.0.0.1,IP_O_HOST_INTERNO
CSRF_TRUSTED_ORIGINS=http://IP_O_HOST_INTERNO:8001
```

Notas:

- `SECRET_KEY` debe generarse de forma segura y no debe subirse a Git.
- `DEBUG=False` es obligatorio para piloto.
- `ALLOWED_HOSTS` debe restringirse al host real del piloto.
- Si se usa HTTPS, actualizar `CSRF_TRUSTED_ORIGINS` a `https://...`.

## Variables de base de datos

```env
POSTGRES_DB=emisiones
POSTGRES_USER=emisiones_user
POSTGRES_PASSWORD=change-me
POSTGRES_HOST=db
POSTGRES_PORT=5432
```

Notas:

- No usar claves triviales.
- No reutilizar credenciales de desarrollo.
- Documentar quien custodia las credenciales.

## Variables de aplicacion

```env
APP_NAME=Apps Emisiones
APP_PORT=8001
APP_TIMEZONE=America/Caracas
```

Notas:

- El puerto local historico del proyecto es `8001`.
- La URL de login esperada es `/login/`.

## Variables de correo opcionales

```env
EMAIL_HOST=
EMAIL_PORT=587
EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=
EMAIL_USE_TLS=True
DEFAULT_FROM_EMAIL=
```

Notas:

- Mantener vacias si el piloto no usa notificaciones por correo.
- No bloquear el piloto por correo si no es parte del alcance UAT.

## Politica de archivo `.env`

- Debe existir en el servidor o equipo del piloto.
- No debe versionarse.
- Debe tener permisos restrictivos.
- Debe respaldarse de forma segura si se requiere reconstruir el ambiente.
- Cambios de `.env` deben quedar registrados en bitacora operativa.
