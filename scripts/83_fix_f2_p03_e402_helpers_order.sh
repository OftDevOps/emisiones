#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== Fix F2-P03: corregir E402 reubicando helpers despues de imports =="

python3 - <<'PY'
from pathlib import Path

FILES = [
    Path("backend/apps/payment_requests/views.py"),
    Path("backend/apps/payment_approvals/views.py"),
]

HELPER_NAMES = (
    "_require_operational_permission",
    "_require_role_permission",
    "_require_permission",
)


def strip_helper_block(text: str):
    lines = text.splitlines()
    removed_blocks = []
    kept = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.lstrip()
        if any(stripped.startswith(f"def {name}(") for name in HELPER_NAMES):
            block = []
            block.append(line)
            i += 1
            while i < len(lines):
                nxt = lines[i]
                # End of top-level function when next top-level nonblank starts.
                if nxt and not nxt.startswith((" ", "\t")):
                    break
                block.append(nxt)
                i += 1
            # Trim trailing blank lines in helper block.
            while block and block[-1] == "":
                block.pop()
            removed_blocks.append("\n".join(block))
            continue
        kept.append(line)
        i += 1
    return "\n".join(kept).rstrip() + "\n", removed_blocks


def find_import_section_end(lines):
    i = 0
    last_import_end = 0
    in_paren_import = False
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if not stripped:
            i += 1
            continue
        if in_paren_import:
            if stripped.endswith(")"):
                in_paren_import = False
                last_import_end = i + 1
            i += 1
            continue
        if stripped.startswith("import ") or stripped.startswith("from "):
            if "(" in stripped and not stripped.endswith(")"):
                in_paren_import = True
            last_import_end = i + 1
            i += 1
            continue
        break
    return last_import_end


def ensure_helper_after_imports(path: Path):
    original = path.read_text(encoding="utf-8")
    without_helpers, helpers = strip_helper_block(original)
    if not helpers:
        print(f"WARN: no helper block found in {path}")
        return

    # Deduplicate identical helper bodies while preserving order.
    unique_helpers = []
    seen = set()
    for helper in helpers:
        if helper not in seen:
            unique_helpers.append(helper)
            seen.add(helper)

    lines = without_helpers.splitlines()
    insert_at = find_import_section_end(lines)

    before = "\n".join(lines[:insert_at]).rstrip()
    after = "\n".join(lines[insert_at:]).lstrip("\n")
    helper_text = "\n\n".join(unique_helpers).strip()

    new_text = before + "\n\n\n" + helper_text + "\n\n\n" + after.rstrip() + "\n"
    if new_text != original:
        path.write_text(new_text, encoding="utf-8")
        print(f"OK: helpers reubicados en {path}")
    else:
        print(f"OK: sin cambios necesarios en {path}")

for file_path in FILES:
    ensure_helper_after_imports(file_path)
PY

echo "== Ruff autofix final =="
docker compose exec backend ruff check . --fix || true

echo "== Validacion ruff =="
docker compose exec backend ruff check .

echo "== Estado posterior =="
git status --short
