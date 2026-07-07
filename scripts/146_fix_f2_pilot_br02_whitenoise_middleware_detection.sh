#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== Fix F2-PILOT-BR02: WhiteNoise middleware detection robusto =="
echo "== Ruta =="
pwd

echo "== Estado inicial =="
git status --short

python3 - <<'PY'
from pathlib import Path

path = Path("backend/config/settings/base.py")
text = path.read_text(encoding="utf-8")
original = text

security_single = "    'django.middleware.security.SecurityMiddleware',"
security_double = '    "django.middleware.security.SecurityMiddleware",'
whitenoise_single = "    'whitenoise.middleware.WhiteNoiseMiddleware',"
whitenoise_double = '    "whitenoise.middleware.WhiteNoiseMiddleware",'

if "whitenoise.middleware.WhiteNoiseMiddleware" not in text:
    if security_single in text:
        text = text.replace(security_single, security_single + "\n" + whitenoise_single, 1)
        print("OK: WhiteNoiseMiddleware insertado despues de SecurityMiddleware con comillas simples")
    elif security_double in text:
        text = text.replace(security_double, security_double + "\n" + whitenoise_double, 1)
        print("OK: WhiteNoiseMiddleware insertado despues de SecurityMiddleware con comillas dobles")
    else:
        raise SystemExit("ERROR: no se encontro SecurityMiddleware con formato esperado en MIDDLEWARE")
else:
    print("OK: WhiteNoiseMiddleware ya existe")

# STATIC_ROOT ya existe segun inspeccion, pero se mantiene validacion defensiva.
if "STATIC_ROOT" not in text:
    if "STATIC_URL" not in text:
        raise SystemExit("ERROR: no se encontro STATIC_URL para insertar STATIC_ROOT")
    text = text.replace('STATIC_URL = "/static/"', 'STATIC_URL = "/static/"\nSTATIC_ROOT = BASE_DIR / "staticfiles"', 1)
    text = text.replace("STATIC_URL = '/static/'", "STATIC_URL = '/static/'\nSTATIC_ROOT = BASE_DIR / 'staticfiles'", 1)
    print("OK: STATIC_ROOT agregado")
else:
    print("OK: STATIC_ROOT ya existe")

# Configurar storage WhiteNoise si no existe.
if "CompressedManifestStaticFilesStorage" not in text:
    block = """

STORAGES = {
    'default': {
        'BACKEND': 'django.core.files.storage.FileSystemStorage',
    },
    'staticfiles': {
        'BACKEND': 'whitenoise.storage.CompressedManifestStaticFilesStorage',
    },
}
WHITENOISE_KEEP_ONLY_HASHED_FILES = True
"""
    # Insertar despues del bloque STATICFILES_DIRS si existe, o al final como fallback controlado.
    marker = "STATICFILES_DIRS = [BASE_DIR / \"static\"] if (BASE_DIR / \"static\").exists() else []"
    marker_single = "STATICFILES_DIRS = [BASE_DIR / 'static'] if (BASE_DIR / 'static').exists() else []"
    if marker in text:
        text = text.replace(marker, marker + block, 1)
    elif marker_single in text:
        text = text.replace(marker_single, marker_single + block, 1)
    else:
        text = text.rstrip() + block + "\n"
    print("OK: STORAGES staticfiles WhiteNoise agregado")
else:
    print("OK: STORAGES staticfiles WhiteNoise ya existe")

if text != original:
    path.write_text(text, encoding="utf-8")
else:
    print("OK: settings/base.py sin cambios nuevos")
PY

echo "== Fragmento settings static/middleware =="
grep -n "SecurityMiddleware\|WhiteNoiseMiddleware\|STATIC_URL\|STATIC_ROOT\|STATICFILES_DIRS\|STORAGES\|WHITENOISE_KEEP" backend/config/settings/base.py || true

echo "== Validacion diff whitespace =="
git diff --check

echo "== Rebuild backend para garantizar runtime limpio =="
docker compose build backend

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== collectstatic =="
docker compose exec backend python manage.py collectstatic --noinput

echo "== Tests focales =="
docker compose exec backend python manage.py test \
  apps.accounts.tests.test_role_navigation_context \
  apps.accounts.tests.test_role_navigation_template \
  apps.accounts.tests.test_authentication_flow \
  apps.payment_requests.tests.test_dashboard

echo "== Reinicio backend =="
docker compose up -d backend
sleep 3

echo "== HTTP static via Gunicorn publicado en host =="
curl -I --max-time 5 http://127.0.0.1:8001/static/css/oftalmi_branding.css || true
curl -I --max-time 5 http://127.0.0.1:8001/static/img/oftalmi-icon.png || true
curl -I --max-time 5 http://127.0.0.1:8001/static/img/favicon.ico || true
curl -I --max-time 5 http://127.0.0.1:8001/login/ || true

echo "== Estado final =="
git status --short

echo "== FIN Fix F2-PILOT-BR02 WhiteNoise middleware detection robusto =="
