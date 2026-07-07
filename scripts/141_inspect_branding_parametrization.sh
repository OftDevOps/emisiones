#!/usr/bin/env bash
set -u

PROJECT_ROOT="${PROJECT_ROOT:-/home/dchirinos/oftalmiIA/emisiones/emisiones}"
cd "$PROJECT_ROOT" || exit 1

printf '== 141 - Inspect branding parametrization ==\n'
printf 'Project: %s\n' "$PROJECT_ROOT"
printf 'Date: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"

printf '== Git baseline ==\n'
git status --short || true
git log --oneline --max-count=5 --decorate || true

printf '\n== Static branding assets ==\n'
for asset in \
  backend/static/img/favicon.ico \
  backend/static/img/oftalmi-icon.png \
  backend/static/css/oftalmi_branding.css
  do
    if [ -f "$asset" ]; then
      printf 'OK: %s\n' "$asset"
      ls -lh "$asset"
    else
      printf 'MISS: %s\n' "$asset"
    fi
  done

printf '\n== Branding references in templates/static/settings ==\n'
grep -RniE 'oftalmi|favicon|brand|logo|APP_COMPANY|APP_BRAND|static.*img|oftalmi_branding' \
  backend/templates backend/static backend/config/settings backend/apps/accounts 2>/dev/null || true

printf '\n== Context processors configured ==\n'
grep -RniE 'context_processors|apps\.accounts\.context_processors|branding|navigation' backend/config/settings backend/apps/accounts 2>/dev/null || true

printf '\n== Current accounts context processors file ==\n'
if [ -f backend/apps/accounts/context_processors.py ]; then
  sed -n '1,240p' backend/apps/accounts/context_processors.py
else
  printf 'MISS: backend/apps/accounts/context_processors.py\n'
fi

printf '\n== Settings snippets likely needed for branding ==\n'
if [ -f backend/config/settings/base.py ]; then
  grep -nE 'STATIC_URL|STATICFILES_DIRS|STATIC_ROOT|TEMPLATES|APP_|BRAND|COMPANY|ALLOWED_HOSTS|CSRF' backend/config/settings/base.py || true
fi

printf '\n== Template heads/layout snippets ==\n'
for tpl in backend/templates/base.html backend/templates/registration/login.html backend/templates/accounts/dashboard.html backend/templates/payment_requests/paymentrequest_dashboard.html; do
  if [ -f "$tpl" ]; then
    printf '\n--- %s ---\n' "$tpl"
    sed -n '1,220p' "$tpl"
  else
    printf '\nMISS: %s\n' "$tpl"
  fi
done

printf '\n== CSS current branding file ==\n'
if [ -f backend/static/css/oftalmi_branding.css ]; then
  sed -n '1,260p' backend/static/css/oftalmi_branding.css
fi

printf '\n== Result ==\n'
printf 'BRANDING_PARAMETRIZATION_INSPECTION_READY\n'
