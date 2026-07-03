#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$ROOT"

TEMPLATE="backend/templates/payment_requests/paymentrequest_detail.html"
TEST="backend/apps/payment_execution/tests/test_cross_action_audit.py"

echo "== Fix F1-P23: eliminar else huerfano restante en template =="
echo "== Rama actual =="
git branch --show-current

echo "== Estado inicial =="
git status --short

if [[ ! -f "$TEMPLATE" ]]; then
  echo "ERROR: no existe $TEMPLATE" >&2
  exit 1
fi

stamp="$(date +%Y%m%d_%H%M%S)"
cp "$TEMPLATE" "$TEMPLATE.bak_f1_p23_$stamp"
echo "Backup creado: $TEMPLATE.bak_f1_p23_$stamp"

echo "== Limpiar backups no versionables =="
rm -f backend/templates/payment_requests/paymentrequest_detail.html.bak_f1_p23_*
rm -f backend/apps/payment_execution/tests/test_cross_action_audit.py.bak_f1_p23_*
rm -f backend/apps/payment_approvals/models.py.bak_f1_p23_*
rm -f backend/apps/payment_approvals/migrations/*.bak_f1_p23_*

python - <<'PY'
from pathlib import Path

path = Path("backend/templates/payment_requests/paymentrequest_detail.html")
text = path.read_text()

# Rebuild the critical-actions history block as the single canonical block.
start_marker = '<h2 class="h5 mb-0">Historial de acciones críticas</h2>'
start = text.find(start_marker)
if start == -1:
    raise SystemExit("ERROR: no se encontro el titulo Historial de acciones criticas")

# Move start to the beginning of the containing card/div if present.
card_start = text.rfind('<div class="card', 0, start)
if card_start != -1:
    start = card_start

# End at the next top-level card after this block, or before payment execution traceability if present.
search_from = text.find(start_marker) + len(start_marker)
next_candidates = []
for marker in [
    '<h2 class="h5 mb-0">Trazabilidad de ejecución de pago</h2>',
    '<h2 class="h5 mb-0">Ejecución de pago</h2>',
    '<h2 class="h5 mb-0">Documentos</h2>',
    '<h2 class="h5 mb-0">Acciones',
]:
    pos = text.find(marker, search_from)
    if pos != -1:
        cstart = text.rfind('<div class="card', 0, pos)
        if cstart > start:
            next_candidates.append(cstart)

# Fallback: after first closing card block following our marker; keep conservative.
if next_candidates:
    end = min(next_candidates)
else:
    # If no next known card exists, stop before endblock to avoid touching footer/block close.
    endblock = text.find('{% endblock %}', search_from)
    if endblock == -1:
        raise SystemExit("ERROR: no se encontro endblock para delimitar")
    end = endblock

block = '''<div class="card mb-4">
  <div class="card-header d-flex justify-content-between align-items-center">
    <h2 class="h5 mb-0">Historial de acciones críticas</h2>
  </div>
  <div class="card-body p-0">
    <div class="table-responsive">
      <table class="table table-sm mb-0">
        <thead>
          <tr>
            <th>Fecha</th>
            <th>Acción</th>
            <th>Usuario</th>
            <th>Rol</th>
            <th>Comentario</th>
          </tr>
        </thead>
        <tbody>
          {% for action in approval_actions %}
            <tr>
              <td>{{ action.created_at|date:"Y-m-d H:i" }}</td>
              <td>{{ action.get_action_display }}</td>
              <td>{{ action.performed_by }}</td>
              <td>{{ action.get_role_display }}</td>
              <td>{{ action.comment|default:"-" }}</td>
            </tr>
          {% empty %}
            <tr>
              <td colspan="5">No hay acciones críticas registradas</td>
            </tr>
          {% endfor %}
        </tbody>
      </table>
    </div>
  </div>
</div>

'''
text = text[:start] + block + text[end:]

# Remove orphan else blocks created by previous automated fixes. Keep legitimate else tags only if there is an unmatched opening tag in the current stack.
lines = text.splitlines()
stack = []
clean = []
for line in lines:
    stripped = line.strip()
    tag = stripped
    if tag.startswith('{%') and tag.endswith('%}'):
        token = tag[2:-2].strip().split()[0]
        if token in {'if', 'for', 'with'}:
            stack.append(token)
        elif token == 'else':
            if not stack or stack[-1] not in {'if', 'for'}:
                continue
        elif token in {'endif', 'endfor', 'endwith'}:
            expected = {'endif': 'if', 'endfor': 'for', 'endwith': 'with'}[token]
            # Pop the closest matching opener if present.
            if expected in stack:
                while stack:
                    top = stack.pop()
                    if top == expected:
                        break
    clean.append(line)

text = "\n".join(clean) + "\n"
path.write_text(text)
PY

echo "== Verificacion de tags problematicos =="
grep -n "{% else %}\|Historial de acciones críticas\|No hay acciones críticas registradas" "$TEMPLATE" || true

echo "== Validacion focalizada =="
docker compose exec backend ruff check apps/payment_execution/tests/test_cross_action_audit.py
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py test apps.payment_execution.tests.test_cross_action_audit

echo "OK: F1-P23 template y test focalizado saneados."
