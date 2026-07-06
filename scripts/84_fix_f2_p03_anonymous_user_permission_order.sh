#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

REQ_VIEWS="backend/apps/payment_requests/views.py"

printf '== Fix F2-P03: no evaluar permisos operativos sobre AnonymousUser ==\n'

python3 - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_requests/views.py")
text = path.read_text(encoding="utf-8")

old = '''def _require_operational_permission(user, permission: str, message: str) -> None:\n    if not user_has_permission(user, permission):\n        raise PermissionDenied(message)\n'''

new = '''def _require_operational_permission(user, permission: str, message: str) -> None:\n    if not getattr(user, "is_authenticated", False):\n        return\n    if not user_has_permission(user, permission):\n        raise PermissionDenied(message)\n'''

if old not in text:
    if 'def _require_operational_permission(user, permission: str, message: str) -> None:' in text and 'getattr(user, "is_authenticated", False)' in text:
        print("OK: helper ya protege AnonymousUser.")
    else:
        raise SystemExit("ERROR: no se encontro el helper esperado en payment_requests/views.py")
else:
    path.write_text(text.replace(old, new), encoding="utf-8")
    print("OK: helper actualizado para delegar AnonymousUser a LoginRequiredMixin.")
PY

printf '== Ruff ==\n'
docker compose exec backend ruff check .

printf '== Tests focales ==\n'
docker compose exec backend python manage.py test \
  apps.payment_requests.tests.test_dashboard.PaymentRequestDashboardViewTests.test_dashboard_requires_login \
  apps.payment_requests.tests.test_views.PaymentRequestViewsTests.test_list_requires_login

printf '== Estado posterior ==\n'
git status --short
