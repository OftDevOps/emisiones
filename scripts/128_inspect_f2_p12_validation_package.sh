#!/usr/bin/env bash
set -euo pipefail

echo "== F2-P12: inspeccion paquete de validacion con usuarios internos =="

echo "== Estado Git =="
git status --short
git log --oneline --max-count=8 --decorate

echo "== Roadmap Fase 2 =="
sed -n '1,260p' docs/roadmap_fase2.md

echo "== Documentacion operativa existente =="
find docs -maxdepth 3 -type f | sort | grep -Ei 'validacion|mvp|demo|usuario|fase2|cierre|matriz|permis|roadmap|auditoria|reporte|cuentas|pagar|manual|uat' || true

echo "== Documentos clave existentes =="
for file in \
  docs/mvp_operativo_fase1.md \
  docs/validacion_visual_funcional_fase1.md \
  docs/cierre_tecnico_fase1.md \
  docs/continuidad_fase1_cierre_arranque_fase2.md \
  docs/f2_p02_roles_permisos_matriz_acceso.md \
  docs/matriz_acceso_operativa_fase2.md \
  docs/matriz_permisos_efectiva_vistas_criticas.md \
  docs/matriz_ux_permisos_navegacion_fase2.md \
  docs/f2_p08_dashboard_operativo_por_rol.md \
  docs/f2_p09_reporte_basico_estado_empresa_fecha.md \
  docs/f2_p10_exportacion_operativa_basica.md \
  docs/f2_p11_auditoria_extendida.md; do
  if [ -f "$file" ]; then
    echo "== $file =="
    sed -n '1,220p' "$file"
  fi
done

echo "== Comandos manage disponibles relacionados con demo/seed/users =="
find backend/apps -path '*/management/commands/*.py' -type f | sort || true

echo "== Busqueda usuarios demo / validacion / UAT =="
grep -Rni --exclude-dir='__pycache__' --exclude='*.pyc' \
  -E 'demo|uat|validacion|validación|usuario interno|usuarios internos|auditor.demo|finanzas|cuentas.por.pagar|solicitante|responsable' \
  backend docs | head -n 300 || true

echo "== Tests actuales por app =="
find backend/apps/accounts/tests backend/apps/payment_requests/tests backend/apps/payment_approvals/tests backend/apps/payment_execution/tests -maxdepth 1 -type f | sort

echo "== URLs principales =="
sed -n '1,220p' backend/config/urls.py
sed -n '1,220p' backend/apps/payment_requests/urls.py
sed -n '1,220p' backend/apps/payment_approvals/urls.py

echo "== Navegacion base =="
sed -n '1,260p' backend/templates/base.html

echo "== F2-P12 inspeccion completada =="
