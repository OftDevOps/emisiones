#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_ROOT"

echo "== F2-PILOT-BR03C: header readability dark text polish =="
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
marker = "/* F2-PILOT-BR03C: header readability dark text polish */"
block = r'''
/* F2-PILOT-BR03C: header readability dark text polish */
:root {
  --oftalmi-header-text: #1226AA;
  --oftalmi-header-muted: #334155;
  --oftalmi-header-surface: rgba(255, 255, 255, 0.88);
}

.oftalmi-header,
.app-header,
.site-header,
.main-header {
  background:
    linear-gradient(90deg, rgba(111, 207, 235, 0.24) 0%, rgba(255, 255, 255, 0.92) 44%, rgba(138, 26, 155, 0.16) 100%) !important;
  color: var(--oftalmi-header-text) !important;
  border-bottom: 1px solid rgba(18, 38, 170, 0.12) !important;
}

.oftalmi-brand,
.brand,
.brand-block,
.header-brand,
.app-brand {
  color: var(--oftalmi-header-text) !important;
}

.oftalmi-brand *,
.brand *,
.brand-block *,
.header-brand *,
.app-brand * {
  color: inherit !important;
  text-shadow: none !important;
}

.oftalmi-brand-title,
.brand-title,
.app-brand-title,
.header-brand-title,
.oftalmi-brand strong,
.brand strong {
  color: #1226AA !important;
  font-weight: 800 !important;
  letter-spacing: 0.01em !important;
}

.oftalmi-brand-subtitle,
.brand-subtitle,
.app-brand-subtitle,
.header-brand-subtitle,
.oftalmi-brand small,
.brand small {
  color: #475569 !important;
  font-weight: 600 !important;
}

.oftalmi-userbar,
.userbar,
.user-menu,
.header-user,
.session-user,
.auth-user,
.oftalmi-header .user-email,
.oftalmi-header [class*="email"] {
  color: #334155 !important;
  font-weight: 700 !important;
  opacity: 1 !important;
  text-shadow: none !important;
}

.oftalmi-header a,
.app-header a,
.site-header a,
.main-header a {
  color: #1226AA !important;
}

.oftalmi-header .logout-button,
.oftalmi-header button[type="submit"],
.app-header .logout-button,
.app-header button[type="submit"],
.site-header .logout-button,
.site-header button[type="submit"],
.main-header .logout-button,
.main-header button[type="submit"] {
  background: #1226AA !important;
  color: #FFFFFF !important;
  border: 1px solid rgba(18, 38, 170, 0.88) !important;
  box-shadow: 0 10px 22px rgba(18, 38, 170, 0.22) !important;
  margin-left: 1rem !important;
}

.oftalmi-header .logout-button:hover,
.oftalmi-header button[type="submit"]:hover,
.app-header .logout-button:hover,
.app-header button[type="submit"]:hover,
.site-header .logout-button:hover,
.site-header button[type="submit"]:hover,
.main-header .logout-button:hover,
.main-header button[type="submit"]:hover {
  background: #8A1A9B !important;
  color: #FFFFFF !important;
  border-color: #8A1A9B !important;
}

.oftalmi-header .brand-logo,
.oftalmi-brand img,
.app-brand img,
.header-brand img,
.brand img {
  background: #FFFFFF !important;
  border: 1px solid rgba(18, 38, 170, 0.10) !important;
  box-shadow: 0 8px 18px rgba(18, 38, 170, 0.14) !important;
}

.dashboard-card,
.summary-card,
.metric-card,
.panel-card {
  overflow: hidden !important;
}

.dashboard-card .value,
.summary-card .value,
.metric-card .value,
.panel-card .value,
.dashboard-card p,
.summary-card p,
.metric-card p,
.panel-card p {
  overflow-wrap: anywhere !important;
  word-break: normal !important;
}
'''
if marker in text:
    before = text[:text.index(marker)].rstrip()
    text = before + "\n\n" + block.strip() + "\n"
else:
    text = text.rstrip() + "\n\n" + block.strip() + "\n"
path.write_text(text, encoding="utf-8")
PY

echo "== Confirmando bloque CSS BR03C =="
grep -n "F2-PILOT-BR03C\|oftalmi-header-text\|header readability" "$CSS" || true

echo "== Validacion diff whitespace =="
git diff --check

echo "== Ruff focal =="
docker compose exec backend ruff check config/settings/base.py apps/accounts/context_processors.py

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== collectstatic =="
docker compose exec backend python manage.py collectstatic --noinput

echo "== Reinicio backend =="
docker compose up -d backend
sleep 3

echo "== HTTP static/login/admin =="
for url in \
  http://127.0.0.1:8001/static/css/oftalmi_branding.css \
  http://127.0.0.1:8001/static/img/oftalmi-icon.png \
  http://127.0.0.1:8001/static/img/favicon.ico \
  http://127.0.0.1:8001/login/ \
  http://127.0.0.1:8001/admin/
do
  echo "-- $url"
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$url" || true)
  echo "HTTP $code"
  case "$url" in
    *admin*)
      if [ "$code" != "200" ] && [ "$code" != "302" ]; then
        echo "ERROR: admin no responde 200/302"
        exit 1
      fi
      ;;
    *)
      if [ "$code" != "200" ]; then
        echo "ERROR: $url no responde 200"
        exit 1
      fi
      ;;
  esac
done

echo "== Usuarios staff/superuser para admin Django =="
docker compose exec backend python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
for email in ['douglas.chirinos@oftalmi.com','finanzas.demo@oftalmi.com','cxp.demo@oftalmi.com','auditor.demo@oftalmi.com']:
    try:
        u = User.objects.get(email=email)
        print(f'{email}: active={u.is_active} staff={u.is_staff} superuser={u.is_superuser} role={getattr(u, "role", None)}')
    except User.DoesNotExist:
        print(f'{email}: NO_EXISTE')
"

echo "== Estado final =="
git status --short

echo "== FIN F2-PILOT-BR03C header readability =="
