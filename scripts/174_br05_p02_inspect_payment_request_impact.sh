#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== BR05-P02: inspeccion tecnica impacto PaymentRequest / items / IVA =="
echo "== Ruta =="
pwd

echo "== Estado inicial =="
git status --short

echo "== HEAD =="
git log --oneline --max-count=5 --decorate

echo "== Archivos clave payment_requests =="
find backend/apps/payment_requests -maxdepth 3 -type f | sort

echo "== Archivos clave payment_execution =="
find backend/apps/payment_execution -maxdepth 3 -type f | sort

echo "== Referencias a amount en backend/apps =="
grep -RIn "\.amount\|amount" backend/apps backend/templates docs --exclude-dir='__pycache__' --exclude='*.pyc' | sed -n '1,260p' || true

echo "== Modelos PaymentRequest actuales =="
sed -n '1,260p' backend/apps/payment_requests/models.py

echo "== Formularios PaymentRequest actuales =="
sed -n '1,260p' backend/apps/payment_requests/forms.py

echo "== Vistas PaymentRequest actuales =="
sed -n '1,380p' backend/apps/payment_requests/views.py

echo "== URLs PaymentRequest actuales =="
sed -n '1,220p' backend/apps/payment_requests/urls.py

echo "== Template form emision actual =="
if [ -f backend/templates/payment_requests/paymentrequest_form.html ]; then
  sed -n '1,260p' backend/templates/payment_requests/paymentrequest_form.html
else
  echo "NO_EXISTE: backend/templates/payment_requests/paymentrequest_form.html"
fi

echo "== Template detail actual: primeras 220 lineas =="
sed -n '1,220p' backend/templates/payment_requests/paymentrequest_detail.html

echo "== Template dashboard actual: primeras 180 lineas =="
sed -n '1,180p' backend/templates/payment_requests/paymentrequest_dashboard.html

echo "== Reportes / exportaciones relacionadas =="
grep -RIn "PaymentRequest\|amount\|currency\|total" backend/apps backend/templates --exclude-dir='__pycache__' | sed -n '1,260p' || true

echo "== Tests payment_requests existentes =="
find backend/apps/payment_requests/tests -type f -maxdepth 1 -print | sort | while read -r f; do
  echo "---- $f"
  sed -n '1,220p' "$f"
done

echo "== Tests payment_execution existentes =="
find backend/apps/payment_execution/tests -type f -maxdepth 1 -print | sort | while read -r f; do
  echo "---- $f"
  sed -n '1,220p' "$f"
done

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== Makemigrations dry-run =="
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== FIN BR05-P02 inspeccion tecnica =="
