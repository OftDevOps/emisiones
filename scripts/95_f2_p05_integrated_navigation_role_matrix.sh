#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_ROOT"

echo "== F2-P05: pruebas integradas de navegacion por rol / matriz UX-permisos =="

TEST_FILE="backend/apps/accounts/tests/test_role_navigation_integrated_matrix.py"
DOC_FILE="docs/f2_p05_pruebas_integradas_navegacion_rol.md"
MATRIX_DOC="docs/matriz_ux_permisos_navegacion_fase2.md"
BASE_TEMPLATE="backend/templates/base.html"
CONTEXT_PROCESSOR="backend/apps/accounts/context_processors.py"

if [ ! -f "$BASE_TEMPLATE" ]; then
  echo "ERROR: no existe $BASE_TEMPLATE"
  exit 1
fi

if [ ! -f "$CONTEXT_PROCESSOR" ]; then
  echo "ERROR: no existe $CONTEXT_PROCESSOR"
  exit 1
fi

echo "== Validando precondiciones F2-P04/F2-P04B =="
grep -q 'return {"role_nav": nav_permissions}' "$CONTEXT_PROCESSOR"
grep -q 'role_nav.can_view_payment_dashboard' "$BASE_TEMPLATE"
grep -q 'role_nav.can_view_accounts_payable' "$BASE_TEMPLATE"
grep -q 'role_nav.can_view_audit_workbench' "$BASE_TEMPLATE"

cat > "$TEST_FILE" <<'PY'
import re

from django.contrib.auth import get_user_model
from django.core.exceptions import PermissionDenied
from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import UserRole
from apps.accounts.role_permissions import (
    PERM_CREATE_PAYMENT_REQUEST,
    PERM_VIEW_ACCOUNTS_PAYABLE,
    PERM_VIEW_AUDIT_WORKBENCH,
    PERM_VIEW_PAYMENT_REQUEST_DASHBOARD,
    PERM_VIEW_PAYMENT_REQUESTS,
    PERM_VIEW_PENDING_APPROVALS,
    user_has_permission,
)


NAVIGATION_CASES = (
    ("Solicitudes", "payment_requests:dashboard", PERM_VIEW_PAYMENT_REQUEST_DASHBOARD),
    ("Listado", "payment_requests:list", PERM_VIEW_PAYMENT_REQUESTS),
    ("Nueva solicitud", "payment_requests:create", PERM_CREATE_PAYMENT_REQUEST),
    ("Aprobaciones", "payment_approvals:pending", PERM_VIEW_PENDING_APPROVALS),
    ("Cuentas por pagar", "payment_requests:accounts_payable", PERM_VIEW_ACCOUNTS_PAYABLE),
    ("Auditoria", "payment_approvals:audit", PERM_VIEW_AUDIT_WORKBENCH),
)


class RoleNavigationIntegratedMatrixTests(TestCase):
    password = "Demo123456*"

    def create_user(self, role):
        user_model = get_user_model()
        role_value = role.value
        email = f"{role_value.lower()}@nav-matrix.oftalmi.com"
        return user_model.objects.create_user(
            email=email,
            password=self.password,
            role=role_value,
        )

    def get_dashboard_response(self, user):
        self.client.force_login(user)
        return self.client.get(reverse("payment_requests:dashboard"))

    def extract_navigation_html(self, response):
        content = response.content.decode("utf-8")
        match = re.search(
            r'<nav class="oftalmi-nav"[^>]*>[\s\S]*?</nav>',
            content,
        )
        self.assertIsNotNone(match, "No se encontro el bloque nav.oftalmi-nav.")
        return match.group(0)

    def test_navigation_visibility_matches_backend_permission_matrix_for_all_roles(self):
        for role in UserRole:
            with self.subTest(role=role.value):
                user = self.create_user(role)
                response = self.get_dashboard_response(user)

                if not user_has_permission(user, PERM_VIEW_PAYMENT_REQUEST_DASHBOARD):
                    self.assertIn(response.status_code, (403, 302))
                    continue

                self.assertEqual(response.status_code, 200)
                nav_html = self.extract_navigation_html(response)

                for label, route_name, permission in NAVIGATION_CASES:
                    expected_url = reverse(route_name)
                    has_permission = user_has_permission(user, permission)

                    if has_permission:
                        self.assertIn(label, nav_html)
                        self.assertIn(f'href="{expected_url}"', nav_html)
                    else:
                        self.assertNotIn(label, nav_html)
                        self.assertNotIn(f'href="{expected_url}"', nav_html)

    def test_backend_permissions_remain_authoritative_for_hidden_links(self):
        user = self.create_user(UserRole.SOLICITANTE)
        self.client.force_login(user)

        protected_urls = (
            reverse("payment_requests:accounts_payable"),
            reverse("payment_approvals:audit"),
        )

        for protected_url in protected_urls:
            with self.subTest(url=protected_url):
                response = self.client.get(protected_url)
                self.assertEqual(response.status_code, 403)

    def test_nav_matrix_routes_are_resolvable(self):
        for _label, route_name, _permission in NAVIGATION_CASES:
            with self.subTest(route_name=route_name):
                self.assertTrue(reverse(route_name).startswith("/"))
PY

cat > "$DOC_FILE" <<'MD'
# F2-P05 - Pruebas integradas de navegacion por rol / matriz UX-permisos

## Objetivo

Validar que la navegacion visible en `base.html` refleje la matriz de permisos backend para todos los roles definidos en `UserRole`.

## Alcance

- Probar la visibilidad integrada del menu por rol.
- Verificar que cada enlace visible tenga una ruta resoluble.
- Confirmar que ocultar enlaces no sustituye los controles backend.
- Documentar la matriz UX-permisos aplicada a navegacion.

## Criterio tecnico

La fuente de verdad sigue siendo la matriz de permisos backend expuesta mediante:

```python
apps.accounts.role_permissions.user_has_permission
```

La capa visual usa:

```python
role_nav
```

inyectado por:

```python
apps.accounts.context_processors.role_navigation
```

## Pruebas agregadas

Archivo:

```text
backend/apps/accounts/tests/test_role_navigation_integrated_matrix.py
```

Casos cubiertos:

1. La navegacion visible coincide con permisos backend para todos los roles.
2. Los enlaces ocultos siguen protegidos por permisos backend si se accede por URL directa.
3. Las rutas usadas por el menu son resolubles por Django.

## Fuera de alcance

- No se modifican modelos.
- No se crean migraciones.
- No se cambian permisos backend.
- No se cambian reglas funcionales de aprobacion, pagos o auditoria.
MD

cat > "$MATRIX_DOC" <<'MD'
# Matriz UX-permisos de navegacion - Fase 2

## Principio de control

La navegacion por rol es una capa UX. No reemplaza autorizacion backend.

## Mapeo menu-permiso-ruta

| Menu | Ruta Django | Permiso backend |
|---|---|---|
| Solicitudes | `payment_requests:dashboard` | `PERM_VIEW_PAYMENT_REQUEST_DASHBOARD` |
| Listado | `payment_requests:list` | `PERM_VIEW_PAYMENT_REQUESTS` |
| Nueva solicitud | `payment_requests:create` | `PERM_CREATE_PAYMENT_REQUEST` |
| Aprobaciones | `payment_approvals:pending` | `PERM_VIEW_PENDING_APPROVALS` |
| Cuentas por pagar | `payment_requests:accounts_payable` | `PERM_VIEW_ACCOUNTS_PAYABLE` |
| Auditoria | `payment_approvals:audit` | `PERM_VIEW_AUDIT_WORKBENCH` |

## Validacion automatizada

La prueba integrada recorre todos los valores de `UserRole` y compara:

```python
user_has_permission(user, permission)
```

contra el contenido real renderizado dentro de:

```html
<nav class="oftalmi-nav">
```

## Regla corporativa

Si un usuario no tiene permiso, el menu no debe exponer el enlace. Si manipula la URL manualmente, la vista debe mantener el bloqueo por permisos backend.
MD

echo "== Ruff focal =="
docker compose exec backend ruff check apps/accounts/tests/test_role_navigation_integrated_matrix.py

echo "== Tests focales F2-P04B/F2-P05 =="
docker compose exec backend python manage.py test \
  apps.accounts.tests.test_role_navigation_template \
  apps.accounts.tests.test_role_navigation_integrated_matrix

echo "== Validacion rapida global =="
docker compose exec backend ruff check .
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== Estado posterior =="
git status --short
