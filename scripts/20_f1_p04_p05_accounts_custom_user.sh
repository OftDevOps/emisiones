#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"
ACCOUNTS_DIR="$BACKEND_DIR/apps/accounts"
TESTS_DIR="$ACCOUNTS_DIR/tests"

if [ ! -f "$BACKEND_DIR/manage.py" ]; then
  echo "ERROR: Ejecuta este script desde la raiz del repo: /home/dchirinos/oftalmiIA/emisiones/emisiones"
  exit 1
fi

echo "=== F1-P04/P05: creando app accounts con CustomUser por email ==="

mkdir -p "$ACCOUNTS_DIR" "$TESTS_DIR"

touch "$BACKEND_DIR/apps/__init__.py"
touch "$ACCOUNTS_DIR/__init__.py"
touch "$TESTS_DIR/__init__.py"

cat > "$ACCOUNTS_DIR/apps.py" <<'PY'
from django.apps import AppConfig


class AccountsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.accounts"
    verbose_name = "Accounts"
PY

cat > "$ACCOUNTS_DIR/models.py" <<'PY'
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
from django.utils.translation import gettext_lazy as _


class UserRole(models.TextChoices):
    ADMINISTRADOR = "ADMINISTRADOR", _("Administrador")
    SOLICITANTE = "SOLICITANTE", _("Solicitante")
    RESPONSABLE_UNIDAD = "RESPONSABLE_UNIDAD", _("Responsable de unidad")
    FINANZAS = "FINANZAS", _("Finanzas")
    GERENCIA_GENERAL = "GERENCIA_GENERAL", _("Gerencia General")
    JUNTA_DIRECTIVA = "JUNTA_DIRECTIVA", _("Junta Directiva")
    CUENTAS_POR_PAGAR = "CUENTAS_POR_PAGAR", _("Cuentas por Pagar")
    AUDITOR = "AUDITOR", _("Auditor")


class CustomUserManager(BaseUserManager):
    use_in_migrations = True

    def normalize_email_required(self, email: str) -> str:
        if not email:
            raise ValueError("El correo electronico es obligatorio.")
        return self.normalize_email(email)

    def create_user(self, email, password=None, **extra_fields):
        email = self.normalize_email_required(email)
        extra_fields.setdefault("username", email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_active", True)
        extra_fields.setdefault("role", UserRole.ADMINISTRADOR)

        if extra_fields.get("is_staff") is not True:
            raise ValueError("El superusuario debe tener is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("El superusuario debe tener is_superuser=True.")

        return self.create_user(email, password, **extra_fields)


class CustomUser(AbstractUser):
    """Usuario base del sistema.

    Regla funcional:
    - El correo institucional es el identificador principal.
    - `username` se mantiene solo por compatibilidad interna de Django,
      pero se sincroniza con el email.
    """

    email = models.EmailField(_("email address"), unique=True)
    role = models.CharField(
        max_length=40,
        choices=UserRole.choices,
        default=UserRole.SOLICITANTE,
    )

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS: list[str] = []

    objects = CustomUserManager()

    class Meta:
        verbose_name = "Usuario"
        verbose_name_plural = "Usuarios"
        ordering = ["email"]

    def save(self, *args, **kwargs):
        if self.email:
            self.email = type(self).objects.normalize_email(self.email)
            self.username = self.email
        super().save(*args, **kwargs)

    def __str__(self):
        return self.email
PY

cat > "$ACCOUNTS_DIR/admin.py" <<'PY'
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.utils.translation import gettext_lazy as _

from .models import CustomUser


@admin.register(CustomUser)
class CustomUserAdmin(UserAdmin):
    model = CustomUser
    ordering = ("email",)
    list_display = ("email", "first_name", "last_name", "role", "is_active", "is_staff")
    list_filter = ("role", "is_active", "is_staff", "is_superuser", "groups")
    search_fields = ("email", "first_name", "last_name")

    fieldsets = (
        (None, {"fields": ("email", "password")}),
        (_("Informacion personal"), {"fields": ("first_name", "last_name")}),
        (_("Rol funcional"), {"fields": ("role",)}),
        (_("Permisos"), {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")}),
        (_("Fechas importantes"), {"fields": ("last_login", "date_joined")}),
    )

    add_fieldsets = (
        (None, {
            "classes": ("wide",),
            "fields": ("email", "role", "password1", "password2", "is_staff", "is_superuser", "is_active"),
        }),
    )
PY

cat > "$ACCOUNTS_DIR/tests/test_custom_user.py" <<'PY'
from django.contrib.auth import get_user_model
from django.test import TestCase

from apps.accounts.models import UserRole


class CustomUserModelTests(TestCase):
    def test_create_user_with_email(self):
        User = get_user_model()
        user = User.objects.create_user(
            email="solicitante@oftalmi.com",
            password="test-password-123",
        )

        self.assertEqual(user.email, "solicitante@oftalmi.com")
        self.assertEqual(user.username, "solicitante@oftalmi.com")
        self.assertEqual(user.role, UserRole.SOLICITANTE)
        self.assertTrue(user.check_password("test-password-123"))

    def test_email_is_required(self):
        User = get_user_model()
        with self.assertRaises(ValueError):
            User.objects.create_user(email="", password="test-password-123")

    def test_email_is_unique(self):
        User = get_user_model()
        User.objects.create_user(email="finanzas@oftalmi.com", password="test-password-123")

        with self.assertRaises(Exception):
            User.objects.create_user(email="finanzas@oftalmi.com", password="test-password-456")

    def test_create_superuser(self):
        User = get_user_model()
        user = User.objects.create_superuser(
            email="admin@oftalmi.com",
            password="admin-password-123",
        )

        self.assertTrue(user.is_staff)
        self.assertTrue(user.is_superuser)
        self.assertEqual(user.role, UserRole.ADMINISTRADOR)
PY

# Ensure settings contain accounts app and custom user model.
BASE_SETTINGS="$BACKEND_DIR/config/settings/base.py"
if ! grep -q 'apps.accounts' "$BASE_SETTINGS"; then
  python3 - <<'PY'
from pathlib import Path
path = Path('backend/config/settings/base.py')
text = path.read_text()
needle = 'INSTALLED_APPS = ['
if needle not in text:
    raise SystemExit('No se encontro INSTALLED_APPS en backend/config/settings/base.py')
text = text.replace(needle, 'INSTALLED_APPS = [\n    "apps.accounts",', 1)
path.write_text(text)
PY
fi

if ! grep -q '^AUTH_USER_MODEL' "$BASE_SETTINGS"; then
  cat >> "$BASE_SETTINGS" <<'PY'

# Custom user model
AUTH_USER_MODEL = "accounts.CustomUser"
PY
fi

# Create migrations locally if Python/Django is available in host; otherwise via Docker later.
mkdir -p "$ACCOUNTS_DIR/migrations"
touch "$ACCOUNTS_DIR/migrations/__init__.py"

cat > "$ACCOUNTS_DIR/migrations/0001_initial.py" <<'PY'
# Generated manually for F1-P04/P05.

import django.contrib.auth.models
import django.contrib.auth.validators
import django.utils.timezone
from django.db import migrations, models

import apps.accounts.models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ("auth", "0012_alter_user_first_name_max_length"),
    ]

    operations = [
        migrations.CreateModel(
            name="CustomUser",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("password", models.CharField(max_length=128, verbose_name="password")),
                ("last_login", models.DateTimeField(blank=True, null=True, verbose_name="last login")),
                ("is_superuser", models.BooleanField(default=False, help_text="Designates that this user has all permissions without explicitly assigning them.", verbose_name="superuser status")),
                ("username", models.CharField(error_messages={"unique": "A user with that username already exists."}, help_text="Required. 150 characters or fewer. Letters, digits and @/./+/-/_ only.", max_length=150, unique=True, validators=[django.contrib.auth.validators.UnicodeUsernameValidator()], verbose_name="username")),
                ("first_name", models.CharField(blank=True, max_length=150, verbose_name="first name")),
                ("last_name", models.CharField(blank=True, max_length=150, verbose_name="last name")),
                ("is_staff", models.BooleanField(default=False, help_text="Designates whether the user can log into this admin site.", verbose_name="staff status")),
                ("is_active", models.BooleanField(default=True, help_text="Designates whether this user should be treated as active. Unselect this instead of deleting accounts.", verbose_name="active")),
                ("date_joined", models.DateTimeField(default=django.utils.timezone.now, verbose_name="date joined")),
                ("email", models.EmailField(max_length=254, unique=True, verbose_name="email address")),
                ("role", models.CharField(choices=[("ADMINISTRADOR", "Administrador"), ("SOLICITANTE", "Solicitante"), ("RESPONSABLE_UNIDAD", "Responsable de unidad"), ("FINANZAS", "Finanzas"), ("GERENCIA_GENERAL", "Gerencia General"), ("JUNTA_DIRECTIVA", "Junta Directiva"), ("CUENTAS_POR_PAGAR", "Cuentas por Pagar"), ("AUDITOR", "Auditor")], default="SOLICITANTE", max_length=40)),
                ("groups", models.ManyToManyField(blank=True, help_text="The groups this user belongs to. A user will get all permissions granted to each of their groups.", related_name="user_set", related_query_name="user", to="auth.group", verbose_name="groups")),
                ("user_permissions", models.ManyToManyField(blank=True, help_text="Specific permissions for this user.", related_name="user_set", related_query_name="user", to="auth.permission", verbose_name="user permissions")),
            ],
            options={
                "verbose_name": "Usuario",
                "verbose_name_plural": "Usuarios",
                "ordering": ["email"],
            },
            managers=[
                ("objects", apps.accounts.models.CustomUserManager()),
            ],
        ),
    ]
PY

cat > "$BACKEND_DIR/apps/accounts/README.md" <<'MD'
# Accounts

App responsable de la identidad interna del Sistema de Rutas de Pago Oftalmi.

## Decisiones

- El correo electronico es el identificador principal del usuario.
- `username` se mantiene sincronizado con `email` solo por compatibilidad interna con Django.
- Los roles base del MVP se definen en `UserRole`.
- La autenticacion queda preparada para futura integracion con Microsoft Entra ID.

## Roles base MVP

- ADMINISTRADOR
- SOLICITANTE
- RESPONSABLE_UNIDAD
- FINANZAS
- GERENCIA_GENERAL
- JUNTA_DIRECTIVA
- CUENTAS_POR_PAGAR
- AUDITOR
MD

echo "=== F1-P04/P05 completado: archivos accounts generados ==="
echo "Siguiente: docker compose exec backend python manage.py check && migrate && test apps.accounts"
