#!/usr/bin/env bash
set -euo pipefail

cd /home/dchirinos/oftalmiIA/emisiones/emisiones

echo "== Fix F2-P09: limpiar whitespace en dashboard y validar focal =="

python3 - <<'PY'
from pathlib import Path

path = Path("backend/templates/payment_requests/paymentrequest_dashboard.html")
text = path.read_text(encoding="utf-8")
lines = text.splitlines()
path.write_text("\n".join(line.rstrip() for line in lines) + "\n", encoding="utf-8")
PY

echo "== Validando diff whitespace =="
git diff --check

echo "== Ruff focal F2-P09 =="
docker compose exec backend ruff check \
  apps/accounts/context_processors.py \
  apps/accounts/role_permissions.py \
  apps/payment_requests/urls.py \
  apps/payment_requests/views.py \
  apps/payment_requests/tests/test_reports.py

echo "== Tests focales F2-P09 =="
docker compose exec backend python manage.py test \
  apps.payment_requests.tests.test_reports \
  apps.payment_requests.tests.test_dashboard

echo "== Check Django focal =="
docker compose exec backend python manage.py check

echo "== Estado Git =="
git status --short

echo "== Fix F2-P09 whitespace OK =="
