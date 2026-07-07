#!/usr/bin/env bash
set -euo pipefail

cd /home/dchirinos/oftalmiIA/emisiones/emisiones

echo "== F2-P11: inspeccion de alcance auditoria extendida =="
echo "== Estado Git =="
git status --short
git log --oneline --max-count=8 --decorate

echo "== Roadmap Fase 2 =="
sed -n '1,260p' docs/roadmap_fase2.md

echo "== Archivos audit/payment_approvals relevantes =="
find backend/apps/audit backend/apps/payment_approvals backend/templates/payment_approvals -maxdepth 4 -type f | sort || true

echo "== URLs auditoria =="
sed -n '1,220p' backend/apps/payment_approvals/urls.py

echo "== Vista auditoria actual =="
sed -n '1,260p' backend/apps/payment_approvals/views.py

echo "== Modelo auditoria actual =="
sed -n '1,240p' backend/apps/payment_approvals/models.py

echo "== Template auditoria actual =="
sed -n '1,280p' backend/templates/payment_approvals/cross_action_audit_workbench.html || true

echo "== Tests auditoria actual =="
sed -n '1,280p' backend/apps/payment_approvals/tests/test_cross_action_audit_workbench.py || true
sed -n '1,260p' backend/apps/payment_execution/tests/test_cross_action_audit.py || true

echo "== Permisos y navegacion audit =="
sed -n '1,240p' backend/apps/accounts/role_permissions.py
sed -n '1,260p' backend/apps/accounts/context_processors.py

echo "== Referencias audit sin binarios =="
grep -RniI "audit\|auditoria\|auditoría\|PERM_VIEW_AUDIT_WORKBENCH\|cross_action" backend/apps docs | head -n 320 || true

echo "== F2-P11 inspeccion completada =="
