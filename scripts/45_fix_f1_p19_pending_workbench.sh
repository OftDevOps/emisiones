#!/usr/bin/env bash
set -euo pipefail

# Fix F1-P19 - Corrección bandeja pendientes por aprobar
# Corrige:
# - Import duplicado de PaymentApprovalStep en payment_approvals/views.py.
# - Template sin mostrar concept, lo que hacía fallar assertContains en tests.
#
# No crea modelos.
# No crea migraciones.
# No hace commit.

EXPECTED_BRANCH="feature/approval-pending-workbench"

echo "== Fix F1-P19: pending approval workbench =="

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "ERROR: este directorio no parece ser un repositorio Git."
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

CURRENT_BRANCH="$(git branch --show-current)"
if [ "$CURRENT_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ERROR: rama incorrecta."
  echo "Actual:   $CURRENT_BRANCH"
  echo "Esperada: $EXPECTED_BRANCH"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re

views_path = Path("backend/apps/payment_approvals/views.py")
template_path = Path("backend/templates/payment_approvals/pending_approval_steps.html")

if not views_path.exists():
    raise SystemExit(f"ERROR: no existe {views_path}")

if not template_path.exists():
    raise SystemExit(f"ERROR: no existe {template_path}")

views = views_path.read_text()

# Normaliza imports desde .models para eliminar duplicados introducidos por el playbook.
views = re.sub(
    r"from \.models import ApprovalActionType, PaymentApprovalStep\n",
    "",
    views,
)

if "from .models import ApprovalActionType" not in views:
    # Si existe un import multilinea desde apps.payment_approvals.models, no lo tocamos.
    if "from apps.payment_approvals.models import (" in views:
        pass
    elif "from apps.payment_approvals.models import ApprovalStepStatus, PaymentApprovalStep" in views:
        views = views.replace(
            "from apps.payment_approvals.models import ApprovalStepStatus, PaymentApprovalStep",
            "from .models import ApprovalActionType\nfrom apps.payment_approvals.models import ApprovalStepStatus, PaymentApprovalStep",
            1,
        )
    else:
        views = "from .models import ApprovalActionType\n" + views

views_path.write_text(views)

template = template_path.read_text()

if "<th>Concepto</th>" not in template:
    template = template.replace(
        "        <th>Beneficiario</th>\n",
        "        <th>Beneficiario</th>\n        <th>Concepto</th>\n",
        1,
    )

if "{{ step.payment_request.concept }}" not in template:
    template = template.replace(
        "          <td>{{ step.payment_request.beneficiary }}</td>\n",
        "          <td>{{ step.payment_request.beneficiary }}</td>\n          <td>{{ step.payment_request.concept }}</td>\n",
        1,
    )

template_path.write_text(template)

print("OK: fix F1-P19 aplicado.")
PY

echo "== Validación sintáctica Python =="
python3 -m py_compile \
  backend/apps/payment_approvals/views.py \
  backend/apps/payment_approvals/urls.py \
  backend/apps/payment_approvals/tests/test_pending_workbench.py

echo "== Estado de archivos =="
git status --short

cat <<'NEXT'

Ejecuta de nuevo la validación completa:

nordvpn disconnect
sleep 3

git status
git log --oneline --max-count=5

docker compose exec backend ruff check .
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests apps.payment_documents apps.payment_approvals

nordvpn connect United_States
nordvpn status

NEXT
