#!/usr/bin/env bash
set -euo pipefail

cd /home/dchirinos/oftalmiIA/emisiones/emisiones

echo "== Fix F2-P09: corregir llamada a helper de permisos en PaymentRequestListView =="
echo "== Estado inicial =="
git status --short

python3 - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_requests/views.py")
text = path.read_text(encoding="utf-8")

old = '''    def dispatch(self, request, *args, **kwargs):
        _require_operational_permission(
            request,
            request.user,
            PERM_VIEW_PAYMENT_REQUESTS,
            "Su rol no permite consultar solicitudes de pago.",
        )
        return super().dispatch(request, *args, **kwargs)
'''
new = '''    def dispatch(self, request, *args, **kwargs):
        _require_operational_permission(
            request.user,
            PERM_VIEW_PAYMENT_REQUESTS,
            "Su rol no permite consultar solicitudes de pago.",
        )
        return super().dispatch(request, *args, **kwargs)
'''

if old in text:
    text = text.replace(old, new)
    path.write_text(text, encoding="utf-8")
    print("OK: llamada corregida removiendo argumento request sobrante.")
else:
    if "_require_operational_permission(\n            request,\n            request.user," in text:
        raise SystemExit("ERROR: patron parcial detectado pero bloque completo no coincide; revisar views.py manualmente.")
    print("OK: llamada ya estaba corregida.")
PY

echo "== Fragmento PaymentRequestListView =="
sed -n '45,65p' backend/apps/payment_requests/views.py

echo "== Validando diff whitespace =="
git diff --check

echo "== Ruff focal F2-P09 =="
docker compose exec backend ruff check \
  apps/accounts/context_processors.py \
  apps/accounts/role_permissions.py \
  apps/payment_requests/urls.py \
  apps/payment_requests/views.py \
  apps/payment_requests/tests/test_dashboard.py \
  apps/payment_requests/tests/test_reports.py \
  apps/payment_requests/tests/test_views.py

echo "== Tests focales de regresion F2-P09 =="
docker compose exec backend python manage.py test \
  apps.payment_requests.tests.test_reports \
  apps.payment_requests.tests.test_dashboard \
  apps.payment_requests.tests.test_views

echo "== Check Django focal =="
docker compose exec backend python manage.py check

echo "== Estado Git =="
git status --short

echo "== Fix F2-P09 llamada helper OK =="
