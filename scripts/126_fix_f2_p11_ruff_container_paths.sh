#!/usr/bin/env bash
set -euo pipefail

cd /home/dchirinos/oftalmiIA/emisiones/emisiones

echo "== Fix F2-P11: corregir validacion Ruff con rutas internas del contenedor =="

echo "== Verificando archivos esperados =="
test -f backend/apps/payment_approvals/tests/test_cross_action_audit_workbench.py
test -f backend/apps/payment_approvals/views.py
test -f backend/templates/payment_approvals/cross_action_audit_workbench.html

python3 - <<'PY'
from pathlib import Path

paths = [
    Path("backend/apps/payment_approvals/tests/test_cross_action_audit_workbench.py"),
    Path("backend/apps/payment_approvals/views.py"),
    Path("backend/templates/payment_approvals/cross_action_audit_workbench.html"),
    Path("docs/roadmap_fase2.md"),
    Path("docs/f2_p11_auditoria_extendida.md"),
]

for path in paths:
    if not path.exists():
        continue
    text = path.read_text(encoding="utf-8")
    text = text.rstrip() + "\n"
    path.write_text(text, encoding="utf-8")
PY

echo "== Validando diff whitespace =="
git diff --check

echo "== Ruff focal F2-P11 con rutas internas del contenedor =="
docker compose exec backend ruff check \
  apps/payment_approvals/tests/test_cross_action_audit_workbench.py \
  apps/payment_approvals/views.py

echo "== Tests focales F2-P11 =="
docker compose exec backend python manage.py test \
  apps.payment_approvals.tests.test_cross_action_audit_workbench

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== Estado Git =="
git status --short

echo "== Fix F2-P11 rutas Ruff OK =="
