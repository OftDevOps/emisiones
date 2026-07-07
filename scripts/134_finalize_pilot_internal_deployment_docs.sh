#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== Finalizar bloque piloto interno documental =="
echo "== Estado inicial =="
git status --short
git log --oneline --max-count=5 --decorate

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "develop" ]; then
  echo "ERROR: este cierre debe ejecutarse sobre develop. Rama actual: $current_branch" >&2
  exit 1
fi

echo "== Validando archivos esperados =="
required_files=(
  "docs/despliegue_piloto_interno.md"
  "docs/checklist_predespliegue_piloto_interno.md"
  "docs/variables_entorno_piloto_interno.md"
  "docs/backup_restore_postgresql_piloto.md"
  "docs/plan_rollback_piloto_interno.md"
  "docs/smoke_test_piloto_interno.md"
  "docs/monitoreo_basico_piloto_interno.md"
  "docs/guia_operacion_piloto_interno.md"
  "scripts/133_pilot_internal_deployment_docs.sh"
  "scripts/134_finalize_pilot_internal_deployment_docs.sh"
)

for file in "${required_files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "ERROR: archivo esperado no existe: $file" >&2
    exit 1
  fi
done

echo "== Verificando alcance documental =="
invalid_paths="$(git status --porcelain | awk '{print $2}' | grep -Ev '^(docs/|scripts/)' || true)"
if [ -n "$invalid_paths" ]; then
  echo "ERROR: se detectaron cambios fuera de docs/ y scripts/:" >&2
  printf '%s\n' "$invalid_paths" >&2
  exit 1
fi

expected_status_pattern='^( M docs/|\?\? docs/|\?\? scripts/133_pilot_internal_deployment_docs\.sh|\?\? scripts/134_finalize_pilot_internal_deployment_docs\.sh|A  docs/|M  docs/|A  scripts/)'
unexpected_status="$(git status --porcelain | grep -Ev "$expected_status_pattern" || true)"
if [ -n "$unexpected_status" ]; then
  echo "ERROR: estado Git no esperado:" >&2
  printf '%s\n' "$unexpected_status" >&2
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

echo "== Agregando archivos del bloque piloto interno =="
git add \
  docs/despliegue_piloto_interno.md \
  docs/checklist_predespliegue_piloto_interno.md \
  docs/variables_entorno_piloto_interno.md \
  docs/backup_restore_postgresql_piloto.md \
  docs/plan_rollback_piloto_interno.md \
  docs/smoke_test_piloto_interno.md \
  docs/monitoreo_basico_piloto_interno.md \
  docs/guia_operacion_piloto_interno.md \
  scripts/133_pilot_internal_deployment_docs.sh \
  scripts/134_finalize_pilot_internal_deployment_docs.sh

echo "== Estado staged =="
git diff --cached --name-status

if git diff --cached --quiet; then
  echo "ERROR: no hay cambios staged para commit." >&2
  exit 1
fi

echo "== Commit =="
git commit -m "docs: add internal pilot deployment plan"

echo "== Push origin develop =="
git push origin develop

echo "== Estado final =="
git status --short
git log --oneline --max-count=5 --decorate

echo "== Bloque piloto interno cerrado y publicado en origin/develop =="
