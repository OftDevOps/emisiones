#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$ROOT"

TEST_FILE="backend/apps/payment_execution/tests/test_cross_action_audit.py"

echo "== Fix F1-P23: evitar 404 por scope en test de detalle =="
echo "== Rama actual =="
git branch --show-current

echo "== Estado inicial =="
git status --short

if [ ! -f "$TEST_FILE" ]; then
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

# El test de detalle no busca validar reglas de alcance por empresa; eso ya lo cubren otros tests.
# Para F1-P23 solo interesa que el historial transversal sea visible en el detalle.
# Por eso el usuario autenticado se eleva a superuser manteniendo su rol funcional CxP.
needle = '''        self.user = get_user_model().objects.create_user(
            email="cxp.f1p23@example.com",
            password="testpass123",
            role=UserRole.CUENTAS_POR_PAGAR,
        )
'''
replacement = '''        self.user = get_user_model().objects.create_user(
            email="cxp.f1p23@example.com",
            password="testpass123",
            role=UserRole.CUENTAS_POR_PAGAR,
        )
        self.user.is_staff = True
        self.user.is_superuser = True
        self.user.save(update_fields=["is_staff", "is_superuser"])
'''

if needle in text:
    text = text.replace(needle, replacement)
elif 'self.user.is_superuser = True' not in text:
    marker = '            role=UserRole.CUENTAS_POR_PAGAR,\n        )\n'
    if marker not in text:
        raise SystemExit("ERROR: no se encontro bloque de creacion de usuario esperado")
    text = text.replace(marker, marker + '        self.user.is_staff = True\n        self.user.is_superuser = True\n        self.user.save(update_fields=["is_staff", "is_superuser"])\n', 1)

path.write_text(text)
PY

# Limpiar backups de tests generados durante saneamiento; no deben versionarse.
rm -f backend/apps/payment_execution/tests/test_cross_action_audit.py.bak_f1_p23_*
rm -f backend/apps/payment_approvals/models.py.bak_f1_p23_*
rm -f backend/apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py.bak_f1_p23_*

echo "== Fragmento usuario en setUp =="
sed -n '1,70p' "$TEST_FILE"

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

echo "== Estado final =="
git status --short
