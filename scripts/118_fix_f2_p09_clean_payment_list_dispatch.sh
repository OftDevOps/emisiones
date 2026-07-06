#!/usr/bin/env bash
set -euo pipefail

cd /home/dchirinos/oftalmiIA/emisiones/emisiones

echo "== Fix F2-P09: reconstruir dispatch limpio en PaymentRequestListView =="

echo "== Estado inicial =="
git status --short

python3 - <<'PY'
from pathlib import Path

path = Path("backend/apps/payment_requests/views.py")
text = path.read_text(encoding="utf-8")

start_marker = "class PaymentRequestListView(LoginRequiredMixin, ListView):"
end_marker = "class PaymentRequestDetailView(LoginRequiredMixin, DetailView):"

if start_marker not in text or end_marker not in text:
    raise SystemExit("ERROR: no se encontraron marcadores de PaymentRequestListView.")

start = text.index(start_marker)
end = text.index(end_marker)
current_block = text[start:end]

new_block = '''class PaymentRequestListView(LoginRequiredMixin, ListView):
    model = PaymentRequest
    template_name = "payment_requests/paymentrequest_list.html"
    context_object_name = "payment_requests"
    paginate_by = 20

    def dispatch(self, request, *args, **kwargs):
        _require_operational_permission(
            request.user,
            PERM_VIEW_PAYMENT_REQUESTS,
            "Su rol no permite consultar solicitudes de pago.",
        )
        return super().dispatch(request, *args, **kwargs)

    def get_queryset(self):
        return scoped_payment_request_queryset(self.request.user).order_by("-created_at")


'''

text = text[:start] + new_block + text[end:]
path.write_text(text, encoding="utf-8")
PY

echo "== Fragmento PaymentRequestListView corregido =="
sed -n '/class PaymentRequestListView/,/class PaymentRequestDetailView/p' backend/apps/payment_requests/views.py

echo "== Validando diff whitespace =="
git diff --check

echo "== Ruff focal F2-P09 =="
docker compose exec backend ruff check \
  apps/accounts/context_processors.py \
  apps/accounts/role_permissions.py \
  apps/payment_requests/urls.py \
  apps/payment_requests/views.py \
  apps/payment_requests/tests/test_dashboard.py \
  apps/payment_requests/tests/test_reports.py \
  apps/payment_requests/tests/test_views.py

echo "== Tests focales de regresion F2-P09 =="
docker compose exec backend python manage.py test \
  apps.payment_requests.tests.test_reports \
  apps.payment_requests.tests.test_dashboard \
  apps.payment_requests.tests.test_views

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== Estado Git =="
git status --short

echo "== Fix F2-P09 dispatch OK =="
