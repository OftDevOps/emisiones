#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

printf '== 142 - Apply parametrized pilot branding ==\n'
printf 'Project: %s\n' "$PROJECT_DIR"
printf 'Date: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"

printf '== Guardrails ==\n'
for path in \
  backend/config/settings/base.py \
  backend/apps/accounts/context_processors.py \
  backend/templates/base.html \
  backend/templates/registration/login.html \
  backend/templates/accounts/dashboard.html \
  backend/templates/payment_requests/paymentrequest_dashboard.html \
  backend/static/css/oftalmi_branding.css \
  backend/static/img/favicon.ico \
  backend/static/img/oftalmi-icon.png \
  .env.example
 do
  if [ -e "$path" ]; then
    printf 'OK: %s\n' "$path"
  else
    printf 'FAIL: required path missing: %s\n' "$path"
    exit 1
  fi
 done

printf '\n== Git baseline ==\n'
git status --short
git log --oneline --max-count=5 --decorate

python3 - <<'PY'
from pathlib import Path

base_settings = Path("backend/config/settings/base.py")
text = base_settings.read_text(encoding="utf-8")

branding_block = '''\n# Branding / company presentation\nAPP_COMPANY_NAME = config("APP_COMPANY_NAME", default="Laboratorios Oftalmi")\nAPP_COMPANY_SHORT_NAME = config("APP_COMPANY_SHORT_NAME", default="Oftalmi")\nAPP_PRODUCT_NAME = config("APP_PRODUCT_NAME", default="Sistema de Rutas de Pago")\nAPP_PRODUCT_SHORT_NAME = config("APP_PRODUCT_SHORT_NAME", default="Rutas de Pago")\nAPP_BRAND_PRIMARY = config("APP_BRAND_PRIMARY", default="#1226AA")\nAPP_BRAND_SECONDARY = config("APP_BRAND_SECONDARY", default="#8A1A9B")\nAPP_BRAND_ACCENT = config("APP_BRAND_ACCENT", default="#FFE800")\nAPP_BRAND_INFO = config("APP_BRAND_INFO", default="#6FCFEB")\nAPP_BRAND_LOGO = config("APP_BRAND_LOGO", default="img/oftalmi-icon.png")\nAPP_BRAND_FAVICON = config("APP_BRAND_FAVICON", default="img/favicon.ico")\nAPP_BRAND_CAPSULE_ENABLED = config("APP_BRAND_CAPSULE_ENABLED", default=True, cast=bool)\n'''

if "APP_COMPANY_NAME" not in text:
    anchor = 'APP_ENV = config("APP_ENV", default="local")\n'
    if anchor not in text:
        raise SystemExit("APP_ENV anchor not found in settings/base.py")
    text = text.replace(anchor, anchor + branding_block, 1)

processor = '                "apps.accounts.context_processors.app_branding",\n'
if "apps.accounts.context_processors.app_branding" not in text:
    anchor = '                "apps.accounts.context_processors.role_navigation",\n'
    if anchor not in text:
        raise SystemExit("role_navigation context processor anchor not found")
    text = text.replace(anchor, anchor + processor, 1)

base_settings.write_text(text, encoding="utf-8")

cp_path = Path("backend/apps/accounts/context_processors.py")
cp = cp_path.read_text(encoding="utf-8")
if "from django.conf import settings" not in cp:
    cp = "from django.conf import settings\n" + cp

if "def app_branding(request):" not in cp:
    cp += '''\n\n\ndef app_branding(request):\n    """Expose company/app branding parameters to templates.\n\n    This keeps the UI reusable for separate deployments per company\n    without hardcoding visual identity in templates.\n    """\n\n    return {\n        "app_branding": {\n            "company_name": settings.APP_COMPANY_NAME,\n            "company_short_name": settings.APP_COMPANY_SHORT_NAME,\n            "product_name": settings.APP_PRODUCT_NAME,\n            "product_short_name": settings.APP_PRODUCT_SHORT_NAME,\n            "primary": settings.APP_BRAND_PRIMARY,\n            "secondary": settings.APP_BRAND_SECONDARY,\n            "accent": settings.APP_BRAND_ACCENT,\n            "info": settings.APP_BRAND_INFO,\n            "logo_path": settings.APP_BRAND_LOGO,\n            "favicon_path": settings.APP_BRAND_FAVICON,\n            "capsule_enabled": settings.APP_BRAND_CAPSULE_ENABLED,\n        }\n    }\n'''
cp_path.write_text(cp, encoding="utf-8")

env_example = Path(".env.example")
env = env_example.read_text(encoding="utf-8")
branding_env = '''\n# Branding / company presentation\nAPP_COMPANY_NAME=Laboratorios Oftalmi\nAPP_COMPANY_SHORT_NAME=Oftalmi\nAPP_PRODUCT_NAME=Sistema de Rutas de Pago\nAPP_PRODUCT_SHORT_NAME=Rutas de Pago\nAPP_BRAND_PRIMARY=#1226AA\nAPP_BRAND_SECONDARY=#8A1A9B\nAPP_BRAND_ACCENT=#FFE800\nAPP_BRAND_INFO=#6FCFEB\nAPP_BRAND_LOGO=img/oftalmi-icon.png\nAPP_BRAND_FAVICON=img/favicon.ico\nAPP_BRAND_CAPSULE_ENABLED=true\n'''
if "APP_COMPANY_NAME=" not in env:
    env = env.rstrip() + "\n" + branding_env
    env_example.write_text(env, encoding="utf-8")

Path("backend/templates/base.html").write_text('''{% load static %}\n<!doctype html>\n<html lang="es">\n<head>\n    <meta charset="utf-8">\n    <meta name="viewport" content="width=device-width, initial-scale=1">\n    <title>{% block title %}{{ app_branding.product_short_name }} | {{ app_branding.company_short_name }}{% endblock %}</title>\n    <link rel="icon" href="{% static app_branding.favicon_path %}">\n    <style>\n        :root {\n            --brand-primary: {{ app_branding.primary }};\n            --brand-secondary: {{ app_branding.secondary }};\n            --brand-accent: {{ app_branding.accent }};\n            --brand-info: {{ app_branding.info }};\n        }\n    </style>\n    <link rel="stylesheet" href="{% static 'css/oftalmi_branding.css' %}">\n</head>\n<body class="oftalmi-shell{% if app_branding.capsule_enabled %} has-capsule-bg{% endif %}">\n<header class="oftalmi-topbar">\n    <a class="oftalmi-brand" href="{% url 'accounts:dashboard' %}" aria-label="Inicio">\n        <span class="oftalmi-brand-logo-wrap">\n            <img class="oftalmi-brand-logo" src="{% static app_branding.logo_path %}" alt="{{ app_branding.company_short_name }}">\n        </span>\n        <span class="oftalmi-brand-copy">\n            <strong>{{ app_branding.product_short_name }}</strong>\n            <small>{{ app_branding.company_name }}</small>\n        </span>\n    </a>\n\n    {% if request.user.is_authenticated %}\n        <div class="oftalmi-userbar">\n            <span>{{ request.user.email }}</span>\n            <form method="post" action="{% url 'accounts:logout' %}">\n                {% csrf_token %}\n                <button class="button-secondary" type="submit">Cerrar sesión</button>\n            </form>\n        </div>\n    {% endif %}\n</header>\n\n{% if request.user.is_authenticated %}\n<nav class="oftalmi-nav" aria-label="Navegación principal">\n    {% if role_nav.can_view_payment_dashboard %}\n        <a class="nav-link" href="{% url 'payment_requests:dashboard' %}">Dashboard</a>\n    {% endif %}\n    {% if role_nav.can_view_payment_requests %}\n        <a class="nav-link" href="{% url 'payment_requests:list' %}">Solicitudes</a>\n    {% endif %}\n    {% if role_nav.can_create_payment_request %}\n        <a class="nav-link nav-link-primary" href="{% url 'payment_requests:create' %}">Nueva solicitud</a>\n    {% endif %}\n    {% if role_nav.can_view_pending_approvals %}\n        <a class="nav-link" href="{% url 'payment_approvals:pending' %}">Aprobaciones</a>\n    {% endif %}\n    {% if role_nav.can_view_accounts_payable %}\n        <a class="nav-link" href="{% url 'payment_requests:accounts_payable' %}">Cuentas por pagar</a>\n    {% endif %}\n    {% if role_nav.can_view_payment_request_report %}\n        <a class="nav-link" href="{% url 'payment_requests:report' %}">Reporte</a>\n    {% endif %}\n    {% if role_nav.can_view_audit_workbench %}\n        <a class="nav-link" href="{% url 'payment_approvals:audit' %}">Auditoría</a>\n    {% endif %}\n</nav>\n{% endif %}\n\n<main class="oftalmi-main">\n    {% block content %}{% endblock %}\n</main>\n\n<footer class="oftalmi-footer">\n    {{ app_branding.product_name }} · {{ app_branding.company_name }}\n</footer>\n</body>\n</html>\n''', encoding="utf-8")

Path("backend/templates/registration/login.html").write_text('''{% extends "base.html" %}\n{% load static %}\n\n{% block title %}Iniciar sesión | {{ app_branding.product_short_name }}{% endblock %}\n\n{% block content %}\n<section class="login-shell">\n    <div class="login-hero">\n        <div class="login-badge">Gestión controlada de pagos</div>\n        <h1>{{ app_branding.product_name }}</h1>\n        <p>Solicitudes, aprobaciones, Cuentas por Pagar y trazabilidad operativa en una sola plataforma.</p>\n        <div class="login-pill-row">\n            <span>Rutas aprobatorias</span>\n            <span>Auditoría</span>\n            <span>Backups</span>\n        </div>\n    </div>\n\n    <section class="card login-card">\n        <img class="login-logo" src="{% static app_branding.logo_path %}" alt="{{ app_branding.company_short_name }}">\n        <h2>Iniciar sesión</h2>\n        <p class="muted">Acceso corporativo para usuarios autorizados.</p>\n\n        {% if form.errors %}\n            <p class="errorlist">Credenciales inválidas. Verifica el correo y la contraseña.</p>\n        {% endif %}\n\n        <form method="post" novalidate>\n            {% csrf_token %}\n            <label for="id_username">Correo electrónico</label>\n            {{ form.username }}\n\n            <label for="id_password">Contraseña</label>\n            {{ form.password }}\n\n            <button class="button button-full" type="submit">Entrar</button>\n        </form>\n    </section>\n</section>\n{% endblock %}\n''', encoding="utf-8")

Path("backend/templates/accounts/dashboard.html").write_text('''{% extends "base.html" %}\n\n{% block title %}Panel principal | {{ app_branding.product_short_name }}{% endblock %}\n\n{% block content %}\n<section class="oftalmi-page-header">\n    <div>\n        <p class="eyebrow">Panel principal</p>\n        <h1>Bienvenido a {{ app_branding.product_short_name }}</h1>\n        <p>Resumen de identidad operativa, rol y alcance organizativo del usuario autenticado.</p>\n    </div>\n</section>\n\n<section class="identity-grid">\n    <article class="card identity-card">\n        <span class="identity-label">Usuario</span>\n        <strong>{{ request.user.email }}</strong>\n    </article>\n    <article class="card identity-card">\n        <span class="identity-label">Rol</span>\n        <strong>{{ request.user.get_role_display|default:request.user.role }}</strong>\n    </article>\n    <article class="card identity-card">\n        <span class="identity-label">Empresa principal</span>\n        <strong>{{ request.user.primary_company|default:"No definida" }}</strong>\n    </article>\n    <article class="card identity-card">\n        <span class="identity-label">Unidad organizativa</span>\n        <strong>{{ request.user.primary_organizational_unit|default:"No definida" }}</strong>\n    </article>\n</section>\n{% endblock %}\n''', encoding="utf-8")

Path("backend/templates/payment_requests/paymentrequest_dashboard.html").write_text('''{% extends "base.html" %}\n\n{% block title %}Dashboard operativo | {{ app_branding.product_short_name }}{% endblock %}\n\n{% block content %}\n<section class="oftalmi-page-header dashboard-header">\n  <div>\n    <p class="eyebrow">Operación controlada</p>\n    <h1>Dashboard operativo de solicitudes</h1>\n    <p>Indicadores, pendientes y accesos rápidos según rol y alcance operativo.</p>\n  </div>\n  <div class="dashboard-profile">\n    <span>Rol</span>\n    <strong>{{ dashboard_role_label }}</strong>\n    <small>{{ dashboard_scope_label }}</small>\n  </div>\n</section>\n\n<section class="quick-actions">\n  {% if role_nav.can_view_pending_approvals %}\n    <a class="quick-action" href="{% url 'payment_approvals:pending' %}">Pendientes por aprobar</a>\n  {% endif %}\n  {% if role_nav.can_view_accounts_payable %}\n    <a class="quick-action" href="{% url 'payment_requests:accounts_payable' %}">Cuentas por Pagar</a>\n  {% endif %}\n  {% if role_nav.can_view_payment_request_report %}\n    <a class="quick-action" href="{% url 'payment_requests:report' %}">Reporte operativo</a>\n  {% endif %}\n  {% if role_nav.can_view_audit_workbench %}\n    <a class="quick-action" href="{% url 'payment_approvals:audit' %}">Auditoría crítica</a>\n  {% endif %}\n</section>\n\n<section class="kpi-grid">\n  <article class="card oftalmi-kpi">\n    <span class="kpi-label">Total de solicitudes</span>\n    <strong class="kpi-value">{{ total_requests }}</strong>\n  </article>\n  {% for card in status_cards %}\n    <article class="card oftalmi-kpi">\n      <span class="kpi-label">{{ card.label }}</span>\n      <strong class="kpi-value">{{ card.total }}</strong>\n    </article>\n  {% endfor %}\n</section>\n\n{% if role_nav.can_view_accounts_payable %}\n<section class="card section-card">\n  <div class="section-card-header">\n    <div>\n      <h2>Solicitudes aprobadas pendientes de pago</h2>\n      <p>Total pendiente de pago: <strong>{{ pending_payment_count }}</strong></p>\n    </div>\n  </div>\n\n  {% if pending_payment_requests %}\n    <div class="table-wrap">\n      <table>\n        <thead>\n          <tr>\n            <th>ID</th>\n            <th>Empresa</th>\n            <th>Beneficiario</th>\n            <th>Monto</th>\n            <th>Fecha estimada</th>\n            <th>Acción</th>\n          </tr>\n        </thead>\n        <tbody>\n          {% for payment_request in pending_payment_requests %}\n            <tr>\n              <td>#{{ payment_request.id }}</td>\n              <td>{{ payment_request.company }}</td>\n              <td>{{ payment_request.beneficiary }}</td>\n              <td>{{ payment_request.amount }} {{ payment_request.currency }}</td>\n              <td>{{ payment_request.due_date|default:"Sin fecha" }}</td>\n              <td><a href="{% url 'payment_requests:detail' payment_request.pk %}">Ver solicitud</a></td>\n            </tr>\n          {% endfor %}\n        </tbody>\n      </table>\n    </div>\n  {% else %}\n    <p class="empty-state">No hay solicitudes aprobadas pendientes de pago.</p>\n  {% endif %}\n</section>\n{% endif %}\n\n{% if role_nav.can_view_audit_workbench %}\n<section class="card section-card">\n  <div class="section-card-header">\n    <div>\n      <h2>Auditoría operativa</h2>\n      <p>Acciones registradas en el alcance: <strong>{{ audit_action_count }}</strong></p>\n    </div>\n    <a class="button" href="{% url 'payment_approvals:audit' %}">Ir a auditoría</a>\n  </div>\n</section>\n{% endif %}\n\n<section class="card section-card">\n  <div class="section-card-header">\n    <h2>Pendientes de aprobación para mi rol</h2>\n  </div>\n\n  {% if pending_approval_steps %}\n    <div class="table-wrap">\n      <table>\n        <thead>\n          <tr>\n            <th>Solicitud</th>\n            <th>Empresa</th>\n            <th>Beneficiario</th>\n            <th>Monto</th>\n            <th>Paso</th>\n            <th>Acción</th>\n          </tr>\n        </thead>\n        <tbody>\n          {% for step in pending_approval_steps %}\n            <tr>\n              <td>#{{ step.payment_request.id }}</td>\n              <td>{{ step.payment_request.company }}</td>\n              <td>{{ step.payment_request.beneficiary }}</td>\n              <td>{{ step.payment_request.amount }} {{ step.payment_request.currency }}</td>\n              <td>{{ step.sequence }}</td>\n              <td><a href="{% url 'payment_requests:detail' step.payment_request.pk %}">Ver solicitud</a></td>\n            </tr>\n          {% endfor %}\n        </tbody>\n      </table>\n    </div>\n  {% else %}\n    <p class="empty-state">No hay aprobaciones pendientes para tu rol.</p>\n  {% endif %}\n</section>\n\n<section class="card section-card">\n  <div class="section-card-header">\n    <h2>Últimas solicitudes</h2>\n  </div>\n\n  {% if latest_requests %}\n    <div class="table-wrap">\n      <table>\n        <thead>\n          <tr>\n            <th>ID</th>\n            <th>Empresa</th>\n            <th>Beneficiario</th>\n            <th>Concepto</th>\n            <th>Monto</th>\n            <th>Estado</th>\n            <th>Creada</th>\n          </tr>\n        </thead>\n        <tbody>\n          {% for payment_request in latest_requests %}\n            <tr>\n              <td><a href="{% url 'payment_requests:detail' payment_request.pk %}">#{{ payment_request.id }}</a></td>\n              <td>{{ payment_request.company }}</td>\n              <td>{{ payment_request.beneficiary }}</td>\n              <td>{{ payment_request.concept }}</td>\n              <td>{{ payment_request.amount }} {{ payment_request.currency }}</td>\n              <td>{{ payment_request.get_status_display }}</td>\n              <td>{{ payment_request.created_at }}</td>\n            </tr>\n          {% endfor %}\n        </tbody>\n      </table>\n    </div>\n  {% else %}\n    <p class="empty-state">No hay solicitudes registradas.</p>\n  {% endif %}\n</section>\n{% endblock %}\n''', encoding="utf-8")
PY

cat > backend/static/css/oftalmi_branding.css <<'CSS'
:root {
  --brand-primary: var(--brand-primary, #1226AA);
  --brand-secondary: var(--brand-secondary, #8A1A9B);
  --brand-accent: var(--brand-accent, #FFE800);
  --brand-info: var(--brand-info, #6FCFEB);
  --surface: #ffffff;
  --surface-soft: #f6f8ff;
  --border: #d9deea;
  --text: #172033;
  --muted: #667085;
  --danger: #b42318;
  --radius: 1rem;
  --shadow: 0 1rem 2.5rem rgba(18, 38, 170, 0.10);
}

* {
  box-sizing: border-box;
}

html {
  font-family: Arial, Helvetica, sans-serif;
  color: var(--text);
  background: #f4f6fb;
}

body {
  margin: 0;
  background: #f4f6fb;
  color: var(--text);
}

.oftalmi-shell {
  min-height: 100vh;
  background:
    radial-gradient(circle at top left, rgba(111, 207, 235, 0.30), transparent 22rem),
    radial-gradient(circle at 90% 0%, rgba(138, 26, 155, 0.12), transparent 28rem),
    linear-gradient(180deg, #f8faff 0%, #f4f6fb 55%, #eef2fa 100%);
}

.oftalmi-shell.has-capsule-bg::before {
  content: "";
  position: fixed;
  inset: 8rem -18rem auto auto;
  width: 34rem;
  height: 12rem;
  border: 0.9rem solid rgba(18, 38, 170, 0.06);
  border-radius: 999px;
  transform: rotate(-28deg);
  pointer-events: none;
}

.oftalmi-topbar {
  position: sticky;
  top: 0;
  z-index: 10;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
  padding: 1rem 1.75rem;
  color: #ffffff;
  background: linear-gradient(110deg, var(--brand-primary), var(--brand-secondary));
  box-shadow: 0 0.75rem 2rem rgba(18, 38, 170, 0.24);
}

.oftalmi-brand {
  display: inline-flex;
  align-items: center;
  gap: 0.85rem;
  color: #ffffff;
  text-decoration: none;
}

.oftalmi-brand-logo-wrap {
  width: 3rem;
  height: 3rem;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: #ffffff;
  border-radius: 1rem;
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.35), 0 0.5rem 1.4rem rgba(0, 0, 0, 0.16);
}

.oftalmi-brand-logo {
  width: 2.25rem;
  height: 2.25rem;
  object-fit: contain;
}

.oftalmi-brand-copy {
  display: grid;
  gap: 0.1rem;
}

.oftalmi-brand-copy strong {
  font-size: 1.05rem;
  letter-spacing: -0.01em;
}

.oftalmi-brand-copy small,
.oftalmi-userbar span {
  opacity: 0.86;
  font-size: 0.85rem;
}

.oftalmi-userbar {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.oftalmi-nav {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  padding: 0.85rem 1.75rem;
  background: rgba(255, 255, 255, 0.90);
  border-bottom: 1px solid rgba(217, 222, 234, 0.9);
  backdrop-filter: blur(10px);
}

.nav-link {
  color: var(--text);
  border: 1px solid transparent;
  border-radius: 999px;
  padding: 0.55rem 0.85rem;
  text-decoration: none;
  font-weight: 700;
  font-size: 0.92rem;
}

.nav-link:hover,
.nav-link:focus {
  color: var(--brand-primary);
  background: rgba(18, 38, 170, 0.06);
  border-color: rgba(18, 38, 170, 0.14);
}

.nav-link-primary {
  color: var(--brand-primary);
  background: rgba(255, 232, 0, 0.25);
  border-color: rgba(255, 232, 0, 0.75);
}

.oftalmi-main {
  width: min(1180px, calc(100% - 2rem));
  margin: 2rem auto;
}

.card,
.oftalmi-card,
.section-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  box-shadow: var(--shadow);
  padding: 1.35rem;
}

.oftalmi-page-header {
  display: flex;
  justify-content: space-between;
  align-items: stretch;
  gap: 1.5rem;
  background: linear-gradient(135deg, #ffffff 0%, #f8fbff 100%);
  border: 1px solid var(--border);
  border-left: 0.45rem solid var(--brand-primary);
  border-radius: var(--radius);
  box-shadow: var(--shadow);
  padding: 1.5rem;
  margin-bottom: 1.5rem;
}

.oftalmi-page-header h1,
.oftalmi-page-header h2,
.oftalmi-page-header h3 {
  color: var(--text);
  margin: 0 0 0.4rem;
}

.oftalmi-page-header p {
  color: var(--muted);
  margin: 0;
}

.eyebrow {
  color: var(--brand-secondary) !important;
  font-size: 0.78rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.12em;
  margin-bottom: 0.45rem !important;
}

.muted {
  color: var(--muted);
}

label {
  display: block;
  margin-bottom: 0.35rem;
  font-weight: 800;
}

input,
select,
textarea,
.form-control,
.form-select {
  width: 100%;
  border: 1px solid #cfd6e4;
  border-radius: 0.8rem;
  padding: 0.75rem 0.85rem;
  margin-bottom: 1rem;
  background: #ffffff;
}

input:focus,
select:focus,
textarea:focus,
.form-control:focus,
.form-select:focus {
  border-color: var(--brand-info);
  outline: 0;
  box-shadow: 0 0 0 0.2rem rgba(111, 207, 235, 0.28);
}

button,
.button,
.btn,
.btn-primary {
  display: inline-flex;
  justify-content: center;
  align-items: center;
  gap: 0.45rem;
  background: linear-gradient(135deg, var(--brand-primary), var(--brand-secondary));
  color: #ffffff;
  border: 0;
  border-radius: 0.85rem;
  padding: 0.72rem 1rem;
  cursor: pointer;
  text-decoration: none;
  font-weight: 800;
}

.button:hover,
button:hover,
.btn:hover {
  filter: brightness(1.04);
}

.button-secondary {
  background: rgba(255, 255, 255, 0.16);
  color: #ffffff;
  border: 1px solid rgba(255, 255, 255, 0.28);
}

.button-full {
  width: 100%;
}

.errorlist {
  color: var(--danger);
  background: rgba(180, 35, 24, 0.08);
  border: 1px solid rgba(180, 35, 24, 0.16);
  border-radius: 0.8rem;
  padding: 0.75rem 0.85rem;
}

.login-shell {
  display: grid;
  grid-template-columns: minmax(0, 1.05fr) minmax(340px, 0.75fr);
  gap: 2rem;
  align-items: center;
  min-height: calc(100vh - 13rem);
}

.login-hero {
  padding: 2rem;
}

.login-badge {
  display: inline-flex;
  border: 1px solid rgba(18, 38, 170, 0.14);
  background: rgba(255, 232, 0, 0.32);
  color: var(--brand-primary);
  border-radius: 999px;
  padding: 0.45rem 0.8rem;
  font-weight: 800;
  margin-bottom: 1.1rem;
}

.login-hero h1 {
  max-width: 660px;
  font-size: clamp(2.2rem, 5vw, 4.25rem);
  line-height: 0.95;
  margin: 0 0 1rem;
  color: var(--brand-primary);
  letter-spacing: -0.05em;
}

.login-hero p {
  max-width: 620px;
  color: var(--muted);
  font-size: 1.12rem;
}

.login-pill-row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.65rem;
  margin-top: 1.5rem;
}

.login-pill-row span {
  background: #ffffff;
  border: 1px solid var(--border);
  border-radius: 999px;
  padding: 0.55rem 0.85rem;
  box-shadow: 0 0.5rem 1.4rem rgba(18, 38, 170, 0.06);
  font-weight: 700;
}

.login-card {
  padding: 2rem;
}

.login-logo {
  width: 4.5rem;
  height: 4.5rem;
  object-fit: contain;
  margin-bottom: 1rem;
}

.login-card h2 {
  margin: 0 0 0.25rem;
  font-size: 1.8rem;
}

.identity-grid,
.kpi-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
  gap: 1rem;
}

.identity-card,
.oftalmi-kpi {
  border-left: 0.35rem solid var(--brand-primary);
}

.identity-label,
.kpi-label {
  display: block;
  color: var(--muted);
  font-size: 0.78rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  margin-bottom: 0.45rem;
}

.identity-card strong,
.kpi-value {
  color: var(--text);
  font-size: 1.65rem;
  line-height: 1.1;
}

.dashboard-header {
  align-items: center;
}

.dashboard-profile {
  min-width: 220px;
  background: linear-gradient(135deg, var(--brand-primary), var(--brand-secondary));
  color: #ffffff;
  border-radius: 1rem;
  padding: 1rem;
}

.dashboard-profile span,
.dashboard-profile small {
  display: block;
  opacity: 0.85;
}

.dashboard-profile strong {
  display: block;
  margin: 0.25rem 0;
  font-size: 1.05rem;
}

.quick-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
  margin-bottom: 1.25rem;
}

.quick-action {
  background: #ffffff;
  color: var(--brand-primary);
  border: 1px solid rgba(18, 38, 170, 0.16);
  border-radius: 999px;
  padding: 0.7rem 1rem;
  text-decoration: none;
  font-weight: 800;
  box-shadow: 0 0.55rem 1.3rem rgba(18, 38, 170, 0.05);
}

.section-card {
  margin-top: 1.25rem;
}

.section-card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1rem;
}

.section-card-header h2 {
  margin: 0 0 0.2rem;
}

.section-card-header p {
  margin: 0;
  color: var(--muted);
}

.table-wrap {
  width: 100%;
  overflow-x: auto;
}

table,
.table {
  width: 100%;
  border-collapse: collapse;
  background: #ffffff;
}

thead th,
.table thead th {
  background: rgba(111, 207, 235, 0.18);
  color: var(--brand-primary);
  border-bottom: 1px solid var(--border);
  font-size: 0.78rem;
  text-align: left;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  padding: 0.75rem;
}

tbody td,
.table tbody td {
  border-bottom: 1px solid var(--border);
  padding: 0.75rem;
  vertical-align: top;
}

tbody tr:hover,
.table tbody tr:hover {
  background: rgba(18, 38, 170, 0.035);
}

a {
  color: var(--brand-primary);
}

.empty-state {
  color: var(--muted);
  background: var(--surface-soft);
  border: 1px dashed var(--border);
  border-radius: 0.9rem;
  padding: 1rem;
}

dl {
  display: grid;
  grid-template-columns: 220px 1fr;
  gap: 0.75rem 1rem;
}

dt {
  font-weight: 800;
}

dd {
  margin: 0;
}

.oftalmi-footer {
  width: min(1180px, calc(100% - 2rem));
  margin: 2rem auto;
  color: var(--muted);
  font-size: 0.86rem;
}

@media (max-width: 760px) {
  .oftalmi-topbar,
  .oftalmi-userbar,
  .oftalmi-page-header,
  .section-card-header {
    align-items: flex-start;
    flex-direction: column;
  }

  .login-shell {
    grid-template-columns: 1fr;
  }

  .login-hero {
    padding: 0.5rem 0;
  }

  .dashboard-profile {
    width: 100%;
  }
}
CSS

printf '\n== Syntax and Django template/settings sanity ==\n'
python3 -m py_compile backend/config/settings/base.py backend/apps/accounts/context_processors.py

git diff --check

printf '\n== Changed files ==\n'
git status --short

printf '\n== Branding settings/context summary ==\n'
grep -nE 'APP_COMPANY|APP_PRODUCT|APP_BRAND|app_branding|context_processors' backend/config/settings/base.py backend/apps/accounts/context_processors.py .env.example

printf '\n== Result ==\n'
printf 'BRANDING_PARAMETRIZATION_APPLIED_READY_FOR_DJANGO_CHECK\n'
