#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== Finalizar F2-P12: paquete de validacion con usuarios internos =="
echo "== Estado inicial =="
git status --short
git log --oneline --max-count=5 --decorate

echo "== Validando archivos esperados =="
for file in \
  docs/roadmap_fase2.md \
  docs/checklist_validacion_interna_fase2.md \
  docs/f2_p12_paquete_validacion_usuarios_internos.md \
  scripts/128_inspect_f2_p12_validation_package.sh \
  scripts/129_f2_p12_internal_validation_package.sh \
  scripts/130_finalize_f2_p12_commit.sh
  do
    if [ ! -f "$file" ]; then
      echo "ERROR: falta archivo esperado: $file" >&2
      exit 1
    fi
  done

echo "== Validando diff whitespace =="
git diff --check

echo "== Validacion completa estandar previa al commit =="
if command -v nordvpn >/dev/null 2>&1; then
  nordvpn disconnect || true
  sleep 3
else
  echo "WARN: nordvpn no disponible en PATH; continuo sin desconectar VPN."
fi

docker compose exec backend ruff check .
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests apps.payment_documents apps.payment_approvals apps.payment_execution

if command -v nordvpn >/dev/null 2>&1; then
  nordvpn connect United_States || true
  nordvpn status || true
fi

echo "== Agregando archivos F2-P12 =="
git add \
  docs/roadmap_fase2.md \
  docs/checklist_validacion_interna_fase2.md \
  docs/f2_p12_paquete_validacion_usuarios_internos.md \
  scripts/128_inspect_f2_p12_validation_package.sh \
  scripts/129_f2_p12_internal_validation_package.sh \
  scripts/130_finalize_f2_p12_commit.sh

echo "== Estado staged =="
git diff --cached --name-status

echo "== Commit =="
git commit -m "docs: add internal validation package"

echo "== Push origin develop =="
git push origin develop

echo "== Estado final =="
git log --oneline --max-count=5 --decorate
git status --short

echo "== F2-P12 cerrado y publicado en origin/develop =="
