#!/usr/bin/env bash
set -euo pipefail

# Fix F1-P20 - Corrige imports rotos en payment_requests/views.py
# No crea modelos.
# No crea migraciones.
# No hace commit.

EXPECTED_BRANCH="feature/accounts-payable-workbench"

echo "== Fix F1-P20: normalizar imports en payment_requests/views.py =="

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "ERROR: este directorio no parece ser un repositorio Git."
  exit 1
fi

cd "$(git rev-parse --show-toplevel)"

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

path = Path("backend/apps/payment_requests/views.py")
text = path.read_text()

# Elimina cualquier línea suelta de UserRole que haya quedado dentro de imports multilínea.
text = re.sub(r"^\s*from apps\.accounts\.models import UserRole\s*\n", "", text, flags=re.MULTILINE)

# Asegura PermissionDenied en el import correcto.
text = text.replace(
    "from django.core.exceptions import ValidationError",
    "from django.core.exceptions import PermissionDenied, ValidationError",
)

# Evita duplicar PermissionDenied si el fix se ejecuta más de una vez.
text = text.replace(
    "from django.core.exceptions import PermissionDenied, PermissionDenied, ValidationError",
    "from django.core.exceptions import PermissionDenied, ValidationError",
)

# Inserta UserRole después del bloque de imports de django y antes de imports de apps, fuera de paréntesis.
if "from apps.accounts.models import UserRole" not in text:
    lines = text.splitlines()
    insert_at = 0

    # Busca la última línea de import django completa, incluyendo bloques multilinea.
    in_multiline = False
    for idx, line in enumerate(lines):
        stripped = line.strip()

        if in_multiline:
            if stripped == ")" or stripped.endswith(")"):
                in_multiline = False
                insert_at = idx + 1
            continue

        if line.startswith("from django.") or line.startswith("import "):
            insert_at = idx + 1
            if line.rstrip().endswith("("):
                in_multiline = True

    lines.insert(insert_at, "from apps.accounts.models import UserRole")
    text = "\n".join(lines) + "\n"

path.write_text(text)
print("OK: imports normalizados.")
PY

echo "== Validación sintáctica Python =="
python3 -m py_compile \
  backend/apps/payment_requests/views.py \
  backend/apps/payment_requests/urls.py \
  backend/apps/payment_requests/tests/test_accounts_payable_workbench.py

echo "== Estado de archivos =="
git status --short

cat <<'NEXT'

Ahora repite validación completa:

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
