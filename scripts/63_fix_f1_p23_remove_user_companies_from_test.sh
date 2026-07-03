#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$ROOT"

echo "== Fix F1-P23: remover relacion inexistente user.companies del test =="
echo "== Rama actual =="
git branch --show-current

echo "== Estado inicial =="
git status --short

TEST_FILE="backend/apps/payment_execution/tests/test_cross_action_audit.py"

if [[ ! -f "$TEST_FILE" ]]; then
  echo "ERROR: no existe $TEST_FILE" >&2
  exit 1
fi

BACKUP="${TEST_FILE}.bak_f1_p23_$(date +%Y%m%d_%H%M%S)"
cp "$TEST_FILE" "$BACKUP"
echo "Backup creado: $BACKUP"

python - <<'PY'
from pathlib import Path
path = Path("backend/apps/payment_execution/tests/test_cross_action_audit.py")
text = path.read_text()
lines = text.splitlines()
new_lines = []
removed = []
for line in lines:
    if ".companies.add(" in line:
        removed.append(line)
        continue
    new_lines.append(line)
path.write_text("\n".join(new_lines) + "\n")
print("Lineas removidas:")
for line in removed:
    print(line)
if not removed:
    print("WARN: no se encontraron lineas .companies.add(...)")
PY

echo "== Fragmento setUp actual =="
sed -n '1,120p' "$TEST_FILE"

echo "== Validacion focalizada =="
docker compose exec backend ruff check \
  apps/payment_execution/tests/test_cross_action_audit.py \
  apps/payment_approvals/models.py \
  apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py \
  apps/payment_execution/models.py

docker compose exec backend python manage.py check

echo "== makemigrations check =="
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== Test focalizado F1-P23 =="
docker compose exec backend python manage.py test apps.payment_execution.tests.test_cross_action_audit

echo "== Limpiar backup del test si todo paso =="
rm -f "$BACKUP"

echo "OK: test_cross_action_audit.py saneado sin user.companies."
