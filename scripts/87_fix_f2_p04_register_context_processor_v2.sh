#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_ROOT"

echo "== Fix F2-P04 v2: registrar context processor de navegacion por rol =="

SETTINGS=""
for candidate in \
  "backend/config/settings/base.py" \
  "backend/config/settings.py" \
  "config/settings/base.py" \
  "config/settings.py" \
  "backend/settings.py"
do
  if [[ -f "$candidate" ]] && grep -q "TEMPLATES" "$candidate"; then
    SETTINGS="$candidate"
    break
  fi
done

if [[ -z "$SETTINGS" ]]; then
  echo "ERROR: no se encontro archivo settings con TEMPLATES."
  exit 1
fi

echo "INFO: settings detectado: $SETTINGS"

SETTINGS_PATH="$SETTINGS" python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["SETTINGS_PATH"])
text = path.read_text(encoding="utf-8")
processor = "apps.accounts.context_processors.role_navigation"

if processor in text:
    print("OK: context processor ya estaba registrado.")
    raise SystemExit(0)

anchor = "django.contrib.messages.context_processors.messages"
if anchor not in text:
    raise SystemExit("ERROR: no se encontro anchor django.contrib.messages.context_processors.messages")

text = text.replace(
    f"'{anchor}',",
    f"'{anchor}',\n                '{processor}',",
)
text = text.replace(
    f'"{anchor}",',
    f'"{anchor}",\n                "{processor}",',
)

if processor not in text:
    raise SystemExit("ERROR: no se pudo insertar el context processor.")

path.write_text(text, encoding="utf-8")
print(f"OK: context processor registrado en {path}")
PY

echo "== Ruff =="
docker compose exec backend ruff check .

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== Estado posterior =="
git status --short
