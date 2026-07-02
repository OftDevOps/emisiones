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
