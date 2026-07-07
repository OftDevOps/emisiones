#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== F2-PILOT: readiness check operativo piloto interno real =="
echo "== Ruta =="
pwd

echo "== Git status =="
git status

echo "== Ultimos commits =="
git log --oneline --max-count=8 --decorate

echo "== Verificando commit base esperado =="
if git log --oneline --max-count=20 | grep -q "3653d41"; then
  echo "OK: commit 3653d41 presente en historial local"
else
  echo "WARN: no se encontro commit 3653d41 en los ultimos 20 commits"
fi

echo "== Verificando arbol limpio =="
if [ -z "$(git status --porcelain)" ]; then
  echo "OK: arbol limpio"
else
  echo "ERROR: arbol con cambios pendientes"
  git status --short
  exit 1
fi

echo "== Docker compose ps =="
docker compose ps

echo "== Validacion diff whitespace =="
git diff --check

echo "== Ruff =="
docker compose exec backend ruff check .

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== Makemigrations dry-run =="
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== Migrate =="
docker compose exec backend python manage.py migrate

echo "== Test suite funcional =="
docker compose exec backend python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests apps.payment_documents apps.payment_approvals apps.payment_execution

echo "== HTTP smoke login/static =="
for url in \
  http://127.0.0.1:8001/login/ \
  http://127.0.0.1:8001/static/css/oftalmi_branding.css \
  http://127.0.0.1:8001/static/img/oftalmi-icon.png \
  http://127.0.0.1:8001/static/img/favicon.ico
 do
  echo "-- $url"
  status=$(curl -I --max-time 5 "$url" 2>/dev/null | awk 'NR==1 {print $2}')
  if [ "$status" = "200" ]; then
    echo "OK: $url -> 200"
  else
    echo "ERROR: $url -> ${status:-sin respuesta}"
    exit 1
  fi
done

echo "== Usuarios demo: existencia y roles =="
docker compose exec backend python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
emails = [
    'douglas.chirinos@oftalmi.com',
    'solicitante.demo@oftalmi.com',
    'responsable.demo@oftalmi.com',
    'finanzas.demo@oftalmi.com',
    'cxp.demo@oftalmi.com',
    'auditor.demo@oftalmi.com',
    'solicitante.otra.demo@oftalmi.com',
]
for email in emails:
    try:
        user = User.objects.get(email=email)
        role = getattr(user, 'role', None) or getattr(user, 'rol', None) or 'SIN_ROLE_ATTR'
        active = getattr(user, 'is_active', None)
        print(f'OK user={email} role={role} active={active}')
    except User.DoesNotExist:
        print(f'ERROR missing user={email}')
        raise SystemExit(1)
"

echo "== FIN readiness piloto interno real: OK =="
