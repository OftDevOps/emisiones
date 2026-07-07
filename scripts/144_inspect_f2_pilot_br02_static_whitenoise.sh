#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== F2-PILOT-BR02: inspeccion static files / WhiteNoise =="
echo "== Ruta =="
pwd

echo "== Git status =="
git status --short

echo "== Ultimos commits =="
git log --oneline --max-count=8 --decorate

echo "== Confirmando fix script 143 en templates =="
grep -n "Auditoria" backend/templates/base.html || true
grep -n "Accesos operativos" backend/templates/payment_requests/paymentrequest_dashboard.html || true
grep -n "No tienes accesos operativos adicionales para tu rol" backend/templates/payment_requests/paymentrequest_dashboard.html || true
grep -n "Ir a auditoría de acciones críticas" backend/templates/payment_requests/paymentrequest_dashboard.html || true

echo "== Buscando WhiteNoise =="
grep -Rni "whitenoise" . \
  --exclude-dir=.git \
  --exclude-dir=.venv \
  --exclude-dir=venv \
  --exclude-dir=__pycache__ \
  --exclude='*.pyc' || true

echo "== Archivos de dependencias/config relevantes =="
find . -maxdepth 4 -type f | sort | grep -E 'requirements|pyproject|Pipfile|Dockerfile|compose|settings' || true

echo "== Settings static/middleware/apps =="
grep -nE 'STATIC|MIDDLEWARE|INSTALLED_APPS|BASE_DIR' backend/config/settings/base.py || true

echo "== Static locales esperados =="
ls -lah backend/static || true
ls -lah backend/static/css || true
ls -lah backend/static/img || true

echo "== Validacion diff whitespace =="
git diff --check

echo "== Validacion Django focal dentro de Docker =="
echo "IMPORTANTE: ejecutar este script con NordVPN desconectado si Docker/puertos locales se congelan."
docker compose exec backend ruff check config/settings/base.py apps/accounts/context_processors.py
docker compose exec backend python manage.py check

echo "== Tests focales branding/navegacion/dashboard =="
docker compose exec backend python manage.py test \
  apps.accounts.tests.test_role_navigation_context \
  apps.accounts.tests.test_role_navigation_template \
  apps.accounts.tests.test_authentication_flow \
  apps.payment_requests.tests.test_dashboard

echo "== HTTP static via Gunicorn publicado en host =="
curl -I --max-time 5 http://127.0.0.1:8001/static/css/oftalmi_branding.css || true
curl -I --max-time 5 http://127.0.0.1:8001/static/img/oftalmi-icon.png || true
curl -I --max-time 5 http://127.0.0.1:8001/static/img/favicon.ico || true
curl -I --max-time 5 http://127.0.0.1:8001/login/ || true

echo "== FIN inspeccion F2-PILOT-BR02 =="
