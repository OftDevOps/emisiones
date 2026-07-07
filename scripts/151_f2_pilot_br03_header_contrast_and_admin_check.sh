#!/usr/bin/env bash
set -euo pipefail

cd /home/dchirinos/oftalmiIA/emisiones/emisiones

echo "== F2-PILOT-BR03: header contrast polish + Django admin check =="
echo "== Ruta =="
pwd

echo "== Estado inicial =="
git status --short

CSS="backend/static/css/oftalmi_branding.css"
BASE="backend/templates/base.html"

if [ ! -f "$CSS" ]; then
  echo "ERROR: no existe $CSS"
  exit 1
fi

if [ ! -f "$BASE" ]; then
  echo "ERROR: no existe $BASE"
  exit 1
fi

MARKER="/* F2-PILOT-BR03B: header contrast and account actions */"

if grep -q "$MARKER" "$CSS"; then
  echo "OK: bloque BR03B ya existe en $CSS"
else
  cat >> "$CSS" <<'CSS'

/* F2-PILOT-BR03B: header contrast and account actions */
.oftalmi-header,
.app-header,
.site-header,
.main-header {
  background: linear-gradient(135deg, var(--brand-primary, #1226AA), var(--brand-secondary, #8A1A9B));
  color: #ffffff;
  border-bottom: 4px solid var(--brand-accent, #FFE800);
}

.oftalmi-header a,
.app-header a,
.site-header a,
.main-header a {
  color: #ffffff;
}

.oftalmi-brand,
.brand,
.brand-block,
.brand-identity,
.app-brand,
.header-brand {
  color: #ffffff;
}

.oftalmi-brand *,
.brand *,
.brand-block *,
.brand-identity *,
.app-brand *,
.header-brand * {
  color: inherit;
}

.oftalmi-brand-title,
.brand-title,
.app-title,
.product-name,
.site-title {
  color: #ffffff;
  font-weight: 800;
  letter-spacing: 0.01em;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.35);
}

.oftalmi-brand-subtitle,
.brand-subtitle,
.company-name,
.company-short-name,
.site-subtitle {
  color: #f7fbff;
  font-weight: 600;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.35);
}

.header-user,
.user-menu,
.account-menu,
.user-session,
.auth-actions,
.session-actions,
.oftalmi-user {
  color: #ffffff;
}

.header-user *,
.user-menu *,
.account-menu *,
.user-session *,
.auth-actions *,
.session-actions *,
.oftalmi-user * {
  color: inherit;
}

.header-user .user-email,
.user-menu .user-email,
.account-menu .user-email,
.user-session .user-email,
.oftalmi-user .user-email,
.header-user small,
.user-menu small,
.account-menu small,
.user-session small,
.oftalmi-user small {
  color: #eef7ff;
  font-weight: 600;
}

.oftalmi-header form,
.app-header form,
.site-header form,
.main-header form,
.auth-actions form,
.session-actions form,
.user-session form,
.account-menu form {
  margin: 0;
}

.oftalmi-header button,
.app-header button,
.site-header button,
.main-header button,
.auth-actions button,
.session-actions button,
.user-session button,
.account-menu button,
.logout-button,
button.logout-button {
  background: var(--brand-accent, #FFE800);
  color: #1f1f2f;
  border: 2px solid rgba(255, 255, 255, 0.85);
  border-radius: 999px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.22);
  font-weight: 800;
}

.oftalmi-header button:hover,
.app-header button:hover,
.site-header button:hover,
.main-header button:hover,
.auth-actions button:hover,
.session-actions button:hover,
.user-session button:hover,
.account-menu button:hover,
.logout-button:hover,
button.logout-button:hover,
.oftalmi-header button:focus,
.app-header button:focus,
.site-header button:focus,
.main-header button:focus,
.auth-actions button:focus,
.session-actions button:focus,
.user-session button:focus,
.account-menu button:focus,
.logout-button:focus,
button.logout-button:focus {
  background: #fff27a;
  color: #111827;
  border-color: #ffffff;
  outline: 3px solid var(--brand-info, #6FCFEB);
  outline-offset: 2px;
}
CSS
  echo "OK: bloque BR03B agregado a $CSS"
fi

echo "== Inspeccion header/base relevante =="
grep -nE "Rutas de Pago|Laboratorios Oftalmi|logout|Cerrar|session|user|brand|APP_|app_branding" "$BASE" || true

echo "== Validacion diff whitespace =="
git diff --check

echo "== Ruff focal =="
docker compose exec backend ruff check config/settings/base.py apps/accounts/context_processors.py

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== Tests focales login/navegacion/dashboard =="
docker compose exec backend python manage.py test \
  apps.accounts.tests.test_role_navigation_context \
  apps.accounts.tests.test_role_navigation_template \
  apps.accounts.tests.test_role_navigation_integrated_matrix \
  apps.accounts.tests.test_authentication_flow \
  apps.payment_requests.tests.test_dashboard

echo "== collectstatic =="
docker compose exec backend python manage.py collectstatic --noinput

echo "== Reinicio backend =="
docker compose up -d backend
sleep 3

echo "== HTTP smoke login/static/admin =="
check_url() {
  local url="$1"
  local expected_regex="$2"
  local code
  code=$(curl -s -o /tmp/f2_pilot_http_check.out -w "%{http_code}" --max-time 8 "$url" || true)
  if echo "$code" | grep -Eq "$expected_regex"; then
    echo "OK: $url -> $code"
  else
    echo "ERROR: $url -> $code; esperado $expected_regex"
    cat /tmp/f2_pilot_http_check.out || true
    exit 1
  fi
}

check_url "http://127.0.0.1:8001/login/" "^200$"
check_url "http://127.0.0.1:8001/static/css/oftalmi_branding.css" "^200$"
check_url "http://127.0.0.1:8001/static/img/oftalmi-icon.png" "^200$"
check_url "http://127.0.0.1:8001/static/img/favicon.ico" "^200$"
check_url "http://127.0.0.1:8001/admin/" "^(200|302)$"

echo "== Django admin: usuarios staff/superuser =="
docker compose exec backend python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
qs = User.objects.filter(is_staff=True).order_by('email')
print('STAFF_COUNT=', qs.count())
for user in qs:
    print(f'STAFF user={user.email} role={getattr(user, "role", "N/A")} active={user.is_active} superuser={user.is_superuser}')
admin_email = 'douglas.chirinos@oftalmi.com'
try:
    user = User.objects.get(email=admin_email)
    print(f'DOUGLAS_ADMIN_CHECK email={user.email} active={user.is_active} staff={user.is_staff} superuser={user.is_superuser} role={getattr(user, "role", "N/A")}')
except User.DoesNotExist:
    print('WARN: douglas.chirinos@oftalmi.com no existe')
"

echo "== Estado final =="
git status --short

echo "== FIN F2-PILOT-BR03 header contrast/admin check =="
