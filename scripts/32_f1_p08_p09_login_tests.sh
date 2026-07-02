#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' '== F1-P08/F1-P09: Login basico y pruebas transversales =='

if [ ! -f "backend/manage.py" ]; then
  printf '%s\n' 'ERROR: ejecutar desde la raiz del repo: /home/dchirinos/oftalmiIA/emisiones/emisiones' >&2
  exit 1
fi

mkdir -p backend/templates/registration backend/templates/accounts backend/apps/accounts/tests docs/03-desarrollo scripts

touch backend/apps/accounts/tests/__init__.py

python3 - <<'PY'
from pathlib import Path
import re

base = Path("backend/config/settings/base.py")
if not base.exists():
    raise SystemExit("ERROR: backend/config/settings/base.py no existe")

s = base.read_text()

# Ensure backend/templates is in TEMPLATES DIRS.
if 'BASE_DIR / "templates"' not in s and "BASE_DIR / 'templates'" not in s:
    replacements = [
        ('"DIRS": [],', '"DIRS": [BASE_DIR / "templates"],'),
        ("'DIRS': [],", "'DIRS': [BASE_DIR / 'templates'],"),
    ]
    for old, new in replacements:
        if old in s:
            s = s.replace(old, new, 1)
            break
    else:
        # More tolerant replacement for multi-space JSON-like Django settings.
        pattern = r'([\"\']DIRS[\"\']\s*:\s*)\[\s*\]'
        s2, count = re.subn(pattern, r'\1[BASE_DIR / "templates"]', s, count=1)
        if count:
            s = s2
        else:
            raise SystemExit("ERROR: no se pudo localizar TEMPLATES['DIRS']; ajustar manualmente base.py")

# Ensure auth redirects are centralized.
append_lines = []
if "LOGIN_URL" not in s:
    append_lines.append('LOGIN_URL = "accounts:login"')
if "LOGIN_REDIRECT_URL" not in s:
    append_lines.append('LOGIN_REDIRECT_URL = "accounts:dashboard"')
if "LOGOUT_REDIRECT_URL" not in s:
    append_lines.append('LOGOUT_REDIRECT_URL = "accounts:login"')

if append_lines:
    s = s.rstrip() + "\n\n# Authentication flow - F1-P08\n" + "\n".join(append_lines) + "\n"

base.write_text(s)

urls = Path("backend/config/urls.py")
if not urls.exists():
    raise SystemExit("ERROR: backend/config/urls.py no existe")

u = urls.read_text()
if "include" not in u:
    u = u.replace("from django.urls import path", "from django.urls import include, path")

if 'include("apps.accounts.urls")' not in u and "include('apps.accounts.urls')" not in u:
    marker = "urlpatterns = ["
    if marker not in u:
        raise SystemExit("ERROR: no se encontro urlpatterns en backend/config/urls.py")
    u = u.replace(marker, marker + '\n    path("", include("apps.accounts.urls")),', 1)

urls.write_text(u)
PY

cat > backend/apps/accounts/views.py <<'PY'
from django.contrib.auth import logout
from django.contrib.auth.mixins import LoginRequiredMixin
from django.shortcuts import redirect
from django.views import View
from django.views.generic import TemplateView


class DashboardView(LoginRequiredMixin, TemplateView):
    """Vista inicial autenticada del Sistema de Rutas de Pago."""

    template_name = "accounts/dashboard.html"


class LogoutView(LoginRequiredMixin, View):
    """Cierre de sesion por POST para evitar logout accidental por enlace GET."""

    def post(self, request, *args, **kwargs):
        logout(request)
        return redirect("accounts:login")

    def get(self, request, *args, **kwargs):
        return redirect("accounts:dashboard")
PY

cat > backend/apps/accounts/urls.py <<'PY'
from django.contrib.auth.views import LoginView
from django.urls import path
from django.views.generic import RedirectView

from .views import DashboardView, LogoutView

app_name = "accounts"

urlpatterns = [
    path("", RedirectView.as_view(pattern_name="accounts:dashboard", permanent=False), name="home"),
    path(
        "login/",
        LoginView.as_view(
            template_name="registration/login.html",
            redirect_authenticated_user=True,
        ),
        name="login",
    ),
    path("logout/", LogoutView.as_view(), name="logout"),
    path("dashboard/", DashboardView.as_view(), name="dashboard"),
]
PY

cat > backend/templates/base.html <<'HTML'
<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{% block title %}Emisiones - Rutas de Pago Oftalmi{% endblock %}</title>
    <style>
        :root { font-family: Arial, Helvetica, sans-serif; color: #172033; background: #f4f6f8; }
        body { margin: 0; }
        header { background: #172033; color: white; padding: 16px 28px; display: flex; justify-content: space-between; align-items: center; }
        main { max-width: 980px; margin: 32px auto; padding: 0 20px; }
        .card { background: white; border: 1px solid #d9dee7; border-radius: 12px; padding: 24px; box-shadow: 0 8px 20px rgba(23, 32, 51, 0.06); }
        .muted { color: #667085; }
        label { display: block; margin-bottom: 6px; font-weight: 700; }
        input { width: 100%; padding: 10px; border: 1px solid #cfd6e4; border-radius: 8px; margin-bottom: 16px; box-sizing: border-box; }
        button, .button { background: #1f5eff; color: white; border: 0; border-radius: 8px; padding: 10px 16px; cursor: pointer; text-decoration: none; display: inline-block; }
        .button-secondary { background: #344054; }
        .errorlist { color: #b42318; }
        dl { display: grid; grid-template-columns: 220px 1fr; gap: 10px 18px; }
        dt { font-weight: 700; }
        dd { margin: 0; }
    </style>
</head>
<body>
<header>
    <strong>Emisiones | Rutas de Pago Oftalmi</strong>
    {% if request.user.is_authenticated %}
        <form method="post" action="{% url 'accounts:logout' %}">
            {% csrf_token %}
            <button class="button-secondary" type="submit">Cerrar sesión</button>
        </form>
    {% endif %}
</header>
<main>
    {% block content %}{% endblock %}
</main>
</body>
</html>
HTML

cat > backend/templates/registration/login.html <<'HTML'
{% extends "base.html" %}

{% block title %}Iniciar sesión | Emisiones{% endblock %}

{% block content %}
<section class="card">
    <h1>Iniciar sesión</h1>
    <p class="muted">Acceso al Sistema de Rutas de Pago Oftalmi.</p>

    {% if form.errors %}
        <p class="errorlist">Credenciales inválidas. Verifica el correo y la contraseña.</p>
    {% endif %}

    <form method="post" novalidate>
        {% csrf_token %}
        <label for="id_username">Correo electrónico</label>
        {{ form.username }}

        <label for="id_password">Contraseña</label>
        {{ form.password }}

        <button type="submit">Entrar</button>
    </form>
</section>
{% endblock %}
HTML

cat > backend/templates/accounts/dashboard.html <<'HTML'
{% extends "base.html" %}

{% block title %}Panel principal | Emisiones{% endblock %}

{% block content %}
<section class="card">
    <h1>Panel principal</h1>
    <p class="muted">Base autenticada del Sistema de Rutas de Pago Oftalmi.</p>

    <dl>
        <dt>Usuario</dt>
        <dd>{{ request.user.email }}</dd>

        <dt>Rol</dt>
        <dd>{{ request.user.get_role_display|default:request.user.role }}</dd>

        <dt>Empresa principal</dt>
        <dd>{{ request.user.primary_company|default:"No definida" }}</dd>

        <dt>Unidad organizativa</dt>
        <dd>{{ request.user.primary_organizational_unit|default:"No definida" }}</dd>
    </dl>
</section>
{% endblock %}
HTML

cat > backend/apps/accounts/tests/test_authentication_flow.py <<'PY'
from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import CustomUser, UserRole
from apps.organization.models import Company, OrganizationalUnit


class AuthenticationFlowTests(TestCase):
    def setUp(self):
        self.password = "Test-pass-12345"
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.unit = OrganizationalUnit.objects.create(
            company=self.company,
            name="Finanzas",
            code="FIN",
        )
        self.user = CustomUser.objects.create_user(
            email="usuario.login@oftalmi.com",
            password=self.password,
            role=UserRole.FINANZAS,
            primary_company=self.company,
            primary_organizational_unit=self.unit,
        )

    def test_login_page_is_public(self):
        response = self.client.get(reverse("accounts:login"))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Iniciar sesión")

    def test_dashboard_requires_authentication(self):
        dashboard_url = reverse("accounts:dashboard")
        login_url = reverse("accounts:login")

        response = self.client.get(dashboard_url)

        self.assertRedirects(response, f"{login_url}?next={dashboard_url}")

    def test_user_can_login_and_access_dashboard(self):
        response = self.client.post(
            reverse("accounts:login"),
            {"username": self.user.email, "password": self.password},
            follow=True,
        )

        self.assertRedirects(response, reverse("accounts:dashboard"))
        self.assertContains(response, "Panel principal")
        self.assertContains(response, self.user.email)
        self.assertContains(response, "Finanzas")

    def test_authenticated_user_redirected_away_from_login(self):
        self.client.force_login(self.user)

        response = self.client.get(reverse("accounts:login"))

        self.assertRedirects(response, reverse("accounts:dashboard"))

    def test_user_can_logout_by_post(self):
        self.client.force_login(self.user)

        response = self.client.post(reverse("accounts:logout"), follow=True)

        self.assertRedirects(response, reverse("accounts:login"))
        dashboard_response = self.client.get(reverse("accounts:dashboard"))
        self.assertEqual(dashboard_response.status_code, 302)

    def test_logout_get_does_not_end_session(self):
        self.client.force_login(self.user)

        response = self.client.get(reverse("accounts:logout"))

        self.assertRedirects(response, reverse("accounts:dashboard"))
        dashboard_response = self.client.get(reverse("accounts:dashboard"))
        self.assertEqual(dashboard_response.status_code, 200)
PY

cat > docs/03-desarrollo/f1_p08_p09_login_pruebas.md <<'MD'
# F1-P08/F1-P09 - Login básico y pruebas mínimas transversales

## Objetivo

Cerrar la base de autenticación web del Sistema de Rutas de Pago Oftalmi antes de iniciar beneficiarios, solicitudes de pago y rutas de aprobación.

## Alcance implementado

```text
F1-P08 Login básico — COMPLETADO
F1-P09 Pruebas mínimas transversales — COMPLETADO
```

## Componentes agregados

```text
backend/apps/accounts/urls.py
backend/apps/accounts/views.py
backend/templates/base.html
backend/templates/registration/login.html
backend/templates/accounts/dashboard.html
backend/apps/accounts/tests/test_authentication_flow.py
```

## Reglas técnicas

```text
AUTH-001 El login usa el CustomUser por correo electrónico.
AUTH-002 La vista dashboard exige autenticación.
AUTH-003 El usuario autenticado no debe volver al login; se redirige al dashboard.
AUTH-004 El logout se ejecuta por POST para evitar cierres accidentales por enlace GET.
AUTH-005 Las rutas base quedan centralizadas bajo accounts.urls.
```

## URLs base

```text
/login/       Login
/logout/      Logout por POST
/dashboard/   Panel autenticado
/             Redirección al dashboard
```

## Validación recomendada

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py test apps.organization apps.accounts
```

## Validación manual

Crear un superusuario si no existe:

```bash
docker compose exec backend python manage.py createsuperuser
```

Abrir:

```text
http://127.0.0.1:8001/login/
```

Si el acceso externo por host falla y el healthcheck interno funciona, desconectar NordVPN:

```bash
nordvpn disconnect
```

## Commit sugerido

```bash
git add .
git commit -m "feat: add basic login and authentication tests"
git push -u origin feature/basic-login-tests
```

Integración a develop:

```bash
git switch develop
git pull origin develop
git merge feature/basic-login-tests
git push origin develop
```
MD

cat > docs/03-desarrollo/continuidad_post_f1_p09.md <<'MD'
# Continuidad posterior a F1-P09

## Estado esperado

```text
F1-P01 Django base project — COMPLETADO
F1-P02 Settings por ambiente — COMPLETADO
F1-P03 Docker Compose backend + PostgreSQL funcional — COMPLETADO
F1-P04 App accounts con CustomUser por email — COMPLETADO
F1-P05 Roles base — COMPLETADO
F1-P06 App organization — COMPLETADO
F1-P07 Relación usuario / empresa / unidad — COMPLETADO
F1-P08 Login básico — COMPLETADO
F1-P09 Pruebas mínimas transversales — COMPLETADO
```

## Próximo bloque recomendado

```text
F1-P10 Beneficiarios / proveedores
F1-P11 Solicitudes de pago
```

## Criterio de avance

No avanzar a rutas de aprobación hasta tener solicitudes de pago con empresa, solicitante, proveedor, monto, concepto, estado inicial y trazabilidad mínima.
MD

printf '%s\n' 'OK: paquete F1-P08/F1-P09 generado.'
printf '%s\n' 'Ejecutar validaciones con docker compose antes de hacer commit.'
