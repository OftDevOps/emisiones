#!/usr/bin/env bash
set -euo pipefail

echo "== Fix F1-P23: alinear migracion 0002 payment_approvals con modelo actual =="

ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$ROOT"

echo "== Rama actual =="
git branch --show-current

echo "== Estado inicial =="
git status --short

MODELS="backend/apps/payment_approvals/models.py"
MIGRATION="backend/apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py"

if [[ ! -f "$MODELS" ]]; then
  echo "ERROR: no existe $MODELS" >&2
  exit 1
fi

mkdir -p "$(dirname "$MIGRATION")"

TS="$(date +%Y%m%d_%H%M%S)"
if [[ -f "$MIGRATION" ]]; then
  cp "$MIGRATION" "${MIGRATION}.bak_f1_p23_${TS}"
  echo "Backup migracion creado: ${MIGRATION}.bak_f1_p23_${TS}"
fi

cat > "$MIGRATION" <<'PY'
# Generated manually for F1-P23.
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("payment_approvals", "0001_initial"),
    ]

    operations = [
        migrations.AlterField(
            model_name="paymentapprovalaction",
            name="action",
            field=models.CharField(
                choices=[
                    ("PAYMENT_EXECUTED", "Pago ejecutado"),
                    ("SUBMIT", "Enviar"),
                    ("APPROVE", "Aprobar"),
                    ("REJECT", "Rechazar"),
                    ("CANCEL", "Cancelar"),
                    ("COMMENT", "Comentario"),
                ],
                max_length=40,
                verbose_name="accion",
            ),
        ),
    ]
PY

echo "== Fragmento migracion 0002 =="
sed -n '1,120p' "$MIGRATION"

echo "== Limpieza de migraciones 0003 no deseadas si existen =="
find backend/apps/payment_approvals/migrations -maxdepth 1 -type f \
  \( -name '0003_alter_paymentapprovalaction_action.py' -o -name '0003_alter_paymentapprovalaction_action_and_more.py' \) \
  -print -delete || true

echo "== Validacion focalizada =="
docker compose exec backend ruff check backend/apps/payment_approvals/models.py backend/apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py

docker compose exec backend python manage.py check

echo "== makemigrations check: debe decir No changes detected =="
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== Estado final =="
git status --short

echo "OK: migracion 0002 alineada con ApprovalActionType actual. Ejecuta validacion completa antes de commit."
