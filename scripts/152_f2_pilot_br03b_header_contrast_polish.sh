#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== F2-PILOT-BR03B: polish contraste header, marca y sesion =="
echo "== Ruta =="
pwd

echo "== Estado inicial =="
git status --short

CSS="backend/static/css/oftalmi_branding.css"
if [ ! -f "$CSS" ]; then
  echo "ERROR: no existe $CSS"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

path = Path("backend/static/css/oftalmi_branding.css")
text = path.read_text(encoding="utf-8")
marker = "/* F2-PILOT-BR03B: header contrast polish */"
block = r'''
/* F2-PILOT-BR03B: header contrast polish */
.oftalmi-header,
.app-header,
.site-header,
header.oftalmi-header {
  background: linear-gradient(135deg, var(--brand-primary, #1226AA) 0%, var(--brand-secondary, #8A1A9B) 100%) !important;
  color: #ffffff !important;
  border-bottom: 1px solid rgba(255, 232, 0, 0.28) !important;
  box-shadow: 0 16px 38px rgba(18, 38, 170, 0.22) !important;
}

.oftalmi-header a,
.app-header a,
.site-header a,
.oftalmi-header .brand-title,
.oftalmi-header .brand-subtitle,
.oftalmi-header .brand-name,
.oftalmi-header .brand-product,
.oftalmi-header .brand-company,
.oftalmi-header .app-brand-title,
.oftalmi-header .app-brand-subtitle,
.oftalmi-header .product-name,
.oftalmi-header .company-name,
.oftalmi-header .user-email,
.oftalmi-header .session-email,
.oftalmi-header .current-user,
.oftalmi-header .user-info,
.app-header .brand-title,
.app-header .brand-subtitle,
.app-header .user-email,
.site-header .brand-title,
.site-header .brand-subtitle,
.site-header .user-email {
  color: #ffffff !important;
  opacity: 1 !important;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.28) !important;
}

.oftalmi-header .brand-subtitle,
.oftalmi-header .app-brand-subtitle,
.oftalmi-header .company-name,
.app-header .brand-subtitle,
.site-header .brand-subtitle {
  color: rgba(255, 255, 255, 0.88) !important;
  font-weight: 600 !important;
}

.oftalmi-header .brand-title,
.oftalmi-header .app-brand-title,
.oftalmi-header .product-name,
.app-header .brand-title,
.site-header .brand-title {
  color: #ffffff !important;
  font-weight: 800 !important;
  letter-spacing: 0.01em !important;
}

.oftalmi-header .brand-logo,
.oftalmi-header .app-logo,
.oftalmi-header img,
.app-header .brand-logo,
.site-header .brand-logo {
  background: #ffffff !important;
  border: 1px solid rgba(255, 255, 255, 0.72) !important;
  box-shadow: 0 10px 26px rgba(0, 0, 0, 0.18) !important;
}

.oftalmi-header .session-area,
.oftalmi-header .user-session,
.oftalmi-header .auth-area,
.oftalmi-header .header-actions,
.app-header .session-area,
.site-header .session-area {
  display: flex !important;
  align-items: center !important;
  gap: 1rem !important;
}

.oftalmi-header .user-email,
.oftalmi-header .session-email,
.oftalmi-header .current-user,
.oftalmi-header .user-info,
.app-header .user-email,
.site-header .user-email {
  max-width: 28rem !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
  white-space: nowrap !important;
  font-weight: 700 !important;
}

.oftalmi-header .logout-button,
.oftalmi-header .logout-link,
.oftalmi-header form button,
.oftalmi-header button[type="submit"],
.app-header .logout-button,
.site-header .logout-button {
  background: var(--brand-accent, #FFE800) !important;
  color: var(--brand-primary, #1226AA) !important;
  border: 1px solid rgba(255, 255, 255, 0.86) !important;
  box-shadow: 0 12px 28px rgba(0, 0, 0, 0.20) !important;
  font-weight: 800 !important;
  text-shadow: none !important;
}

.oftalmi-header .logout-button:hover,
.oftalmi-header .logout-link:hover,
.oftalmi-header form button:hover,
.oftalmi-header button[type="submit"]:hover,
.app-header .logout-button:hover,
.site-header .logout-button:hover {
  background: #ffffff !important;
  color: var(--brand-secondary, #8A1A9B) !important;
  transform: translateY(-1px) !important;
}

.oftalmi-card,
.dashboard-card,
.summary-card,
.card {
  overflow: hidden;
}

.oftalmi-card .card-value,
.dashboard-card .card-value,
.summary-card .card-value,
.card .card-value {
  overflow-wrap: anywhere;
  word-break: break-word;
}
'''

if marker in text:
    before = text.split(marker)[0].rstrip()
    text = before + "\n\n" + block.lstrip()
    print("OK: bloque BR03B reemplazado")
else:
    text = text.rstrip() + "\n\n" + block.lstrip()
    print("OK: bloque BR03B agregado")

path.write_text(text, encoding="utf-8")
PY

echo "== Validacion diff whitespace =="
git diff --check

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== Tests focales visual/navigation/login =="
docker compose exec backend python manage.py test \
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
for url in \
  http://127.0.0.1:8001/login/ \
  http://127.0.0.1:8001/static/css/oftalmi_branding.css \
  http://127.0.0.1:8001/static/img/oftalmi-icon.png \
  http://127.0.0.1:8001/static/img/favicon.ico \
  http://127.0.0.1:8001/admin/; do
  echo "-- $url"
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" || true)
  echo "HTTP $code"
done

echo "== Usuarios con staff/superuser para admin Django =="
docker compose exec backend python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
for user in User.objects.filter(is_active=True).order_by('email'):
    if user.is_staff or user.is_superuser or user.email == 'douglas.chirinos@oftalmi.com':
        print(f'{user.email} staff={user.is_staff} superuser={user.is_superuser} active={user.is_active}')
"

echo "== Estado final =="
git status --short

echo "== FIN F2-PILOT-BR03B header contrast polish =="
