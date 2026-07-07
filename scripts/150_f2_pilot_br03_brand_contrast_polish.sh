#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== F2-PILOT-BR03: ajuste de contraste visual con branding Oftalmi =="
echo "== Ruta =="
pwd

echo "== Estado inicial =="
git status --short

CSS_PATH="backend/static/css/oftalmi_branding.css"
TEMPLATE_BASE="backend/templates/base.html"

if [ ! -f "$CSS_PATH" ]; then
  echo "ERROR: no existe $CSS_PATH"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

css_path = Path("backend/static/css/oftalmi_branding.css")
css = css_path.read_text(encoding="utf-8")

marker = "/* F2-PILOT-BR03: brand contrast polish */"
block = r'''

/* F2-PILOT-BR03: brand contrast polish */
:root {
  --oftalmi-primary: #1226AA;
  --oftalmi-secondary: #8A1A9B;
  --oftalmi-accent: #FFE800;
  --oftalmi-info: #6FCFEB;
  --oftalmi-surface: #FFFFFF;
  --oftalmi-surface-soft: #F7F8FF;
  --oftalmi-text-strong: #111827;
  --oftalmi-text-muted: #4B5563;
  --oftalmi-border: rgba(18, 38, 170, 0.18);
  --oftalmi-shadow: 0 12px 32px rgba(18, 38, 170, 0.14);
}

body {
  color: var(--oftalmi-text-strong);
  background:
    radial-gradient(circle at top left, rgba(111, 207, 235, 0.20), transparent 32rem),
    linear-gradient(135deg, #F8FAFF 0%, #FFFFFF 46%, #F9F5FF 100%);
}

a,
.nav-link {
  color: var(--oftalmi-primary);
}

.nav-link:hover,
.nav-link:focus {
  color: var(--oftalmi-secondary);
  background: rgba(18, 38, 170, 0.08);
}

.oftalmi-header,
.app-header,
.site-header {
  border-bottom: 1px solid var(--oftalmi-border);
  background: rgba(255, 255, 255, 0.94);
  box-shadow: 0 8px 24px rgba(18, 38, 170, 0.08);
}

.card,
.panel,
.dashboard-card,
.quick-action-card,
.summary-card,
.login-card,
.oftalmi-card {
  background: var(--oftalmi-surface);
  border: 1px solid var(--oftalmi-border);
  box-shadow: var(--oftalmi-shadow);
}

.button,
.btn,
button[type="submit"],
a.button,
.nav-link-primary {
  border: 1px solid var(--oftalmi-primary);
  background: var(--oftalmi-primary);
  color: #FFFFFF !important;
  box-shadow: 0 8px 18px rgba(18, 38, 170, 0.22);
}

.button:hover,
.button:focus,
.btn:hover,
.btn:focus,
button[type="submit"]:hover,
button[type="submit"]:focus,
a.button:hover,
a.button:focus,
.nav-link-primary:hover,
.nav-link-primary:focus {
  border-color: var(--oftalmi-secondary);
  background: var(--oftalmi-secondary);
  color: #FFFFFF !important;
}

.button-secondary,
.btn-secondary,
a.button-secondary {
  border: 1px solid var(--oftalmi-primary);
  background: #FFFFFF;
  color: var(--oftalmi-primary) !important;
}

.button-secondary:hover,
.button-secondary:focus,
.btn-secondary:hover,
.btn-secondary:focus,
a.button-secondary:hover,
a.button-secondary:focus {
  background: rgba(18, 38, 170, 0.08);
  color: var(--oftalmi-secondary) !important;
}

.badge,
.status-badge,
.role-badge {
  border: 1px solid rgba(18, 38, 170, 0.18);
  background: rgba(111, 207, 235, 0.18);
  color: var(--oftalmi-primary);
}

.alert,
.message,
.empty-state {
  border-left: 4px solid var(--oftalmi-primary);
  background: var(--oftalmi-surface-soft);
  color: var(--oftalmi-text-strong);
}

table thead th {
  background: rgba(18, 38, 170, 0.08);
  color: var(--oftalmi-primary);
}

input:focus,
select:focus,
textarea:focus {
  border-color: var(--oftalmi-primary);
  box-shadow: 0 0 0 3px rgba(18, 38, 170, 0.14);
  outline: none;
}
'''

if marker in css:
    before, _sep, _after = css.partition(marker)
    css = before.rstrip() + block + "\n"
    print("OK: bloque BR03 existente reemplazado")
else:
    css = css.rstrip() + block + "\n"
    print("OK: bloque BR03 agregado")

css_path.write_text(css, encoding="utf-8")
PY

echo "== Confirmando bloque BR03 =="
grep -n "F2-PILOT-BR03\|--oftalmi-primary\|nav-link-primary\|button\[type=\"submit\"\]" "$CSS_PATH" | head -40

echo "== Validacion diff whitespace =="
git diff --check

echo "== Ruff/check focal =="
docker compose exec backend ruff check apps/accounts/context_processors.py config/settings/base.py
docker compose exec backend python manage.py check

echo "== Tests focales visual/navegacion/dashboard =="
docker compose exec backend python manage.py test \
  apps.accounts.tests.test_role_navigation_context \
  apps.accounts.tests.test_role_navigation_template \
  apps.accounts.tests.test_authentication_flow \
  apps.accounts.tests.test_role_navigation_integrated_matrix \
  apps.payment_requests.tests.test_dashboard

echo "== collectstatic para actualizar staticfiles =="
docker compose exec backend python manage.py collectstatic --noinput

echo "== Reinicio backend =="
docker compose up -d backend
sleep 3

echo "== HTTP smoke static/login =="
for url in \
  "http://127.0.0.1:8001/login/" \
  "http://127.0.0.1:8001/static/css/oftalmi_branding.css" \
  "http://127.0.0.1:8001/static/img/oftalmi-icon.png" \
  "http://127.0.0.1:8001/static/img/favicon.ico"; do
  echo "-- $url"
  status="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$url" || true)"
  echo "HTTP $status"
  if [ "$status" != "200" ]; then
    echo "ERROR: $url no responde 200"
    exit 1
  fi
done

echo "== Estado final =="
git status --short

echo "== FIN F2-PILOT-BR03 contraste branding: OK =="
