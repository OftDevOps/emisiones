#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== Finalizar F2-P13: cierre tecnico de Fase 2 =="

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "develop" ]; then
  echo "ERROR: este cierre debe ejecutarse sobre develop. Rama actual: $current_branch" >&2
  exit 1
fi

echo "== Estado inicial =="
git status --short
git log --oneline --max-count=5 --decorate

echo "== Validando archivos esperados =="
test -f docs/f2_p13_cierre_tecnico_fase2.md
test -f docs/roadmap_fase2.md
test -f scripts/131_f2_p13_technical_closure.sh
test -f scripts/132_finalize_f2_p13_commit.sh

echo "== Verificando alcance documental =="
changed_files="$(git status --porcelain | awk '{print $2}')"
if [ -z "$changed_files" ]; then
  echo "ERROR: no hay cambios para cerrar F2-P13" >&2
  exit 1
fi

bad_files="$(printf '%s\n' "$changed_files" | grep -Ev '^(docs/|scripts/)' || true)"
if [ -n "$bad_files" ]; then
  echo "ERROR: F2-P13 solo permite cambios en docs/ y scripts/. Archivos no permitidos:" >&2
  printf '%s\n' "$bad_files" >&2
  exit 1
fi

echo "== Validando diff whitespace =="
git diff --check

echo "== Validacion completa estandar previa al commit =="
nordvpn disconnect || true
sleep 3

docker compose exec backend ruff check .
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests apps.payment_documents apps.payment_approvals apps.payment_execution

nordvpn connect United_States || true
nordvpn status || true

echo "== Agregando archivos F2-P13 =="
git add docs/roadmap_fase2.md \
        docs/f2_p13_cierre_tecnico_fase2.md \
        scripts/131_f2_p13_technical_closure.sh \
        scripts/132_finalize_f2_p13_commit.sh

echo "== Estado staged =="
git diff --cached --name-status

echo "== Commit =="
git commit -m "docs: close phase 2 technical baseline"

echo "== Push origin develop =="
git push origin develop

echo "== Estado final =="
git log --oneline --max-count=5 --decorate

echo "== F2-P13 cerrado y publicado en origin/develop =="
