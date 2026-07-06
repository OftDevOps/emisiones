#!/usr/bin/env bash
set -euo pipefail

cd /home/dchirinos/oftalmiIA/emisiones/emisiones

echo "== Fix F2-P08: alinear test CxP con matriz de permisos =="

FILE="backend/apps/payment_requests/tests/test_accounts_payable_workbench.py"

if [[ ! -f "$FILE" ]]; then
  echo "ERROR: no existe $FILE"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_requests/tests/test_accounts_payable_workbench.py")
text = path.read_text(encoding="utf-8")

old = '''    def test_non_accounts_payable_user_gets_403(self):
        self.client.force_login(self.finance_user)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 403)
'''

new = '''    def test_user_without_accounts_payable_permission_gets_403(self):
        requester_user = self.create_user(
            "solicitante.cxp@oftalmi.com",
            self.company,
            UserRole.SOLICITANTE,
        )
        self.client.force_login(requester_user)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 403)
'''

if old not in text:
    if "test_user_without_accounts_payable_permission_gets_403" in text:
        print("OK: el test negativo ya estaba alineado con la matriz.")
    else:
        raise SystemExit("ERROR: bloque esperado no encontrado; revisar test manualmente.")
else:
    text = text.replace(old, new)
    path.write_text(text, encoding="utf-8")
    print("OK: test negativo actualizado de FINANZAS a SOLICITANTE.")
PY

echo "== Fragmento actualizado =="
grep -n "test_user_without_accounts_payable_permission_gets_403\|test_finance_user_can_access_accounts_payable_per_permission_matrix" "$FILE" || true

echo "== Ruff focal =="
docker compose exec backend ruff check \
  apps/payment_requests/views.py \
  apps/payment_requests/tests/test_dashboard.py \
  apps/payment_requests/tests/test_accounts_payable_workbench.py

echo "== Tests focales F2-P08 =="
docker compose exec backend python manage.py test \
  apps.payment_requests.tests.test_dashboard \
  apps.payment_requests.tests.test_accounts_payable_workbench

echo "== F2-P08 fix focal OK =="
