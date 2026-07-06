#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_ROOT"

echo "== Fix F2-P08: importar PermissionDenied en payment_requests.views =="

TARGET="backend/apps/payment_requests/views.py"

if [ ! -f "$TARGET" ]; then
  echo "ERROR: no existe $TARGET"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_requests/views.py")
text = path.read_text(encoding="utf-8")

if "from django.core.exceptions import PermissionDenied" not in text:
    if "from django.core.exceptions import ValidationError" in text:
        text = text.replace(
            "from django.core.exceptions import ValidationError",
            "from django.core.exceptions import PermissionDenied, ValidationError",
        )
    else:
        marker = "from django.contrib.auth.mixins import LoginRequiredMixin\n"
        if marker not in text:
            raise SystemExit("ERROR: no se encontro punto seguro para insertar import PermissionDenied")
        text = text.replace(marker, marker + "from django.core.exceptions import PermissionDenied\n")

path.write_text(text, encoding="utf-8")
PY

echo "== Verificando import =="
grep -n "PermissionDenied" backend/apps/payment_requests/views.py

echo "== Ruff focal =="
docker compose exec backend ruff check apps/payment_requests/views.py apps/payment_requests/tests/test_dashboard.py apps/payment_requests/tests/test_accounts_payable_workbench.py

echo "== Tests focales F2-P08 =="
docker compose exec backend python manage.py test apps.payment_requests.tests.test_dashboard apps.payment_requests.tests.test_accounts_payable_workbench

echo "== Validacion global rapida =="
docker compose exec backend ruff check .
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== Estado posterior =="
git status --short
