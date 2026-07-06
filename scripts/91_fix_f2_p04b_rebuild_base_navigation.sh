#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_ROOT"

echo "== Fix F2-P04B: reconstruir navegacion real por rol en base.html =="

BASE_TEMPLATE="backend/templates/base.html"
TEST_FILE="backend/apps/accounts/tests/test_role_navigation_template.py"
DOC_FILE="docs/f2_p04b_visibilidad_real_menu_base.md"
MATRIX_DOC="docs/matriz_visibilidad_menu_base_fase2.md"

if [ ! -f "$BASE_TEMPLATE" ]; then
  echo "ERROR: no existe $BASE_TEMPLATE"
  exit 1
fi

if [ ! -f "backend/apps/accounts/context_processors.py" ]; then
  echo "ERROR: falta backend/apps/accounts/context_processors.py"
  exit 1
fi

echo "== Validando contrato del context processor =="
grep -q 'return {"role_nav": nav_permissions}' backend/apps/accounts/context_processors.py

echo "== Backup de base.html =="
cp "$BASE_TEMPLATE" "${BASE_TEMPLATE}.bak_f2_p04b_91"

python3 - <<'PY'
from pathlib import Path

path = Path("backend/templates/base.html")
text = path.read_text(encoding="utf-8")

old = """    {% if request.user.is_authenticated %}
        <form method="post" action="{% url 'accounts:logout' %}">
            {% csrf_token %}
            <button class="button-secondary" type="submit">Cerrar sesión</button>
        </form>
    {% endif %}
</header>
<main>
    {% block content %}{% endblock %}
</main>
<p><a href="{% url 'payment_requests:list' %}">Solicitudes de pago</a></p>
</body>
</html>
"""

new = """    {% if request.user.is_authenticated %}
        <form method="post" action="{% url 'accounts:logout' %}">
            {% csrf_token %}
            <button class="button-secondary" type="submit">Cerrar sesión</button>
        </form>
    {% endif %}
</header>

{% if request.user.is_authenticated %}
<nav class="oftalmi-nav" aria-label="Navegación principal">
    {% if role_nav.can_view_payment_dashboard %}
        <a class="nav-link" href="{% url 'payment_requests:dashboard' %}">Solicitudes</a>
    {% endif %}
    {% if role_nav.can_view_payment_requests %}
        <a class="nav-link" href="{% url 'payment_requests:list' %}">Listado</a>
    {% endif %}
    {% if role_nav.can_create_payment_request %}
        <a class="nav-link" href="{% url 'payment_requests:create' %}">Nueva solicitud</a>
    {% endif %}
    {% if role_nav.can_view_pending_approvals %}
        <a class="nav-link" href="{% url 'payment_approvals:pending' %}">Aprobaciones</a>
    {% endif %}
    {% if role_nav.can_view_accounts_payable %}
        <a class="nav-link" href="{% url 'payment_requests:accounts_payable' %}">Cuentas por pagar</a>
    {% endif %}
    {% if role_nav.can_view_audit_workbench %}
        <a class="nav-link" href="{% url 'payment_approvals:audit' %}">Auditoria</a>
    {% endif %}
</nav>
{% endif %}

<main>
    {% block content %}{% endblock %}
</main>
</body>
</html>
"""

if old not in text:
    raise SystemExit("ERROR: no se encontro el bloque esperado en base.html; revisar manualmente antes de continuar.")

text = text.replace(old, new)
path.write_text(text, encoding="utf-8")
PY

cat > "$TEST_FILE" <<'PY'
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import UserRole


class RoleBasedNavigationTemplateTests(TestCase):
    password = "Demo123456*"

    def create_user(self, email, role):
        user_model = get_user_model()
        return user_model.objects.create_user(
            email=email,
            password=self.password,
            role=role,
        )

    def test_solicitante_does_not_see_accounts_payable_or_audit_links(self):
        user = self.create_user("solicitante.nav@oftalmi.com", UserRole.SOLICITANTE)
        self.client.force_login(user)

        response = self.client.get(reverse("dashboard"))

        self.assertEqual(response.status_code, 200)
        content = response.content.decode("utf-8")
        self.assertIn("Solicitudes", content)
        self.assertNotIn("Cuentas por pagar", content)
        self.assertNotIn("Auditoria", content)

    def test_cuentas_por_pagar_sees_accounts_payable_link(self):
        user = self.create_user("cxp.nav@oftalmi.com", UserRole.CUENTAS_POR_PAGAR)
        self.client.force_login(user)

        response = self.client.get(reverse("dashboard"))

        self.assertEqual(response.status_code, 200)
        content = response.content.decode("utf-8")
        self.assertIn("Cuentas por pagar", content)

    def test_auditor_sees_audit_link(self):
        user = self.create_user("auditor.nav@oftalmi.com", UserRole.AUDITOR)
        self.client.force_login(user)

        response = self.client.get(reverse("dashboard"))

        self.assertEqual(response.status_code, 200)
        content = response.content.decode("utf-8")
        self.assertIn("Auditoria", content)
PY

cat > "$DOC_FILE" <<'MD'
# F2-P04B - Visibilidad real de menu por rol en base.html

## Objetivo

Aplicar visibilidad real de navegacion por rol en `backend/templates/base.html`, usando el context processor creado en F2-P04.

## Implementacion

La plantilla base usa el objeto:

```python
role_nav
```

Este objeto es inyectado por:

```python
apps.accounts.context_processors.role_navigation
```

## Alcance

- Mostrar u ocultar enlaces del menu segun permisos efectivos por rol.
- Mantener los permisos backend como fuente real de seguridad.
- Reducir exposicion visual de opciones que terminan en `403`.
- Agregar pruebas de renderizado de menu por rol.

## Enlaces condicionados

- Solicitudes
- Listado
- Nueva solicitud
- Aprobaciones
- Cuentas por pagar
- Auditoria

## Criterio de seguridad

La visibilidad del menu es UX. No sustituye controles backend.

Si un usuario manipula manualmente una URL protegida, la vista debe seguir devolviendo `403` cuando no tenga permiso.
MD

cat > "$MATRIX_DOC" <<'MD'
# Matriz de visibilidad de menu - Fase 2

## Fuente

La visibilidad depende de `role_nav`, inyectado por:

```python
apps.accounts.context_processors.role_navigation
```

## Variables usadas

| Variable | Enlace |
|---|---|
| `role_nav.can_view_payment_dashboard` | Solicitudes |
| `role_nav.can_view_payment_requests` | Listado |
| `role_nav.can_create_payment_request` | Nueva solicitud |
| `role_nav.can_view_pending_approvals` | Aprobaciones |
| `role_nav.can_view_accounts_payable` | Cuentas por pagar |
| `role_nav.can_view_audit_workbench` | Auditoria |

## Regla corporativa

El menu solo refleja accesos permitidos. La autorizacion real sigue estando en las vistas Django y en la matriz de permisos backend.
MD

echo "== Ruff focal =="
docker compose exec backend ruff check backend/apps/accounts/tests/test_role_navigation_template.py

echo "== Test focal F2-P04B =="
docker compose exec backend python manage.py test apps.accounts.tests.test_role_navigation_template

echo "== Estado posterior =="
git status --short
