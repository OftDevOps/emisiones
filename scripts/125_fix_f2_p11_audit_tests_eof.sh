#!/usr/bin/env bash
set -euo pipefail

cd /home/dchirinos/oftalmiIA/emisiones/emisiones

echo "== Fix F2-P11: normalizar EOF en tests de auditoria y validar focal =="

python - <<'PY'
from pathlib import Path
path = Path('backend/apps/payment_approvals/tests/test_cross_action_audit_workbench.py')
text = path.read_text(encoding='utf-8')
text = text.rstrip() + '\n'
path.write_text(text, encoding='utf-8')
PY

echo "== Validando diff whitespace =="
git diff --check

echo "== Ruff focal F2-P11 =="
docker compose exec backend ruff check \
  backend/apps/payment_approvals/views.py \
  backend/apps/payment_approvals/tests/test_cross_action_audit_workbench.py

echo "== Tests focales F2-P11 =="
docker compose exec backend python manage.py test \
  apps.payment_approvals.tests.test_cross_action_audit_workbench

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== Estado Git =="
git status --short

echo "== Fix F2-P11 EOF OK =="
