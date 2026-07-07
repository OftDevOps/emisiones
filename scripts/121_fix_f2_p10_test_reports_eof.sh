#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

printf '%s\n' '== Fix F2-P10: normalizar EOF en test_reports y validar focal =='

python3 - <<'PY'
from pathlib import Path

path = Path('backend/apps/payment_requests/tests/test_reports.py')
text = path.read_text(encoding='utf-8')
# Remueve lineas en blanco al final y deja exactamente un newline final POSIX.
path.write_text(text.rstrip() + '\n', encoding='utf-8')
PY

printf '%s\n' '== Validando diff whitespace =='
git diff --check

printf '%s\n' '== Ruff focal F2-P10 =='
docker compose exec backend ruff check \
  apps/payment_requests/views.py \
  apps/payment_requests/urls.py \
  apps/payment_requests/tests/test_reports.py

printf '%s\n' '== Tests focales F2-P10 =='
docker compose exec backend python manage.py test \
  apps.payment_requests.tests.test_reports

printf '%s\n' '== Django check =='
docker compose exec backend python manage.py check

printf '%s\n' '== Estado Git =='
git status --short

printf '%s\n' '== Fix F2-P10 EOF OK =='
