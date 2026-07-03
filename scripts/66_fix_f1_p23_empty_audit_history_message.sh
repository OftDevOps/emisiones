#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== Fix F1-P23: mensaje vacio historial de acciones criticas =="
echo "== Rama actual =="
git branch --show-current

echo "== Estado inicial =="
git status --short

TEMPLATE="backend/templates/payment_requests/paymentrequest_detail.html"
TEST="backend/apps/payment_execution/tests/test_cross_action_audit.py"
MESSAGE="No hay acciones críticas registradas"

if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: no existe $TEMPLATE" >&2
  exit 1
fi
if [ ! -f "$TEST" ]; then
  echo "ERROR: no existe $TEST" >&2
  exit 1
fi

TS="$(date +%Y%m%d_%H%M%S)"
cp "$TEMPLATE" "${TEMPLATE}.bak_f1_p23_${TS}"
cp "$TEST" "${TEST}.bak_f1_p23_${TS}"
echo "Backups creados:"
echo "- ${TEMPLATE}.bak_f1_p23_${TS}"
echo "- ${TEST}.bak_f1_p23_${TS}"

python3 - <<'PY'
from pathlib import Path

template = Path("backend/templates/payment_requests/paymentrequest_detail.html")
test = Path("backend/apps/payment_execution/tests/test_cross_action_audit.py")
message = "No hay acciones críticas registradas"

text = template.read_text()

# Si el mensaje ya existe, no tocar el template.
if message not in text:
    # Caso normal: existe un for sobre approval_actions sin empty.
    if "{% for action in approval_actions %}" in text and "{% empty %}" not in text[text.find("{% for action in approval_actions %}"): text.find("{% endfor %}", text.find("{% for action in approval_actions %}"))]:
        start = text.find("{% for action in approval_actions %}")
        end = text.find("{% endfor %}", start)
        if end == -1:
            raise SystemExit("ERROR: se encontro for approval_actions pero no su endfor")
        insertion = (
            "{% empty %}\n"
            "              <tr>\n"
            "                <td colspan=\"5\">No hay acciones críticas registradas</td>\n"
            "              </tr>\n"
        )
        text = text[:end] + insertion + text[end:]
    elif "approval_actions" in text and "<tbody" in text:
        # Fallback defensivo: insertar un bloque independiente despues del titulo si no hay loop claro.
        marker = "Historial de acciones críticas"
        pos = text.find(marker)
        if pos == -1:
            raise SystemExit("ERROR: no se encontro bloque de Historial de acciones criticas")
        # No adivinar estructura HTML completa: agregar parrafo visible condicionado antes de la siguiente tabla.
        insert_pos = text.find("<table", pos)
        if insert_pos == -1:
            insert_pos = pos + len(marker)
        snippet = "\n{% if not approval_actions %}<p>No hay acciones críticas registradas</p>{% endif %}\n"
        text = text[:insert_pos] + snippet + text[insert_pos:]
    else:
        raise SystemExit("ERROR: no se pudo ubicar bloque approval_actions en template")

    template.write_text(text)

# Normalizar el test al mismo texto funcional.
t = test.read_text()
for old in [
    "No hay acciones criticas registradas",
    "Sin acciones críticas registradas",
    "Sin acciones criticas registradas",
    "No hay acciones registradas",
]:
    t = t.replace(old, message)

# Si por alguna razon el assert no existe, agregar uno dentro del test de historial vacio.
if message not in t:
    needle = "self.assertEqual(response.status_code, 200)"
    fn = "def test_detail_shows_empty_audit_history_message"
    idx = t.find(fn)
    if idx == -1:
        raise SystemExit("ERROR: no se encontro test_detail_shows_empty_audit_history_message")
    pos = t.find(needle, idx)
    if pos == -1:
        raise SystemExit("ERROR: no se encontro assert status 200 en test vacio")
    line_end = t.find("\n", pos)
    t = t[:line_end+1] + f'        self.assertContains(response, "{message}")\n' + t[line_end+1:]

test.write_text(t)
PY

echo "== Limpiar backups no versionables generados por fixes anteriores =="
rm -f backend/apps/payment_approvals/models.py.bak_f1_p23_*
rm -f backend/apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py.bak_f1_p23_*
rm -f backend/apps/payment_execution/tests/test_cross_action_audit.py.bak_f1_p23_*
rm -f backend/templates/payment_requests/paymentrequest_detail.html.bak_f1_p23_*

echo "== Verificar mensaje en template y test =="
grep -Rni "No hay acciones críticas registradas\|Historial de acciones críticas" "$TEMPLATE" "$TEST" || true

echo "== Validacion focalizada =="
docker compose exec backend ruff check \
  apps/payment_execution/tests/test_cross_action_audit.py \
  apps/payment_approvals/models.py \
  apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py

docker compose exec backend python manage.py check

echo "== makemigrations check =="
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== Test focalizado F1-P23 =="
docker compose exec backend python manage.py test apps.payment_execution.tests.test_cross_action_audit

echo "== Estado final =="
git status --short
