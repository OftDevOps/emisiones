#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$ROOT"

echo "== Fix F2-P04: registrar context processor de navegacion por rol =="

SETTINGS_FILES=(
  "backend/config/settings/base.py"
  "backend/config/settings.py"
  "backend/emisiones/settings.py"
  "backend/core/settings.py"
)

TARGET="apps.accounts.context_processors.role_navigation"
SETTINGS=""
for f in "${SETTINGS_FILES[@]}"; do
  if [ -f "$f" ]; then
    if grep -q "TEMPLATES" "$f" && grep -q "context_processors" "$f"; then
      SETTINGS="$f"
      break
    fi
  fi
done

if [ -z "$SETTINGS" ]; then
  SETTINGS=$(find backend -path "*/settings*.py" -type f -print | while read -r f; do
    if grep -q "TEMPLATES" "$f" && grep -q "context_processors" "$f"; then
      echo "$f"
      break
    fi
  done)
fi

if [ -z "$SETTINGS" ]; then
  echo "ERROR: no se encontro archivo settings con TEMPLATES/context_processors." >&2
  exit 1
fi

echo "INFO: settings detectado: $SETTINGS"

python3 - <<'PY'
from pathlib import Path

settings_path = Path("$SETTINGS")
target = "apps.accounts.context_processors.role_navigation"
text = settings_path.read_text(encoding="utf-8")

if target in text:
    print(f"OK: context processor ya registrado en {settings_path}")
    raise SystemExit(0)

anchors = [
    '"django.contrib.messages.context_processors.messages",',
    "'django.contrib.messages.context_processors.messages',",
    '"django.template.context_processors.request",',
    "'django.template.context_processors.request',",
]

for anchor in anchors:
    if anchor in text:
        quote = '"' if anchor.strip().startswith('"') else "'"
        insert = anchor + f"\n                {quote}{target}{quote},"
        text = text.replace(anchor, insert, 1)
        settings_path.write_text(text, encoding="utf-8")
        print(f"OK: context processor registrado en {settings_path}")
        raise SystemExit(0)

raise SystemExit("ERROR: no se encontro anchor compatible dentro de context_processors.")
PY

# replace placeholder safely
python3 - <<PY
from pathlib import Path
p = Path("$SETTINGS")
script = Path("/tmp/f2_p04_register_cp.py")
PY

echo "== Verificacion =="
grep -Rni "apps.accounts.context_processors.role_navigation" "$SETTINGS" || true

echo "== Estado posterior =="
git status --short
