#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
TEMPLATE="backend/templates/payment_requests/paymentrequest_detail.html"

cd "$PROJECT_DIR"

echo "== Fix F1-P23: resetear template desde origin/develop e insertar bloque limpio de auditoria =="
echo "== Rama actual =="
git branch --show-current

echo "== Estado inicial =="
git status --short

if ! git rev-parse --verify origin/develop >/dev/null 2>&1; then
  echo "ERROR: origin/develop no existe localmente. Ejecuta: git fetch origin develop" >&2
  exit 1
fi

TS="$(date +%Y%m%d_%H%M%S)"
cp "$TEMPLATE" "${TEMPLATE}.bak_f1_p23_${TS}"
echo "Backup creado: ${TEMPLATE}.bak_f1_p23_${TS}"

echo "== Restaurar template base desde origin/develop =="
git checkout origin/develop -- "$TEMPLATE"

echo "== Insertar bloque limpio Historial de acciones criticas antes del ultimo endblock =="
python - <<'PY'
from pathlib import Path

path = Path("backend/templates/payment_requests/paymentrequest_detail.html")
text = path.read_text()

# Evitar duplicados si el script se ejecuta dos veces.
if "Historial de acciones críticas" not in text:
    block = '''

<section class="card mt-4">
  <div class="card-header d-flex justify-content-between align-items-center">
    <h2 class="h5 mb-0">Historial de acciones críticas</h2>
  </div>
  <div class="card-body p-0">
    <div class="table-responsive">
      <table class="table table-sm table-striped mb-0">
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
</section>
'''
    marker = "{% endblock %}"
    idx = text.rfind(marker)
    if idx == -1:
        raise SystemExit("ERROR: no se encontro {% endblock %} en el template")
    text = text[:idx] + block + "\n" + text[idx:]
    path.write_text(text)
PY

echo "== Limpiar backups no versionables de fixes anteriores =="
rm -f backend/templates/payment_requests/paymentrequest_detail.html.bak_f1_p23_*
rm -f backend/apps/payment_execution/tests/test_cross_action_audit.py.bak_f1_p23_*
rm -f backend/apps/payment_approvals/models.py.bak_f1_p23_*
rm -f backend/apps/payment_approvals/migrations/*.bak_f1_p23_*

echo "== Verificacion de tags criticos =="
grep -n "Historial de acciones críticas\|No hay acciones críticas registradas\|{% else %}\|{% endif %}\|{% empty %}\|{% endfor %}" "$TEMPLATE" || true

echo "== Validacion focalizada =="
docker compose exec backend ruff check \
  apps/payment_approvals/models.py \
  apps/payment_approvals/migrations/0002_paymentapprovalaction_payment_executed.py \
  apps/payment_execution/models.py \
  apps/payment_execution/tests/test_cross_action_audit.py

docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py test apps.payment_execution.tests.test_cross_action_audit

echo "== OK fix 70 aplicado. Si todo paso, ejecutar validacion completa. =="
