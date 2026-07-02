#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' '== FIX F1-P11: payment_requests tests and index names =='

if [ ! -f "backend/manage.py" ]; then
  printf '%s\n' 'ERROR: run this script from repository root: /home/dchirinos/oftalmiIA/emisiones/emisiones' >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

models_path = Path('backend/apps/payment_requests/models.py')
tests_path = Path('backend/apps/payment_requests/tests/test_models.py')

if not models_path.exists():
    raise SystemExit('ERROR: backend/apps/payment_requests/models.py not found')
if not tests_path.exists():
    raise SystemExit('ERROR: backend/apps/payment_requests/tests/test_models.py not found')

models = models_path.read_text()
models = models.replace('models.Index(fields=["company", "status"]),', 'models.Index(fields=["company", "status"], name="payment_req_company_status_idx"),')
models = models.replace('models.Index(fields=["beneficiary", "status"]),', 'models.Index(fields=["beneficiary", "status"], name="payment_req_beneficiary_status_idx"),')
models = models.replace('models.Index(fields=["requested_by", "status"]),', 'models.Index(fields=["requested_by", "status"], name="payment_req_requested_status_idx"),')
models = models.replace('models.Index(fields=["created_at"]),', 'models.Index(fields=["created_at"], name="payment_req_created_at_idx"),')
models_path.write_text(models)

tests = tests_path.read_text()
tests = tests.replace('name="Proveedor Demo C.A.",', 'legal_name="Proveedor Demo C.A.",')
tests = tests.replace('name="Proveedor Otra Empresa",', 'legal_name="Proveedor Otra Empresa",')
tests_path.write_text(tests)
PY

# Remove accidental auto-generated index-rename migration if someone created it after the dry run.
rm -f backend/apps/payment_requests/migrations/0002_rename_payment_req_company_status_idx_payment_req_company_ec9f07_idx_and_more.py

printf '%s\n' 'OK: F1-P11 fix applied.'
printf '%s\n' 'Next: run check, makemigrations --check --dry-run, migrate, and tests.'
