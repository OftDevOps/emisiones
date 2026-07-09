#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== F2-PILOT-BR04E: mostrar Compras como responsable de marcar emision pagada =="
echo "== Ruta =="
pwd

echo "== Estado inicial =="
git status --short

python3 - <<'PY'
from pathlib import Path
import re

changed_files = []

def write_if_changed(path: Path, text: str, original: str):
    if text != original:
        path.write_text(text, encoding="utf-8")
        changed_files.append(str(path))
        print(f"OK: actualizado {path}")
    else:
        print(f"INFO: sin cambios {path}")

# 1) Header: reintroducir acceso operativo para el rol tecnico CUENTAS_POR_PAGAR,
#    pero visible como Compras. No se cambian URLs, permisos ni roles internos.
base = Path("backend/templates/base.html")
text = base.read_text(encoding="utf-8")
original = text

# Normalizar cualquier etiqueta vieja si existe.
text = text.replace(">Cuentas por pagar<", ">Compras<")
text = text.replace(">Cuentas por Pagar<", ">Compras<")

accounts_link_block = """    {% if role_nav.can_view_accounts_payable %}
        <a class=\"nav-link\" href=\"{% url 'payment_requests:accounts_payable' %}\">Compras</a>
    {% endif %}
"""

if "payment_requests:accounts_payable" not in text:
    # Insertar despues de Reporte si existe, antes de Auditoria si aplica.
    report_link = "        <a class=\"nav-link\" href=\"{% url 'payment_requests:report' %}\">Reporte</a>"
    if report_link in text:
        text = text.replace(report_link, report_link + "\n" + accounts_link_block.rstrip(), 1)
    else:
        # Fallback conservador: insertar antes de cierre de nav principal.
        text = text.replace("</nav>", accounts_link_block + "</nav>", 1)

write_if_changed(base, text, original)

# 2) Dashboard operativo: reintroducir accion rapida como Compras, no Cuentas por Pagar.
dash = Path("backend/templates/payment_requests/paymentrequest_dashboard.html")
text = dash.read_text(encoding="utf-8")
original = text

text = text.replace("Cuentas por Pagar", "Compras")
text = text.replace("Cuentas por pagar", "Compras")

quick_block = """  {% if role_nav.can_view_accounts_payable %}
    <a class=\"quick-action\" href=\"{% url 'payment_requests:accounts_payable' %}\">Compras</a>
  {% endif %}
"""

if "payment_requests:accounts_payable" not in text:
    marker = "</div>"
    # Insertar dentro del primer bloque de acciones rapidas, justo antes del primer cierre de div.
    text = text.replace(marker, quick_block + marker, 1)
elif "Cuentas por Pagar" in original or "Cuentas por pagar" in original:
    pass

# Ajustar condicion de empty-state si el script anterior removio can_view_accounts_payable.
old_empty = "not role_nav.can_view_pending_approvals and not role_nav.can_view_audit_workbench and not role_nav.can_view_payment_request_report"
new_empty = "not role_nav.can_view_pending_approvals and not role_nav.can_view_audit_workbench and not role_nav.can_view_accounts_payable and not role_nav.can_view_payment_request_report"
if old_empty in text and "not role_nav.can_view_accounts_payable" not in text:
    text = text.replace(old_empty, new_empty)

write_if_changed(dash, text, original)

# 3) Workbench tecnico accounts_payable: visible como Compras / confirmacion de pago.
workbench = Path("backend/templates/payment_requests/accounts_payable_pending.html")
text = workbench.read_text(encoding="utf-8")
original = text

repls = {
    "Cuentas por Pagar": "Compras",
    "Cuentas por pagar": "Compras",
    "Emisiones aprobadas pendientes por ejecutar": "Emisiones aprobadas pendientes de confirmación de pago",
    "Emisiones aprobadas pendientes de ejecución": "Emisiones aprobadas pendientes de confirmación de pago",
    "Pagos aprobados pendientes por ejecutar": "Emisiones aprobadas pendientes de confirmación de pago",
    "Registrar pago en ERP": "Marcar emisión como pagada",
    "Registrar pago": "Marcar emisión como pagada",
    "No hay emisiones aprobadas pendientes por ejecutar.": "No hay emisiones aprobadas pendientes de confirmación de pago.",
    "No hay emisiones aprobadas pendientes de ejecución.": "No hay emisiones aprobadas pendientes de confirmación de pago.",
    "No hay pagos aprobados pendientes por ejecutar.": "No hay emisiones aprobadas pendientes de confirmación de pago.",
}
for old, new in repls.items():
    text = text.replace(old, new)
write_if_changed(workbench, text, original)

# 4) Detalle de emision y formulario de ejecucion: texto final claro.
detail = Path("backend/templates/payment_requests/paymentrequest_detail.html")
text = detail.read_text(encoding="utf-8")
original = text
text = text.replace("Registrar pago en ERP", "Marcar emisión como pagada")
text = text.replace("Registrar pago", "Marcar emisión como pagada")
write_if_changed(detail, text, original)

form = Path("backend/templates/payment_execution/paymentexecution_form.html")
text = form.read_text(encoding="utf-8")
original = text
repls = {
    "Registrar ejecución de pago en ERP": "Marcar emisión como pagada",
    "Registrar ejecucion de pago": "Marcar emisión como pagada",
    "Registrar pago en ERP": "Marcar emisión como pagada",
    "Registrar pago": "Marcar emisión como pagada",
    "Volver a Cuentas por Pagar": "Volver al dashboard operativo",
    "Volver a Compras": "Volver al dashboard operativo",
    "{% url 'payment_requests:accounts_payable' %}": "{% url 'payment_requests:dashboard' %}",
}
for old, new in repls.items():
    text = text.replace(old, new)
write_if_changed(form, text, original)

# 5) Login: si vuelve a aparecer Cuentas por Pagar, dejarlo como Compras o eliminarlo del claim.
login = Path("backend/templates/registration/login.html")
text = login.read_text(encoding="utf-8")
original = text
text = text.replace("Emisiones, aprobaciones, Cuentas por Pagar y trazabilidad operativa en una sola plataforma.", "Emisiones, aprobaciones, Compras y trazabilidad operativa en una sola plataforma.")
text = text.replace("Cuentas por Pagar", "Compras")
text = text.replace("Cuentas por pagar", "Compras")
write_if_changed(login, text, original)

# 6) Dashboard identidad: mostrar el rol tecnico CUENTAS_POR_PAGAR como Compras sin tocar el modelo.
identity = Path("backend/templates/accounts/dashboard.html")
text = identity.read_text(encoding="utf-8")
original = text
old_role = '<strong>{{ request.user.get_role_display|default:request.user.role }}</strong>'
new_role = '''<strong>
            {% if request.user.role == "CUENTAS_POR_PAGAR" %}
                Compras
            {% else %}
                {{ request.user.get_role_display|default:request.user.role }}
            {% endif %}
        </strong>'''
if old_role in text:
    text = text.replace(old_role, new_role, 1)
write_if_changed(identity, text, original)

# 7) Tests de navegacion: el rol tecnico sigue siendo CUENTAS_POR_PAGAR, etiqueta visible Compras.
nav_template = Path("backend/apps/accounts/tests/test_role_navigation_template.py")
text = nav_template.read_text(encoding="utf-8")
original = text
text = text.replace('"Cuentas por pagar"', '"Compras"')
text = text.replace('"Cuentas por Pagar"', '"Compras"')
text = text.replace("Cuentas por pagar", "Compras")
text = text.replace("Cuentas por Pagar", "Compras")
write_if_changed(nav_template, text, original)

nav_matrix = Path("backend/apps/accounts/tests/test_role_navigation_integrated_matrix.py")
text = nav_matrix.read_text(encoding="utf-8")
original = text

# Reagregar import si fue removido por BR04D.
if "PERM_VIEW_ACCOUNTS_PAYABLE" not in text:
    text = text.replace("PERM_CREATE_PAYMENT_REQUEST,\n", "PERM_CREATE_PAYMENT_REQUEST,\n    PERM_VIEW_ACCOUNTS_PAYABLE,\n", 1)
elif "from apps.accounts.role_permissions import" in text and "PERM_VIEW_ACCOUNTS_PAYABLE" not in text.split("from apps.accounts.role_permissions import", 1)[1].split(")", 1)[0]:
    text = text.replace("PERM_CREATE_PAYMENT_REQUEST,\n", "PERM_CREATE_PAYMENT_REQUEST,\n    PERM_VIEW_ACCOUNTS_PAYABLE,\n", 1)

text = text.replace('("Cuentas por pagar", "payment_requests:accounts_payable", PERM_VIEW_ACCOUNTS_PAYABLE)', '("Compras", "payment_requests:accounts_payable", PERM_VIEW_ACCOUNTS_PAYABLE)')
text = text.replace('("Cuentas por Pagar", "payment_requests:accounts_payable", PERM_VIEW_ACCOUNTS_PAYABLE)', '("Compras", "payment_requests:accounts_payable", PERM_VIEW_ACCOUNTS_PAYABLE)')

if '"payment_requests:accounts_payable"' not in text:
    # Insertar en NAV_ITEMS despues de Reporte si existe.
    report_tuple = '("Reporte", "payment_requests:report", PERM_VIEW_PAYMENT_REQUEST_REPORT),'
    if report_tuple in text:
        text = text.replace(report_tuple, report_tuple + '\n    ("Compras", "payment_requests:accounts_payable", PERM_VIEW_ACCOUNTS_PAYABLE),', 1)

write_if_changed(nav_matrix, text, original)

# 8) Tests dashboard: visible Compras, no Cuentas por Pagar.
test_dash = Path("backend/apps/payment_requests/tests/test_dashboard.py")
text = test_dash.read_text(encoding="utf-8")
original = text
text = text.replace('"Cuentas por Pagar"', '"Compras"')
text = text.replace('"Cuentas por pagar"', '"Compras"')
text = text.replace("Cuentas por Pagar", "Compras")
text = text.replace("Cuentas por pagar", "Compras")
text = text.replace("Emisiones aprobadas pendientes de ejecución", "Emisiones aprobadas pendientes de confirmación de pago")
text = text.replace("Emisiones aprobadas pendientes por ejecutar", "Emisiones aprobadas pendientes de confirmación de pago")
write_if_changed(test_dash, text, original)

print("\nArchivos modificados:")
for item in changed_files:
    print(f"- {item}")
PY

echo "== Validacion diff whitespace =="
git diff --check

echo "== Busqueda de Cuentas por Pagar visible pendiente en templates principales =="
grep -RniI "Cuentas por Pagar\|Cuentas por pagar\|Registrar pago en ERP" \
  backend/templates/registration/login.html \
  backend/templates/base.html \
  backend/templates/accounts/dashboard.html \
  backend/templates/payment_requests/paymentrequest_dashboard.html \
  backend/templates/payment_requests/accounts_payable_pending.html \
  backend/templates/payment_requests/paymentrequest_detail.html \
  backend/templates/payment_execution/paymentexecution_form.html \
  || true

echo "== Busqueda de Compras / Marcar emision en templates principales =="
grep -RniI "Compras\|Marcar emisión como pagada" \
  backend/templates/base.html \
  backend/templates/accounts/dashboard.html \
  backend/templates/payment_requests/paymentrequest_dashboard.html \
  backend/templates/payment_requests/accounts_payable_pending.html \
  backend/templates/payment_requests/paymentrequest_detail.html \
  backend/templates/payment_execution/paymentexecution_form.html \
  | head -n 120 || true

echo "== Ruff =="
docker compose exec backend ruff check .

echo "== Django check =="
docker compose exec backend python manage.py check

echo "== Tests focales BR04E =="
docker compose exec backend python manage.py test \
  apps.accounts.tests.test_authentication_flow \
  apps.accounts.tests.test_role_navigation_template \
  apps.accounts.tests.test_role_navigation_integrated_matrix \
  apps.accounts.tests.test_role_navigation_context \
  apps.payment_requests.tests.test_dashboard \
  apps.payment_requests.tests.test_accounts_payable_workbench \
  apps.payment_execution.tests.test_views

echo "== Estado final =="
git status --short

echo "== FIN F2-PILOT-BR04E Compras visible =="
