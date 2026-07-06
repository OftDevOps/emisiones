#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== Fix F2-P03: login redirect + ruff import order =="

python3 - <<'PY'
from pathlib import Path
import re

files = [
    Path("backend/apps/payment_requests/views.py"),
    Path("backend/apps/payment_approvals/views.py"),
    Path("backend/apps/payment_execution/views.py"),
]

HELPER_RE = re.compile(
    r"^def _require_operational_permission\([^\n]*\):\n"
    r"(?:^[ \t]+.*\n|^\s*\n)*",
    re.M,
)


def patch_helper_body(helper: str) -> str:
    lines = helper.splitlines()
    if not lines:
        return helper
    body = "\n".join(lines[1:])
    if "is_authenticated" not in body:
        lines.insert(1, '    if not getattr(user, "is_authenticated", False):')
        lines.insert(2, "        return")
    return "\n".join(lines).rstrip() + "\n"


def find_import_block_end(text: str) -> int:
    lines = text.splitlines(keepends=True)
    idx = 0
    paren = 0
    seen_import = False
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped == "":
            if seen_import:
                idx = i + 1
                continue
            idx = i + 1
            continue
        is_import_line = stripped.startswith("import ") or stripped.startswith("from ")
        if is_import_line or paren > 0:
            seen_import = True
            paren += line.count("(") - line.count(")")
            idx = i + 1
            continue
        break
    return sum(len(line) for line in lines[:idx])

for path in files:
    if not path.exists():
        continue
    text = path.read_text(encoding="utf-8")
    match = HELPER_RE.search(text)
    if not match:
        continue
    helper = patch_helper_body(match.group(0))
    text_without_helper = text[: match.start()] + text[match.end():]
    insert_at = find_import_block_end(text_without_helper)
    new_text = (
        text_without_helper[:insert_at].rstrip()
        + "\n\n"
        + helper.rstrip()
        + "\n\n"
        + text_without_helper[insert_at:].lstrip()
    )
    if new_text != text:
        path.write_text(new_text, encoding="utf-8")
        print(f"PATCHED: {path}")

PY

echo "== Ruff autofix =="
docker compose exec backend ruff check . --fix || true

echo "== Estado posterior al fix =="
git status --short

echo "== Validacion rapida de ruff =="
docker compose exec backend ruff check .

echo "OK: fix F2-P03 aplicado. Ejecuta validacion completa antes de commit."
