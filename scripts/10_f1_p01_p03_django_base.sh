#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="emisiones"
EXPECTED_MARKER="docker-compose.yml"

info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$1"; }
err() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$1" >&2; }

if [ ! -f "$EXPECTED_MARKER" ]; then
  err "Este script debe ejecutarse desde la raiz del repo emisiones, donde existe docker-compose.yml"
  err "Ruta actual: $(pwd)"
  exit 1
fi

info "Aplicando Fase 1 - P01/P02/P03: Django base + settings por ambiente + Docker/PostgreSQL"

mkdir -p backend/config/settings backend/apps backend/static backend/media backend/templates backend/requirements docker nginx scripts docs/06-backlog .github/workflows logs backups

touch backend/config/__init__.py backend/config/settings/__init__.py backend/apps/__init__.py

cat > backend/manage.py <<'PY'
#!/usr/bin/env python
"""Django administrative utility for the Emisiones project."""
import os
import sys


def main() -> None:
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.dev")
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "No se pudo importar Django. Verifique que las dependencias esten instaladas."
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == "__main__":
    main()
PY
chmod +x backend/manage.py

cat > backend/config/settings/base.py <<'PY'
"""Base settings for the Emisiones project."""
from pathlib import Path
from decouple import Csv, config

BASE_DIR = Path(__file__).resolve().parent.parent.parent
PROJECT_ROOT = BASE_DIR.parent

APP_NAME = config("APP_NAME", default="emisiones")
APP_ENV = config("APP_ENV", default="local")
SECRET_KEY = config("SECRET_KEY", default="unsafe-dev-secret-key-change-me")
DEBUG = config("DEBUG", default=False, cast=bool)
ALLOWED_HOSTS = config("ALLOWED_HOSTS", default="localhost,127.0.0.1", cast=Csv())
CSRF_TRUSTED_ORIGINS = config("CSRF_TRUSTED_ORIGINS", default="http://localhost:8001,http://127.0.0.1:8001", cast=Csv())

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": config("POSTGRES_DB", default="emisiones_db"),
        "USER": config("POSTGRES_USER", default="emisiones_user"),
        "PASSWORD": config("POSTGRES_PASSWORD", default="change-me"),
        "HOST": config("POSTGRES_HOST", default="db"),
        "PORT": config("POSTGRES_PORT", default="5432"),
    }
}

LANGUAGE_CODE = "es"
LANGUAGES = [
    ("es", "Espanol"),
    ("en", "English"),
]
TIME_ZONE = "America/Caracas"
USE_I18N = True
USE_TZ = True

STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STATICFILES_DIRS = [BASE_DIR / "static"] if (BASE_DIR / "static").exists() else []

MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_HTTPONLY = False
X_FRAME_OPTIONS = "DENY"
SECURE_CONTENT_TYPE_NOSNIFF = True

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {
        "console": {"class": "logging.StreamHandler"},
    },
    "root": {
        "handlers": ["console"],
        "level": config("LOG_LEVEL", default="INFO"),
    },
}
PY

cat > backend/config/settings/dev.py <<'PY'
"""Development settings."""
from .base import *  # noqa: F401,F403

DEBUG = True
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False
PY

cat > backend/config/settings/prod.py <<'PY'
"""Production settings."""
from .base import *  # noqa: F401,F403
from decouple import config

DEBUG = False
SESSION_COOKIE_SECURE = config("SESSION_COOKIE_SECURE", default=True, cast=bool)
CSRF_COOKIE_SECURE = config("CSRF_COOKIE_SECURE", default=True, cast=bool)
SECURE_SSL_REDIRECT = config("SECURE_SSL_REDIRECT", default=True, cast=bool)
SECURE_HSTS_SECONDS = config("SECURE_HSTS_SECONDS", default=31536000, cast=int)
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
PY

cat > backend/config/urls.py <<'PY'
"""URL configuration for Emisiones."""
from django.contrib import admin
from django.http import JsonResponse
from django.urls import path


def healthcheck(request):
    return JsonResponse({"status": "ok", "service": "emisiones"})


def home(request):
    return JsonResponse({"app": "Sistema de Rutas de Pago Oftalmi", "status": "running"})


urlpatterns = [
    path("", home, name="home"),
    path("health/", healthcheck, name="healthcheck"),
    path("admin/", admin.site.urls),
]
PY

cat > backend/config/wsgi.py <<'PY'
"""WSGI config for Emisiones."""
import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.dev")

application = get_wsgi_application()
PY

cat > backend/config/asgi.py <<'PY'
"""ASGI config for Emisiones."""
import os

from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.dev")

application = get_asgi_application()
PY

cat > backend/requirements/base.txt <<'REQ'
Django==5.0.6
djangorestframework==3.15.2
psycopg[binary]==3.2.1
python-decouple==3.8
gunicorn==22.0.0
whitenoise==6.7.0
celery==5.4.0
redis==5.0.7
REQ

cat > backend/requirements/dev.txt <<'REQ'
-r base.txt
pytest==8.3.2
pytest-django==4.8.0
ruff==0.5.5
REQ

cat > backend/requirements/prod.txt <<'REQ'
-r base.txt
REQ

cat > docker/backend.Dockerfile <<'DOCKER'
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libpq-dev curl \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements /app/backend/requirements
RUN pip install --upgrade pip \
    && pip install -r /app/backend/requirements/dev.txt

COPY backend /app/backend

WORKDIR /app/backend

EXPOSE 8000

CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "2"]
DOCKER

cat > docker/frontend.Dockerfile <<'DOCKER'
FROM node:22-alpine
WORKDIR /app/frontend
CMD ["sh", "-c", "echo 'Frontend futuro no implementado en MVP inicial' && sleep infinity"]
DOCKER

cat > docker/nginx.Dockerfile <<'DOCKER'
FROM nginx:1.27-alpine
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
DOCKER

cat > docker-compose.yml <<'YAML'
services:
  db:
    image: postgres:16-alpine
    container_name: emisiones_db
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-emisiones_db}
      POSTGRES_USER: ${POSTGRES_USER:-emisiones_user}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-change-me}
    ports:
      - "5434:5432"
    volumes:
      - emisiones_postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-emisiones_user} -d ${POSTGRES_DB:-emisiones_db}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: emisiones_redis
    restart: unless-stopped
    ports:
      - "6381:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    build:
      context: .
      dockerfile: docker/backend.Dockerfile
    container_name: emisiones_backend
    restart: unless-stopped
    env_file:
      - .env
    working_dir: /app/backend
    command: gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 2 --reload
    volumes:
      - ./backend:/app/backend
      - ./logs:/app/logs
    ports:
      - "8001:8000"
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    healthcheck:
      test: ["CMD-SHELL", "curl -fsS http://localhost:8000/health/ || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  emisiones_postgres_data:
YAML

cat > docker-compose.prod.yml <<'YAML'
services:
  backend:
    command: gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 3
YAML

cat > nginx/default.conf <<'NGINX'
server {
    listen 80;
    server_name _;

    client_max_body_size 20M;

    location /static/ {
        alias /app/backend/staticfiles/;
    }

    location /media/ {
        alias /app/backend/media/;
    }

    location / {
        proxy_pass http://backend:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX

cat > .env.example <<'ENV'
APP_NAME=emisiones
APP_ENV=development
DEBUG=True
SECRET_KEY=change-me-use-a-real-secret
DJANGO_SETTINGS_MODULE=config.settings.dev
ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0
CSRF_TRUSTED_ORIGINS=http://localhost:8001,http://127.0.0.1:8001
POSTGRES_DB=emisiones_db
POSTGRES_USER=emisiones_user
POSTGRES_PASSWORD=change-me
POSTGRES_HOST=db
POSTGRES_PORT=5432
REDIS_HOST=redis
REDIS_PORT=6379
LOG_LEVEL=INFO
M365_TENANT_ID=
M365_CLIENT_ID=
M365_CLIENT_SECRET=
M365_SENDER_EMAIL=notificaciones@oftalmi.com
TEAMS_WEBHOOK_URL=
SESSION_COOKIE_SECURE=False
CSRF_COOKIE_SECURE=False
SECURE_SSL_REDIRECT=False
ENV

if [ ! -f .env ]; then
  cp .env.example .env
  warn "Se creo .env local desde .env.example. No debe subirse al repositorio."
fi

if ! grep -q '^.env$' .gitignore 2>/dev/null; then
  cat >> .gitignore <<'GITIGNORE'
.env
*.pyc
__pycache__/
backend/staticfiles/
backend/media/
logs/
backups/
GITIGNORE
fi

cat > scripts/check_env.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

required_files=(
  ".env"
  "docker-compose.yml"
  "backend/manage.py"
  "backend/config/settings/base.py"
)

for file in "${required_files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "ERROR: falta $file" >&2
    exit 1
  fi
  echo "OK: $file"
done

echo "Validacion basica completada."
SH
chmod +x scripts/check_env.sh

cat > scripts/backup_db.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

mkdir -p backups
STAMP=$(date +%Y%m%d_%H%M%S)
OUT="backups/emisiones_db_${STAMP}.sql.gz"

docker compose exec -T db pg_dump -U "${POSTGRES_USER:-emisiones_user}" "${POSTGRES_DB:-emisiones_db}" | gzip > "$OUT"
echo "Backup creado: $OUT"
SH
chmod +x scripts/backup_db.sh

cat > scripts/restore_db.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Uso: $0 backups/archivo.sql.gz" >&2
  exit 1
fi

FILE="$1"
if [ ! -f "$FILE" ]; then
  echo "ERROR: no existe $FILE" >&2
  exit 1
fi

gunzip -c "$FILE" | docker compose exec -T db psql -U "${POSTGRES_USER:-emisiones_user}" "${POSTGRES_DB:-emisiones_db}"
echo "Restore aplicado desde: $FILE"
SH
chmod +x scripts/restore_db.sh

cat > scripts/deploy.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

docker compose pull || true
docker compose build
docker compose up -d
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py collectstatic --noinput
SH
chmod +x scripts/deploy.sh

cat > .github/workflows/backend-ci.yml <<'YAML'
name: Backend CI

on:
  push:
    branches: [develop, main]
  pull_request:
    branches: [develop, main]

jobs:
  backend-check:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: emisiones_db
          POSTGRES_USER: emisiones_user
          POSTGRES_PASSWORD: change-me
        ports:
          - 5432:5432
        options: >-
          --health-cmd="pg_isready -U emisiones_user -d emisiones_db"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=5
    env:
      DJANGO_SETTINGS_MODULE: config.settings.dev
      SECRET_KEY: ci-secret
      POSTGRES_DB: emisiones_db
      POSTGRES_USER: emisiones_user
      POSTGRES_PASSWORD: change-me
      POSTGRES_HOST: localhost
      POSTGRES_PORT: 5432
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r backend/requirements/dev.txt
      - name: Django checks
        working-directory: backend
        run: |
          python manage.py check
          python manage.py migrate --check || true
      - name: Ruff
        run: ruff check backend
YAML

cat > docs/06-backlog/fase1_plan_trabajo.md <<'MD'
# Fase 1 - Plan de trabajo controlado

## Objetivo

Construir el nucleo operativo del MVP del Sistema de Rutas de Pago Oftalmi, evitando deuda tecnica temprana y manteniendo trazabilidad por ramas Git.

## Secuencia aprobada

| Punto | Rama sugerida | Alcance |
|---|---|---|
| F1-P01 | feature/django-base-project | Proyecto Django base funcional. |
| F1-P02 | feature/django-base-project | Settings por ambiente. |
| F1-P03 | feature/django-base-project | Docker Compose con backend y PostgreSQL. |
| F1-P04 | feature/accounts-email-user | CustomUser con email como username. |
| F1-P05 | feature/accounts-roles | Roles base del MVP. |
| F1-P06 | feature/organization-base | Empresa, unidades, departamentos, areas y gerencias. |
| F1-P07 | feature/user-organization-scope | Relacion usuario, empresa y unidad. |
| F1-P08 | feature/login-basic | Login basico por email. |
| F1-P09 | feature/phase1-base-tests | Pruebas minimas de usuarios, roles y organizacion. |
| F1-P10 | feature/beneficiaries-base | Beneficiarios/proveedores. |
| F1-P11 | feature/payment-requests-base | Solicitudes de pago. |
| F1-P12 | feature/payment-documents-base | Documentos soporte. |
| F1-P13 | feature/basic-approval-route | Ruta basica de aprobacion. |
| F1-P14 | feature/approval-actions | Aprobar, devolver y rechazar. |
| F1-P15 | feature/accounts-payable | Bandeja Cuentas por Pagar. |
| F1-P16 | feature/payment-execution | Registro de pago. |
| F1-P17 | feature/basic-audit | Auditoria basica transversal. |

## Regla de avance

No se inicia un punto nuevo hasta que el punto anterior tenga:

1. Codigo aplicado.
2. Validacion local.
3. Commit en rama feature.
4. Integracion a develop.
5. Estado Git limpio.
MD

cat > docs/04-devops/ejecucion_local.md <<'MD'
# Ejecucion local - Emisiones

## Levantar servicios

```bash
cp .env.example .env
./scripts/check_env.sh
docker compose up --build
```

## Migraciones

En otra terminal:

```bash
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py check
```

## Validar healthcheck

```bash
curl http://localhost:8001/health/
```

Respuesta esperada:

```json
{"status": "ok", "service": "emisiones"}
```

## Admin Django

```bash
docker compose exec backend python manage.py createsuperuser
```

Acceso:

```text
http://localhost:8001/admin/
```
MD

info "Archivos generados/actualizados. Validacion recomendada:"
cat <<'NEXT'

./scripts/check_env.sh
docker compose up --build
# En otra terminal:
docker compose exec backend python manage.py check
docker compose exec backend python manage.py migrate
curl http://localhost:8001/health/

git status --short
NEXT
