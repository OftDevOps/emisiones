#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== 143 - Fix branding template regressions =="
echo "Project: $PROJECT_DIR"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S %z')"

BASE_TEMPLATE="backend/templates/base.html"
DASHBOARD_TEMPLATE="backend/templates/payment_requests/paymentrequest_dashboard.html"
CSS_FILE="backend/static/css/oftalmi_branding.css"

for path in "$BASE_TEMPLATE" "$DASHBOARD_TEMPLATE" "$CSS_FILE"; do
  if [ ! -f "$path" ]; then
    echo "FAIL: required file not found: $path" >&2
    exit 1
  fi
  echo "OK: $path"
done

echo
printf '== Git baseline ==\n'
git status --short
git log --oneline --max-count=5 --decorate

python3 - <<'PY'
from pathlib import Path

base = Path("backend/templates/base.html")
dash = Path("backend/templates/payment_requests/paymentrequest_dashboard.html")
css = Path("backend/static/css/oftalmi_branding.css")

base_text = base.read_text(encoding="utf-8")
base_text = base_text.replace(
    'href="{% url \'payment_approvals:audit\' %}">Auditoría</a>',
    'href="{% url \'payment_approvals:audit\' %}">Auditoria</a>',
)
base.write_text(base_text, encoding="utf-8")

dash_text = dash.read_text(encoding="utf-8")

if 'aria-label="Accesos operativos"' not in dash_text:
    dash_text = dash_text.replace(
        '<section class="quick-actions">',
        '<section class="quick-actions" aria-label="Accesos operativos">\n  <h2 class="visually-hidden">Accesos operativos</h2>',
        1,
    )

fallback = '''  {% if not role_nav.can_view_pending_approvals and not role_nav.can_view_audit_workbench and not role_nav.can_view_accounts_payable and not role_nav.can_view_payment_request_report %}
    <p class="empty-state">No tienes accesos operativos adicionales para tu rol.</p>
  {% endif %}
'''
if 'No tienes accesos operativos adicionales para tu rol.' not in dash_text:
    marker = '</section>\n\n<section class="kpi-grid">'
    dash_text = dash_text.replace('</section>\n\n<section class="kpi-grid">', fallback + '</section>\n\n<section class="kpi-grid">', 1)

# Keep the legacy acceptance-test wording while preserving the improved visual layout.
dash_text = dash_text.replace(
    'Ir a auditoría</a>',
    'Ir a auditoría de acciones críticas</a>',
)

dash.write_text(dash_text, encoding="utf-8")

css_text = css.read_text(encoding="utf-8")
if '.visually-hidden' not in css_text:
    css_text += '''

.visually-hidden {
  position: absolute !important;
  width: 1px !important;
  height: 1px !important;
  padding: 0 !important;
  margin: -1px !important;
  overflow: hidden !important;
  clip: rect(0, 0, 0, 0) !important;
  white-space: nowrap !important;
  border: 0 !important;
}
'''
    css.write_text(css_text, encoding="utf-8")
PY

echo
printf '== Relevant template evidence ==\n'
grep -nE 'Auditoria|Accesos operativos|No tienes accesos|Ir a auditoría de acciones críticas' \
  "$BASE_TEMPLATE" "$DASHBOARD_TEMPLATE" || true

echo
printf '== Diff summary ==\n'
git diff -- "$BASE_TEMPLATE" "$DASHBOARD_TEMPLATE" "$CSS_FILE"

echo
printf '== Local syntax checks ==\n'
python3 -m py_compile backend/config/settings/base.py backend/apps/accounts/context_processors.py
bash -n scripts/141_inspect_branding_parametrization.sh 2>/dev/null || true
bash -n scripts/142_apply_branding_parametrization.sh 2>/dev/null || true
bash -n scripts/143_fix_branding_template_regressions.sh 2>/dev/null || true

echo
printf '== Result ==\n'
echo "BRANDING_TEMPLATE_REGRESSIONS_FIXED_READY_FOR_DJANGO_TESTS"
