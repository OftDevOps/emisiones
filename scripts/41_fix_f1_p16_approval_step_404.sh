#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' '== Fix F1-P16: Approval step 404 handling =='

if [ ! -f "backend/manage.py" ]; then
  printf '%s\n' 'ERROR: run from repository root: /home/dchirinos/oftalmiIA/emisiones/emisiones' >&2
  exit 1
fi

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "feature/approval-actions-ui" ]; then
  printf '%s\n' "ERROR: expected branch feature/approval-actions-ui, current: $current_branch" >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_approvals/views.py")
if not path.exists():
    raise SystemExit("ERROR: backend/apps/payment_approvals/views.py not found")

text = path.read_text()

if "from django.shortcuts import get_object_or_404, redirect" not in text:
    text = text.replace(
        "from django.shortcuts import redirect",
        "from django.shortcuts import get_object_or_404, redirect",
    )

old = '        step = queryset.get(pk=self.kwargs["pk"])'
new = '        step = get_object_or_404(queryset, pk=self.kwargs["pk"])'

if old not in text and new not in text:
    raise SystemExit("ERROR: expected queryset.get line not found. Inspect views.py manually.")

text = text.replace(old, new)
path.write_text(text)

print("OK: ApprovalStepActionView now returns 404 when step does not exist.")
PY

printf '%s\n' 'Next validation:'
printf '%s\n' 'nordvpn disconnect && sleep 3'
printf '%s\n' 'docker compose exec backend ruff check .'
printf '%s\n' 'docker compose exec backend python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests apps.payment_documents apps.payment_approvals'
printf '%s\n' 'nordvpn connect United_States && nordvpn status'
