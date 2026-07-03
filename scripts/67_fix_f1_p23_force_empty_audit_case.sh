#!/usr/bin/env bash
set -euo pipefail

echo "== Fix F1-P23: forzar caso vacio real del historial critico =="
echo "== Rama actual =="
git branch --show-current

echo "== Estado inicial =="
git status --short

TEST_FILE="backend/apps/payment_execution/tests/test_cross_action_audit.py"
TEMPLATE_FILE="backend/templates/payment_requests/paymentrequest_detail.html"

if [[ ! -f "$TEST_FILE" ]]; then
  echo "ERROR: no existe $TEST_FILE" >&2
  exit 1
fi
if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "ERROR: no existe $TEMPLATE_FILE" >&2
  exit 1
fi

TS="$(date +%Y%m%d_%H%M%S)"
cp "$TEST_FILE" "${TEST_FILE}.bak_f1_p23_${TS}"
cp "$TEMPLATE_FILE" "${TEMPLATE_FILE}.bak_f1_p23_${TS}"
echo "Backups creados:"
echo "- ${TEST_FILE}.bak_f1_p23_${TS}"
echo "- ${TEMPLATE_FILE}.bak_f1_p23_${TS}"

python - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_execution/tests/test_cross_action_audit.py")
text = path.read_text()
old = '''    def test_detail_shows_empty_audit_history_message(self):\n        self.client.force_login(self.user)\n\n        response = self.client.get(\n            reverse("payment_requests:detail", kwargs={"pk": self.payment_request.pk})\n        )\n\n        self.assertEqual(response.status_code, 200)\n        self.assertContains(response, "No hay acciones críticas registradas")\n'''
new = '''    def test_detail_shows_empty_audit_history_message(self):\n        PaymentApprovalAction.objects.filter(payment_request=self.payment_request).delete()\n        self.client.force_login(self.user)\n\n        response = self.client.get(\n            reverse("payment_requests:detail", kwargs={"pk": self.payment_request.pk})\n        )\n\n        self.assertEqual(response.status_code, 200)\n        self.assertContains(response, "Historial de acciones críticas")\n        self.assertContains(response, "No hay acciones críticas registradas")\n'''
if old not in text:
    # fallback: replace only first assertContains empty block area by injecting delete after def line
    marker = "    def test_detail_shows_empty_audit_history_message(self):\n"
    if marker not in text:
        raise SystemExit("ERROR: no se encontro test_detail_shows_empty_audit_history_message")
    text = text.replace(marker, marker + "        PaymentApprovalAction.objects.filter(payment_request=self.payment_request).delete()\n", 1)
    if 'self.assertContains(response, "Historial de acciones críticas")' not in text:
        text = text.replace(
            '        self.assertEqual(response.status_code, 200)\n        self.assertContains(response, "No hay acciones críticas registradas")',
            '        self.assertEqual(response.status_code, 200)\n        self.assertContains(response, "Historial de acciones críticas")\n        self.assertContains(response, "No hay acciones críticas registradas")',
            1,
        )
else:
    text = text.replace(old, new)
path.write_text(text)
PY

python - <<'PY'
from pathlib import Path

path = Path("backend/templates/payment_requests/paymentrequest_detail.html")
text = path.read_text()
# Normalize a common bad pattern where the entire table/body is wrapped in {% if approval_actions %}
# and the empty row is therefore unreachable. Keep it conservative: only act if the expected
# heading and message exist.
if "Historial de acciones críticas" not in text:
    raise SystemExit("ERROR: no se encontro bloque Historial de acciones criticas en template")
if "No hay acciones críticas registradas" not in text:
    raise SystemExit("ERROR: no se encontro mensaje vacio en template")

# If template uses a for loop without empty, add empty branch.
if "{% for action in approval_actions %}" in text and "{% empty %}" not in text:
    text = text.replace(
        "{% endfor %}",
        "{% empty %}\n              <tr>\n                <td colspan=\"5\">No hay acciones críticas registradas</td>\n              </tr>\n            {% endfor %}",
        1,
    )

# If an outer conditional hides the block when approval_actions is empty, remove only the simplest wrappers.
text = text.replace("{% if approval_actions %}\n", "")
text = text.replace("{% endif %}\n", "", 1) if text.count("{% endif %}") == 1 and "Historial de acciones críticas" in text else text

path.write_text(text)
PY

echo "== Limpiar backups no versionables =="
rm -f backend/apps/payment_execution/tests/test_cross_action_audit.py.bak_f1_p23_*
rm -f backend/templates/payment_requests/paymentrequest_detail.html.bak_f1_p23_*
rm -f backend/apps/payment_approvals/models.py.bak_f1_p23_*
rm -f backend/apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py.bak_f1_p23_*

echo "== Verificaciones rapidas =="
grep -Rni "No hay acciones críticas registradas\|Historial de acciones críticas" "$TEMPLATE_FILE" "$TEST_FILE"

echo "== Validacion focalizada =="
docker compose exec backend ruff check apps/payment_execution/tests/test_cross_action_audit.py apps/payment_approvals/models.py apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py
docker compose exec backend python manage.py check
echo "== makemigrations check =="
docker compose exec backend python manage.py makemigrations --check --dry-run
echo "== Test focalizado F1-P23 =="
docker compose exec backend python manage.py test apps.payment_execution.tests.test_cross_action_audit
