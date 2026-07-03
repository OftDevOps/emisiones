#!/usr/bin/env bash
set -euo pipefail

echo "== F1-P25: agregar navegacion de auditoria al dashboard operativo =="

PROJECT_ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_ROOT"

echo "== Rama actual =="
git branch --show-current

echo "== Estado inicial =="
git status --short

DASHBOARD_TEMPLATE="backend/templates/payment_requests/paymentrequest_dashboard.html"
DASHBOARD_TEST="backend/apps/payment_requests/tests/test_dashboard.py"

if [[ ! -f "$DASHBOARD_TEMPLATE" ]]; then
  echo "ERROR: no existe $DASHBOARD_TEMPLATE" >&2
  exit 1
fi

if [[ ! -f "$DASHBOARD_TEST" ]]; then
  echo "ERROR: no existe $DASHBOARD_TEST" >&2
  exit 1
fi

TS="$(date +%Y%m%d_%H%M%S)"
cp "$DASHBOARD_TEMPLATE" "$DASHBOARD_TEMPLATE.bak_f1_p25_$TS"
cp "$DASHBOARD_TEST" "$DASHBOARD_TEST.bak_f1_p25_$TS"

echo "== Insertar bloque Accesos operativos en dashboard si no existe =="
python - <<'PY'
from pathlib import Path

path = Path("backend/templates/payment_requests/paymentrequest_dashboard.html")
text = path.read_text()

if "Accesos operativos" not in text:
    marker = "<section>\n  <h2>Resumen ejecutivo</h2>"
    block = """<section>\n  <h2>Accesos operativos</h2>\n  <ul>\n    <li><a href=\"{% url 'payment_approvals:pending' %}\">Pendientes por aprobar</a></li>\n    <li><a href=\"{% url 'payment_approvals:audit' %}\">Auditoría de acciones críticas</a></li>\n    <li><a href=\"{% url 'payment_requests:accounts_payable' %}\">Cuentas por Pagar</a></li>\n  </ul>\n</section>\n\n"""
    if marker not in text:
        raise SystemExit("ERROR: no se encontro punto de insercion en dashboard")
    text = text.replace(marker, block + marker, 1)

path.write_text(text)
PY

echo "== Agregar tests de navegacion si no existen =="
python - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_requests/tests/test_dashboard.py")
text = path.read_text()

if "test_dashboard_shows_operational_access_links" not in text:
    test_block = r'''

    def test_dashboard_shows_operational_access_links(self):
        self.client.force_login(self.user)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Accesos operativos")
        self.assertContains(response, "Pendientes por aprobar")
        self.assertContains(response, "Auditoría de acciones críticas")
        self.assertContains(response, "Cuentas por Pagar")
        self.assertContains(response, reverse("payment_approvals:pending"))
        self.assertContains(response, reverse("payment_approvals:audit"))
        self.assertContains(response, reverse("payment_requests:accounts_payable"))
'''
    text = text.rstrip() + test_block + "\n"

path.write_text(text)
PY

echo "== Limpiar backups no versionables generados por este script =="
rm -f backend/templates/payment_requests/paymentrequest_dashboard.html.bak_f1_p25_*
rm -f backend/apps/payment_requests/tests/test_dashboard.py.bak_f1_p25_*

echo "== Verificacion rapida =="
grep -Rni "Accesos operativos\|Auditoría de acciones críticas\|payment_approvals:audit" "$DASHBOARD_TEMPLATE" "$DASHBOARD_TEST"

echo "== Validacion focalizada =="
docker compose exec backend ruff check apps/payment_requests/tests/test_dashboard.py
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py test apps.payment_requests.tests.test_dashboard

echo "== OK F1-P25 aplicado. Ejecutar validacion completa antes de commit. =="
