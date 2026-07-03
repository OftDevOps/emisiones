#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== Fix F1-P23: sanear sintaxis payment_approvals/models.py =="
echo "== Rama actual =="
git branch --show-current

echo "== Estado inicial =="
git status --short

TARGET="backend/apps/payment_approvals/models.py"
BACKUP="${TARGET}.bak_f1_p23_$(date +%Y%m%d_%H%M%S)"
cp "$TARGET" "$BACKUP"
echo "Backup creado: $BACKUP"

python - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_approvals/models.py")
text = path.read_text()

# Normaliza indentacion accidental de SKIPPED dentro del enum PaymentApprovalStepStatus.
text = text.replace("\n        SKIPPED = \"SKIPPED\", \"Omitido\"", "\n    SKIPPED = \"SKIPPED\", \"Omitido\"")

# Asegura que PAYMENT_EXECUTED exista dentro de ApprovalActionType, una sola vez.
lines = text.splitlines()
new_lines = []
in_action_type = False
inserted = False
seen_payment_executed = False

for line in lines:
    if line.startswith("class ApprovalActionType(models.TextChoices):"):
        in_action_type = True
        inserted = False
        seen_payment_executed = False
        new_lines.append(line)
        continue

    if in_action_type:
        if line.startswith("class ") and not line.startswith("class ApprovalActionType"):
            if not inserted and not seen_payment_executed:
                new_lines.append('    PAYMENT_EXECUTED = "PAYMENT_EXECUTED", "Pago ejecutado"')
            in_action_type = False
            new_lines.append(line)
            continue

        if "PAYMENT_EXECUTED" in line:
            if not seen_payment_executed:
                new_lines.append('    PAYMENT_EXECUTED = "PAYMENT_EXECUTED", "Pago ejecutado"')
                seen_payment_executed = True
                inserted = True
            continue

        if not inserted and line.strip() and line.startswith("    "):
            new_lines.append('    PAYMENT_EXECUTED = "PAYMENT_EXECUTED", "Pago ejecutado"')
            inserted = True
            seen_payment_executed = True

    new_lines.append(line)

if in_action_type and not inserted and not seen_payment_executed:
    new_lines.append('    PAYMENT_EXECUTED = "PAYMENT_EXECUTED", "Pago ejecutado"')

path.write_text("\n".join(new_lines) + "\n")
PY

echo "== Fragmento corregido PaymentApprovalStepStatus / ApprovalActionType =="
sed -n '1,45p' "$TARGET"

echo "== Validacion sintactica local =="
python -m py_compile "$TARGET"
python -m py_compile backend/apps/payment_execution/models.py
python -m py_compile backend/apps/payment_execution/tests/test_cross_action_audit.py

echo "== Ruff focalizado =="
docker compose exec backend ruff check apps/payment_approvals/models.py apps/payment_execution/models.py apps/payment_execution/tests/test_cross_action_audit.py

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== makemigrations check =="
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== Tests focalizados F1-P23 =="
docker compose exec backend python manage.py test apps.payment_execution.tests.test_cross_action_audit apps.payment_execution.tests.test_traceability apps.payment_execution.tests.test_views

echo "== Estado final =="
git status --short

echo "OK: sintaxis saneada. Si las validaciones focalizadas pasan, ejecutar validacion completa estandar."
