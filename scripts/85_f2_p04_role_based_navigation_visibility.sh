#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== F2-P04: Visibilidad de navegacion segun rol =="

python3 - <<'PY'
from pathlib import Path

root = Path('/home/dchirinos/oftalmiIA/emisiones/emisiones')

role_permissions = root / 'backend/apps/accounts/role_permissions.py'
if not role_permissions.exists():
    raise SystemExit('ERROR: no existe backend/apps/accounts/role_permissions.py. Ejecuta/cierra primero F2-P03.')

text = role_permissions.read_text(encoding='utf-8')
required = [
    'PERM_VIEW_PAYMENT_REQUEST_DASHBOARD',
    'PERM_VIEW_PAYMENT_REQUESTS',
    'PERM_CREATE_PAYMENT_REQUEST',
    'PERM_VIEW_PENDING_APPROVALS',
    'PERM_VIEW_AUDIT_WORKBENCH',
    'PERM_VIEW_ACCOUNTS_PAYABLE',
    'user_has_permission',
]
missing = [item for item in required if item not in text]
if missing:
    raise SystemExit('ERROR: faltan permisos base de F2-P03: ' + ', '.join(missing))

# Context processor for permission-aware navigation.
context_processors = root / 'backend/apps/accounts/context_processors.py'
context_processors.write_text('''from apps.accounts.role_permissions import (\n    PERM_CREATE_PAYMENT_REQUEST,\n    PERM_VIEW_ACCOUNTS_PAYABLE,\n    PERM_VIEW_AUDIT_WORKBENCH,\n    PERM_VIEW_PAYMENT_REQUEST_DASHBOARD,\n    PERM_VIEW_PAYMENT_REQUESTS,\n    PERM_VIEW_PENDING_APPROVALS,\n    user_has_permission,\n)\n\n\ndef role_navigation(request):\n    \"\"\"Expose role-aware navigation flags to templates.\n\n    Backend permissions remain authoritative. These flags only prevent\n    showing links that the current user cannot use.\n    \"\"\"\n\n    user = getattr(request, "user", None)\n\n    nav_permissions = {\n        "can_view_payment_dashboard": user_has_permission(user, PERM_VIEW_PAYMENT_REQUEST_DASHBOARD),\n        "can_view_payment_requests": user_has_permission(user, PERM_VIEW_PAYMENT_REQUESTS),\n        "can_create_payment_request": user_has_permission(user, PERM_CREATE_PAYMENT_REQUEST),\n        "can_view_pending_approvals": user_has_permission(user, PERM_VIEW_PENDING_APPROVALS),\n        "can_view_audit_workbench": user_has_permission(user, PERM_VIEW_AUDIT_WORKBENCH),\n        "can_view_accounts_payable": user_has_permission(user, PERM_VIEW_ACCOUNTS_PAYABLE),\n    }\n\n    return {"role_nav": nav_permissions}\n''', encoding='utf-8')
print(f'OK: creado/actualizado {context_processors}')

# Tests for context processor.
tests_dir = root / 'backend/apps/accounts/tests'
tests_dir.mkdir(parents=True, exist_ok=True)
nav_tests = tests_dir / 'test_role_navigation_context.py'
nav_tests.write_text('''from django.contrib.auth import get_user_model\nfrom django.test import RequestFactory, TestCase\n\nfrom apps.accounts.context_processors import role_navigation\nfrom apps.accounts.models import UserRole\n\n\nclass RoleNavigationContextTests(TestCase):\n    def setUp(self):\n        self.factory = RequestFactory()\n        self.user_model = get_user_model()\n\n    def _request_for_role(self, role):\n        request = self.factory.get("/")\n        request.user = self.user_model.objects.create_user(\n            email=f"{role.lower()}@example.com",\n            password="test-pass-123",\n            role=role,\n        )\n        return request\n\n    def test_solicitante_navigation_flags(self):\n        context = role_navigation(self._request_for_role(UserRole.SOLICITANTE))\n\n        self.assertTrue(context["role_nav"]["can_view_payment_dashboard"])\n        self.assertTrue(context["role_nav"]["can_view_payment_requests"])\n        self.assertTrue(context["role_nav"]["can_create_payment_request"])\n        self.assertFalse(context["role_nav"]["can_view_accounts_payable"])\n        self.assertFalse(context["role_nav"]["can_view_audit_workbench"])\n\n    def test_cuentas_por_pagar_navigation_flags(self):\n        context = role_navigation(self._request_for_role(UserRole.CUENTAS_POR_PAGAR))\n\n        self.assertTrue(context["role_nav"]["can_view_accounts_payable"])\n        self.assertTrue(context["role_nav"]["can_view_payment_requests"])\n        self.assertFalse(context["role_nav"]["can_create_payment_request"])\n\n    def test_auditor_navigation_flags(self):\n        context = role_navigation(self._request_for_role(UserRole.AUDITOR))\n\n        self.assertTrue(context["role_nav"]["can_view_audit_workbench"])\n        self.assertTrue(context["role_nav"]["can_view_payment_requests"])\n        self.assertFalse(context["role_nav"]["can_create_payment_request"])\n\n    def test_anonymous_navigation_flags_are_false(self):\n        request = self.factory.get("/")\n\n        class AnonymousLikeUser:\n            is_authenticated = False\n\n        request.user = AnonymousLikeUser()\n        context = role_navigation(request)\n\n        self.assertTrue(context["role_nav"])\n        self.assertTrue(all(value is False for value in context["role_nav"].values()))\n''', encoding='utf-8')
print(f'OK: creado/actualizado {nav_tests}')

# Register context processor in settings files that contain TEMPLATES context_processors.
settings_candidates = list((root / 'backend').rglob('settings*.py')) + list((root / 'config').rglob('settings*.py'))
settings_candidates = [p for p in settings_candidates if p.is_file()]
registered = []
needle = 'apps.accounts.context_processors.role_navigation'
for path in settings_candidates:
    content = path.read_text(encoding='utf-8')
    if 'context_processors' not in content or 'django.template.context_processors.request' not in content:
        continue
    if needle in content:
        registered.append(str(path))
        continue
    marker = "'django.template.context_processors.request',"
    marker2 = '"django.template.context_processors.request",'
    if marker in content:
        content = content.replace(marker, marker + f"\n                '{needle}',", 1)
    elif marker2 in content:
        content = content.replace(marker2, marker2 + f'\n                "{needle}",', 1)
    else:
        continue
    path.write_text(content, encoding='utf-8')
    registered.append(str(path))

if not registered:
    raise SystemExit('ERROR: no se pudo registrar el context processor en settings. Revisar TEMPLATES manualmente.')
print('OK: context processor registrado en:')
for item in registered:
    print(f'- {item}')

# Update base template navigation. Prefer backend/templates/base.html.
template_candidates = [
    root / 'backend/templates/base.html',
    root / 'backend/templates/base_site.html',
    root / 'backend/templates/layout.html',
]
base = next((p for p in template_candidates if p.exists()), None)
if base is None:
    raise SystemExit('ERROR: no se encontro template base para actualizar navegacion.')

html = base.read_text(encoding='utf-8')
start = '<!-- F2-P04 role-aware navigation start -->'
end = '<!-- F2-P04 role-aware navigation end -->'
nav_block = '''<!-- F2-P04 role-aware navigation start -->\n{% if user.is_authenticated %}\n  <nav class="oftalmi-role-nav" aria-label="Navegacion operativa">\n    {% if role_nav.can_view_payment_dashboard %}\n      <a class="oftalmi-role-nav__link" href="/payment-requests/dashboard/">Dashboard solicitudes</a>\n    {% endif %}\n    {% if role_nav.can_view_payment_requests %}\n      <a class="oftalmi-role-nav__link" href="/payment-requests/">Solicitudes</a>\n    {% endif %}\n    {% if role_nav.can_create_payment_request %}\n      <a class="oftalmi-role-nav__link" href="/payment-requests/create/">Nueva solicitud</a>\n    {% endif %}\n    {% if role_nav.can_view_pending_approvals %}\n      <a class="oftalmi-role-nav__link" href="/payment-approvals/pending/">Pendientes por aprobar</a>\n    {% endif %}\n    {% if role_nav.can_view_accounts_payable %}\n      <a class="oftalmi-role-nav__link" href="/payment-requests/accounts-payable/">Cuentas por pagar</a>\n    {% endif %}\n    {% if role_nav.can_view_audit_workbench %}\n      <a class="oftalmi-role-nav__link" href="/payment-approvals/audit/">Auditoria</a>\n    {% endif %}\n  </nav>\n{% endif %}\n<!-- F2-P04 role-aware navigation end -->'''

if start in html and end in html:
    before, rest = html.split(start, 1)
    _, after = rest.split(end, 1)
    html = before + nav_block + after
else:
    # Insert after body open when possible, otherwise before main/container, otherwise append.
    if '<body>' in html:
        html = html.replace('<body>', '<body>\n' + nav_block, 1)
    elif '<body ' in html:
        idx = html.find('>', html.find('<body '))
        html = html[:idx+1] + '\n' + nav_block + html[idx+1:]
    elif '<main' in html:
        html = html.replace('<main', nav_block + '\n<main', 1)
    else:
        html = html + '\n' + nav_block + '\n'
base.write_text(html, encoding='utf-8')
print(f'OK: navegacion role-aware insertada/actualizada en {base}')

# Append CSS if branding file exists; otherwise create minimal css.
css = root / 'backend/static/css/oftalmi_branding.css'
css.parent.mkdir(parents=True, exist_ok=True)
css_text = css.read_text(encoding='utf-8') if css.exists() else ''
css_marker = '/* F2-P04 role-aware navigation */'
css_block = '''\n/* F2-P04 role-aware navigation */\n.oftalmi-role-nav {\n  display: flex;\n  flex-wrap: wrap;\n  gap: 0.5rem;\n  align-items: center;\n  padding: 0.75rem 1rem;\n  margin: 0 auto 1rem;\n  max-width: 1200px;\n  background: #ffffff;\n  border: 1px solid rgba(13, 110, 253, 0.14);\n  border-radius: 0.85rem;\n  box-shadow: 0 8px 24px rgba(23, 32, 51, 0.07);\n}\n\n.oftalmi-role-nav__link {\n  display: inline-flex;\n  align-items: center;\n  justify-content: center;\n  min-height: 2.25rem;\n  padding: 0.45rem 0.75rem;\n  color: #172033;\n  font-weight: 600;\n  text-decoration: none;\n  border-radius: 999px;\n  background: rgba(13, 110, 253, 0.08);\n}\n\n.oftalmi-role-nav__link:hover,\n.oftalmi-role-nav__link:focus {\n  color: #0d6efd;\n  background: rgba(13, 110, 253, 0.14);\n  text-decoration: none;\n}\n'''
if css_marker not in css_text:
    css.write_text(css_text.rstrip() + '\n' + css_block, encoding='utf-8')
    print(f'OK: estilos de navegacion agregados en {css}')
else:
    print(f'OK: estilos F2-P04 ya existen en {css}')

# Docs.
doc = root / 'docs/f2_p04_visibilidad_navegacion_por_rol.md'
doc.write_text('''# F2-P04 - Visibilidad de navegacion segun rol\n\n## Objetivo\n\nEvitar que usuarios autenticados vean opciones de menu que no pueden ejecutar por permisos backend, reduciendo friccion operativa y exposicion innecesaria de rutas que terminan en `403`.\n\n## Alcance\n\n- Se agrega un context processor `role_navigation`.\n- Se expone el diccionario `role_nav` a los templates.\n- Se actualiza la navegacion base para renderizar enlaces segun permisos efectivos.\n- Se agregan pruebas unitarias del contrato de visibilidad por rol.\n- No se modifican modelos.\n- No se crean migraciones.\n- No se relajan permisos backend.\n\n## Principio de seguridad\n\nLa visibilidad en UI no sustituye los controles backend. Los permisos aplicados en F2-P03 siguen siendo la fuente de verdad. F2-P04 solo mejora la experiencia y evita accesos visibles no autorizados.\n\n## Enlaces controlados\n\n| Enlace | Flag | Permiso fuente |\n|---|---|---|\n| Dashboard solicitudes | `can_view_payment_dashboard` | `PERM_VIEW_PAYMENT_REQUEST_DASHBOARD` |\n| Solicitudes | `can_view_payment_requests` | `PERM_VIEW_PAYMENT_REQUESTS` |\n| Nueva solicitud | `can_create_payment_request` | `PERM_CREATE_PAYMENT_REQUEST` |\n| Pendientes por aprobar | `can_view_pending_approvals` | `PERM_VIEW_PENDING_APPROVALS` |\n| Cuentas por pagar | `can_view_accounts_payable` | `PERM_VIEW_ACCOUNTS_PAYABLE` |\n| Auditoria | `can_view_audit_workbench` | `PERM_VIEW_AUDIT_WORKBENCH` |\n\n## Criterios de aceptacion\n\n- Usuario anonimo no recibe enlaces operativos.\n- Solicitante ve opciones propias de solicitud.\n- Cuentas por Pagar ve acceso a Cuentas por Pagar.\n- Auditor ve acceso a Auditoria.\n- `ruff check .` debe pasar.\n- `manage.py check` debe pasar.\n- No debe haber migraciones nuevas.\n- Suite backend debe quedar verde.\n''', encoding='utf-8')
print(f'OK: creado/actualizado {doc}')

matrix = root / 'docs/matriz_visibilidad_navegacion_fase2.md'
matrix.write_text('''# Matriz de visibilidad de navegacion - Fase 2\n\n| Rol | Dashboard solicitudes | Solicitudes | Nueva solicitud | Pendientes aprobar | Cuentas por pagar | Auditoria |\n|---|---:|---:|---:|---:|---:|---:|\n| ADMINISTRADOR | Si | Si | Si | Si | Si | Si |\n| SOLICITANTE | Si | Si | Si | No | No | No |\n| RESPONSABLE_UNIDAD | Si | Si | No | Si | No | No |\n| FINANZAS | Si | Si | No | Si | No | No |\n| CUENTAS_POR_PAGAR | Si | Si | No | No | Si | No |\n| AUDITOR | Si | Si | No | No | No | Si |\n\n## Nota operativa\n\nEsta matriz gobierna la visibilidad del menu. La autorizacion real sigue validandose en las vistas criticas mediante los permisos backend centralizados.\n''', encoding='utf-8')
print(f'OK: creado/actualizado {matrix}')
PY

echo "== Validacion rapida =="
docker compose exec backend ruff check .
docker compose exec backend python manage.py test apps.accounts.tests.test_role_navigation_context

echo "== Archivos modificados =="
git status --short
