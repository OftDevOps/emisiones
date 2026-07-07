#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== Finalizar F2-P11: Auditoria extendida =="
echo "== Estado inicial =="
git status --short

echo "== Validando diff whitespace =="
git diff --check

echo "== Ruff focal previo al commit =="
docker compose exec backend ruff check apps/payment_approvals/views.py apps/payment_approvals/tests/test_cross_action_audit_workbench.py

echo "== Tests focales F2-P11 previo al commit =="
docker compose exec backend python manage.py test apps.payment_approvals.tests.test_cross_action_audit_workbench

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== Verificando migraciones pendientes =="
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== Agregando archivos F2-P11 =="
git add \
  backend/apps/payment_approvals/tests/test_cross_action_audit_workbench.py \
  backend/apps/payment_approvals/views.py \
  backend/templates/payment_approvals/cross_action_audit_workbench.html \
  docs/roadmap_fase2.md \
  docs/f2_p11_auditoria_extendida.md \
  scripts/123_inspect_f2_p11_audit_scope.sh \
  scripts/124_f2_p11_extended_audit_workbench.sh \
  scripts/125_fix_f2_p11_audit_tests_eof.sh \
  scripts/126_fix_f2_p11_ruff_container_paths.sh \
  scripts/127_finalize_f2_p11_commit.sh

echo "== Estado staged =="
git diff --cached --name-status

echo "== Commit =="
git commit -m "feat: extend operational audit workbench"

echo "== Push origin develop =="
git push origin develop

echo "== Estado final =="
git log --oneline --max-count=5 --decorate

echo "== F2-P11 cerrado y publicado en origin/develop =="
