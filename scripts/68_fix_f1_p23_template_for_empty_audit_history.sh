#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== Fix F1-P23: corregir sintaxis del bloque Historial de acciones criticas =="
echo "== Rama actual =="
git branch --show-current

echo "== Estado inicial =="
git status --short

TEMPLATE="backend/templates/payment_requests/paymentrequest_detail.html"
TEST_FILE="backend/apps/payment_execution/tests/test_cross_action_audit.py"
TS="$(date +%Y%m%d_%H%M%S)"

cp "$TEMPLATE" "${TEMPLATE}.bak_f1_p23_${TS}"
echo "Backup creado: ${TEMPLATE}.bak_f1_p23_${TS}"

python - <<'PY'
from pathlib import Path

path = Path("backend/templates/payment_requests/paymentrequest_detail.html")
text = path.read_text()

start_marker = '<h2 class="h5 mb-0">Historial de acciones críticas</h2>'
start = text.find(start_marker)
if start == -1:
    raise SystemExit("ERROR: no se encontro encabezado Historial de acciones criticas")

# Buscar inicio del contenedor del bloque: el <section o <div inmediatamente anterior al h2.
container_start = text.rfind('<section', 0, start)
container_tag = 'section'
if container_start == -1:
    container_start = text.rfind('<div', 0, start)
    container_tag = 'div'
if container_start == -1:
    raise SystemExit("ERROR: no se encontro contenedor antes del historial")

# El bloque historico fue insertado antes del enlace/boton Volver o antes del fin del bloque content.
end_candidates = []
for marker in [
    '<a href="{% url \'payment_requests:list\' %}"',
    '<a href="{% url \'payment_requests:dashboard\' %}"',
    '{% endblock %}',
]:
    idx = text.find(marker, start)
    if idx != -1:
        end_candidates.append(idx)
if not end_candidates:
    raise SystemExit("ERROR: no se encontro fin seguro para reemplazar bloque historial")
end = min(end_candidates)

new_block = '''<section class="card mb-4">
  <div class="card-header">
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
              <td>{{ action.created_at|date:"d/m/Y H:i" }}</td>
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
</section>

'''

updated = text[:container_start] + new_block + text[end:]
path.write_text(updated)
PY

echo "== Eliminar backups no versionables anteriores =="
rm -f backend/templates/payment_requests/paymentrequest_detail.html.bak_f1_p23_*
rm -f backend/apps/payment_execution/tests/test_cross_action_audit.py.bak_f1_p23_*
rm -f backend/apps/payment_approvals/models.py.bak_f1_p23_*
rm -f backend/apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py.bak_f1_p23_*

echo "== Fragmento historial corregido =="
grep -n "Historial de acciones críticas\|No hay acciones críticas registradas\|for action in approval_actions\|empty\|endfor" "$TEMPLATE"

echo "== Validacion focalizada =="
docker compose exec backend ruff check apps/payment_execution/tests/test_cross_action_audit.py apps/payment_approvals/models.py apps/payment_execution/models.py
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py test apps.payment_execution.tests.test_cross_action_audit
