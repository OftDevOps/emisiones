#!/usr/bin/env bash
set -euo pipefail

cd /home/dchirinos/oftalmiIA/emisiones/emisiones

echo "== F2-P09 inspeccion: reporte basico por estado, empresa y fecha =="

echo "== Estado Git =="
git status --short
git log --oneline --max-count=6 --decorate

echo "== Estructura payment_requests =="
find backend/apps/payment_requests -maxdepth 3 -type f | sort

echo "== Estructura templates payment_requests =="
find backend/templates/payment_requests -maxdepth 2 -type f | sort || true

echo "== Estructura organization =="
find backend/apps/organization -maxdepth 3 -type f | sort

echo "== URLs payment_requests =="
sed -n '1,260p' backend/apps/payment_requests/urls.py

echo "== Vistas payment_requests =="
sed -n '1,360p' backend/apps/payment_requests/views.py

echo "== Modelos payment_requests =="
sed -n '1,320p' backend/apps/payment_requests/models.py

echo "== Forms payment_requests =="
sed -n '1,260p' backend/apps/payment_requests/forms.py

echo "== Role permissions =="
sed -n '1,260p' backend/apps/accounts/role_permissions.py

echo "== Context processors / role_nav =="
grep -Rni "role_nav\|PERM_VIEW\|permissions_for_role\|user_has_permission" backend/apps backend/config backend/templates | head -n 240 || true

echo "== Tests payment_requests existentes =="
find backend/apps/payment_requests/tests -maxdepth 1 -type f | sort
for f in backend/apps/payment_requests/tests/*.py; do
  echo "== TEST FILE: $f =="
  sed -n '1,260p' "$f"
done

echo "== Docs Fase 2 relevantes =="
sed -n '1,260p' docs/roadmap_fase2.md
sed -n '1,260p' docs/f2_p08_dashboard_operativo_por_rol.md || true
sed -n '1,260p' docs/matriz_dashboard_operativo_por_rol_fase2.md || true

echo "== F2-P09 inspeccion completada =="
