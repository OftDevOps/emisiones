#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== F2-PILOT-BR04E-FIX6: corregir comillas escapadas en asserts Compras =="
echo "== Ruta =="
pwd

echo "== Estado inicial =="
git status --short

python3 - <<'PY'
from pathlib import Path

files = [
    Path("backend/apps/accounts/tests/test_role_navigation_template.py"),
    Path("backend/apps/payment_requests/tests/test_dashboard.py"),
]

for path in files:
    text = path.read_text(encoding="utf-8")
    original = text
    text = text.replace('\\"Compras\\"', '"Compras"')
    if text != original:
        path.write_text(text, encoding="utf-8")
        print(f"OK: corregidas comillas escapadas en {path}")
    else:
        print(f"INFO: sin comillas escapadas en {path}")

# Asegurar asserts finales correctos.
path = Path("backend/apps/accounts/tests/test_role_navigation_template.py")
text = path.read_text(encoding="utf-8")
text = text.replace(
    '    def test_cuentas_por_pagar_sees_compras_link(self):\n'
    '        user = self.create_user("cxp.nav@oftalmi.com", UserRole.CUENTAS_POR_PAGAR)\n'
    '        self.client.force_login(user)\n\n'
    '        response = self.client.get(reverse("payment_requests:dashboard"))\n\n'
    '        self.assertEqual(response.status_code, 200)\n'
    '        content = response.content.decode("utf-8")\n'
    '        self.assertNotIn("Compras", content)\n',
    '    def test_cuentas_por_pagar_sees_compras_link(self):\n'
    '        user = self.create_user("cxp.nav@oftalmi.com", UserRole.CUENTAS_POR_PAGAR)\n'
    '        self.client.force_login(user)\n\n'
    '        response = self.client.get(reverse("payment_requests:dashboard"))\n\n'
    '        self.assertEqual(response.status_code, 200)\n'
    '        content = response.content.decode("utf-8")\n'
    '        self.assertIn("Compras", content)\n',
)
path.write_text(text, encoding="utf-8")

path = Path("backend/apps/payment_requests/tests/test_dashboard.py")
text = path.read_text(encoding="utf-8")
text = text.replace(
    '        self.assertNotContains(response, "Compras")\n'
    '        self.assertContains(response, reverse("payment_approvals:pending"))\n'
    '        self.assertContains(response, reverse("payment_requests:accounts_payable"))\n',
    '        self.assertContains(response, "Compras")\n'
    '        self.assertContains(response, reverse("payment_approvals:pending"))\n'
    '        self.assertContains(response, reverse("payment_requests:accounts_payable"))\n',
    1,
)
path.write_text(text, encoding="utf-8")
PY

echo "== Fragmentos corregidos =="
grep -n "Compras\|accounts_payable" backend/apps/accounts/tests/test_role_navigation_template.py backend/apps/payment_requests/tests/test_dashboard.py | head -n 80

echo "== Validacion diff whitespace =="
git diff --check

echo "== Ruff =="
docker compose exec backend ruff check .

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== Tests focales BR04E =="
docker compose exec backend python manage.py test \
  apps.accounts.tests.test_role_navigation_template \
  apps.accounts.tests.test_role_navigation_integrated_matrix \
  apps.accounts.tests.test_role_navigation_context \
  apps.payment_requests.tests.test_dashboard \
  apps.payment_requests.tests.test_accounts_payable_workbench \
  apps.payment_execution.tests.test_views

echo "== Estado final =="
git status --short

echo "== FIN F2-PILOT-BR04E-FIX6 =="
