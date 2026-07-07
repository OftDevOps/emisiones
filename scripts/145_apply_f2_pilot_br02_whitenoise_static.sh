#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== F2-PILOT-BR02: aplicar WhiteNoise/static para piloto =="
echo "== Ruta =="
pwd

echo "== Estado inicial =="
git status --short

python3 - <<'PY'
from pathlib import Path

project = Path('/home/dchirinos/oftalmiIA/emisiones/emisiones')
base = project / 'backend/config/settings/base.py'
text = base.read_text(encoding='utf-8')
original = text

# 1) Middleware WhiteNoise justo despues de SecurityMiddleware.
if 'whitenoise.middleware.WhiteNoiseMiddleware' not in text:
    security_line = "    'django.middleware.security.SecurityMiddleware',"
    if security_line in text:
        text = text.replace(
            security_line,
            security_line + "\n    'whitenoise.middleware.WhiteNoiseMiddleware',",
            1,
        )
    else:
        raise SystemExit('ERROR: no se encontro django.middleware.security.SecurityMiddleware en MIDDLEWARE')

# 2) Config STATIC_ROOT y storage WhiteNoise si no existen.
if 'STATIC_ROOT' not in text:
    marker = "STATIC_URL = 'static/'"
    if marker not in text:
        marker = 'STATIC_URL = "static/"'
    if marker in text:
        text = text.replace(
            marker,
            marker + "\nSTATIC_ROOT = BASE_DIR / 'staticfiles'",
            1,
        )
    else:
        raise SystemExit('ERROR: no se encontro STATIC_URL en settings/base.py')

if 'STORAGES' not in text and 'WHITENOISE' not in text and 'CompressedManifestStaticFilesStorage' not in text:
    static_root_line = "STATIC_ROOT = BASE_DIR / 'staticfiles'"
    if static_root_line in text:
        text = text.replace(
            static_root_line,
            static_root_line + "\n\nSTORAGES = {\n    'default': {\n        'BACKEND': 'django.core.files.storage.FileSystemStorage',\n    },\n    'staticfiles': {\n        'BACKEND': 'whitenoise.storage.CompressedManifestStaticFilesStorage',\n    },\n}\nWHITENOISE_KEEP_ONLY_HASHED_FILES = True",
            1,
        )
    else:
        raise SystemExit('ERROR: no se encontro STATIC_ROOT para insertar STORAGES')

if text != original:
    base.write_text(text, encoding='utf-8')
    print('OK: settings/base.py actualizado para WhiteNoise/static')
else:
    print('OK: settings/base.py ya tenia configuracion WhiteNoise/static equivalente')

# 3) Agregar dependencia whitenoise en archivo detectado.
# Preferencia: requirements/base.txt, requirements.txt, backend/requirements.txt, pyproject no se modifica automaticamente.
candidates = [
    project / 'requirements/base.txt',
    project / 'requirements.txt',
    project / 'backend/requirements.txt',
]
req_path = next((p for p in candidates if p.exists()), None)
if req_path is None:
    print('WARN: no se encontro requirements*.txt conocido. Agrega manualmente whitenoise si el proyecto usa otro gestor.')
else:
    req = req_path.read_text(encoding='utf-8')
    if 'whitenoise' not in req.lower():
        if not req.endswith('\n'):
            req += '\n'
        req += 'whitenoise>=6.7,<7\n'
        req_path.write_text(req, encoding='utf-8')
        print(f'OK: dependencia agregada en {req_path.relative_to(project)}')
    else:
        print(f'OK: dependencia WhiteNoise ya existe en {req_path.relative_to(project)}')
PY

echo "== Verificando cambios relevantes =="
grep -n "WhiteNoiseMiddleware\|STATIC_URL\|STATIC_ROOT\|STORAGES\|WHITENOISE_KEEP" backend/config/settings/base.py || true
grep -Rni "whitenoise" requirements*.txt requirements backend 2>/dev/null || true

echo "== Rebuild backend para instalar dependencia si aplica =="
docker compose build backend

echo "== Reiniciando servicios =="
docker compose up -d

echo "== collectstatic =="
docker compose exec backend python manage.py collectstatic --noinput

echo "== Validaciones focales =="
git diff --check
docker compose exec backend ruff check config/settings/base.py apps/accounts/context_processors.py
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== Tests focales branding/navegacion/dashboard =="
docker compose exec backend python manage.py test \
  apps.accounts.tests.test_role_navigation_context \
  apps.accounts.tests.test_role_navigation_template \
  apps.accounts.tests.test_authentication_flow \
  apps.payment_requests.tests.test_dashboard

echo "== Validando static via Gunicorn publicado en host =="
curl -I --max-time 5 http://127.0.0.1:8001/static/css/oftalmi_branding.css || true
curl -I --max-time 5 http://127.0.0.1:8001/static/img/oftalmi-icon.png || true
curl -I --max-time 5 http://127.0.0.1:8001/static/img/favicon.ico || true
curl -I --max-time 5 http://127.0.0.1:8001/login/ || true

echo "== Estado final =="
git status --short

echo "== FIN F2-PILOT-BR02 WhiteNoise/static =="
