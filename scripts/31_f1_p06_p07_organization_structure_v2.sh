#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' '== F1-P06/F1-P07 v2: Organization structure =='

if [ ! -f "backend/manage.py" ]; then
  printf '%s\n' 'ERROR: run this script from repository root: /home/dchirinos/oftalmiIA/emisiones/emisiones' >&2
  exit 1
fi

mkdir -p backend/apps/organization/migrations backend/apps/organization/tests docs/05-modelo-datos

touch backend/apps/organization/__init__.py

touch backend/apps/organization/migrations/__init__.py

touch backend/apps/organization/tests/__init__.py

cat > backend/apps/organization/apps.py <<'PY'
from django.apps import AppConfig


class OrganizationConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.organization"
    label = "organization"
    verbose_name = "Organización"
PY

cat > backend/apps/organization/models.py <<'PY'
from django.db import models


class ActiveModel(models.Model):
    is_active = models.BooleanField(default=True, verbose_name="activo")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="creado")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="actualizado")

    class Meta:
        abstract = True


class Company(ActiveModel):
    name = models.CharField(max_length=180, unique=True, verbose_name="nombre")
    rif = models.CharField(max_length=30, blank=True, verbose_name="RIF")
    code = models.CharField(max_length=30, unique=True, verbose_name="código")

    class Meta:
        ordering = ["name"]
        verbose_name = "empresa"
        verbose_name_plural = "empresas"

    def __str__(self) -> str:
        return self.name


class Management(ActiveModel):
    company = models.ForeignKey(
        Company,
        on_delete=models.PROTECT,
        related_name="managements",
        verbose_name="empresa",
    )
    name = models.CharField(max_length=180, verbose_name="nombre")
    code = models.CharField(max_length=30, verbose_name="código")

    class Meta:
        ordering = ["company__name", "name"]
        unique_together = [("company", "code"), ("company", "name")]
        verbose_name = "gerencia"
        verbose_name_plural = "gerencias"

    def __str__(self) -> str:
        return f"{self.company} - {self.name}"


class Area(ActiveModel):
    company = models.ForeignKey(
        Company,
        on_delete=models.PROTECT,
        related_name="areas",
        verbose_name="empresa",
    )
    management = models.ForeignKey(
        Management,
        on_delete=models.PROTECT,
        related_name="areas",
        null=True,
        blank=True,
        verbose_name="gerencia",
    )
    name = models.CharField(max_length=180, verbose_name="nombre")
    code = models.CharField(max_length=30, verbose_name="código")

    class Meta:
        ordering = ["company__name", "name"]
        unique_together = [("company", "code"), ("company", "name")]
        verbose_name = "área"
        verbose_name_plural = "áreas"

    def __str__(self) -> str:
        return f"{self.company} - {self.name}"


class Department(ActiveModel):
    company = models.ForeignKey(
        Company,
        on_delete=models.PROTECT,
        related_name="departments",
        verbose_name="empresa",
    )
    area = models.ForeignKey(
        Area,
        on_delete=models.PROTECT,
        related_name="departments",
        null=True,
        blank=True,
        verbose_name="área",
    )
    name = models.CharField(max_length=180, verbose_name="nombre")
    code = models.CharField(max_length=30, verbose_name="código")

    class Meta:
        ordering = ["company__name", "name"]
        unique_together = [("company", "code"), ("company", "name")]
        verbose_name = "departamento"
        verbose_name_plural = "departamentos"

    def __str__(self) -> str:
        return f"{self.company} - {self.name}"


class OrganizationalUnit(ActiveModel):
    company = models.ForeignKey(
        Company,
        on_delete=models.PROTECT,
        related_name="organizational_units",
        verbose_name="empresa",
    )
    management = models.ForeignKey(
        Management,
        on_delete=models.PROTECT,
        related_name="organizational_units",
        null=True,
        blank=True,
        verbose_name="gerencia",
    )
    area = models.ForeignKey(
        Area,
        on_delete=models.PROTECT,
        related_name="organizational_units",
        null=True,
        blank=True,
        verbose_name="área",
    )
    department = models.ForeignKey(
        Department,
        on_delete=models.PROTECT,
        related_name="organizational_units",
        null=True,
        blank=True,
        verbose_name="departamento",
    )
    name = models.CharField(max_length=180, verbose_name="nombre")
    code = models.CharField(max_length=30, verbose_name="código")

    class Meta:
        ordering = ["company__name", "name"]
        unique_together = [("company", "code"), ("company", "name")]
        verbose_name = "unidad organizativa"
        verbose_name_plural = "unidades organizativas"

    def __str__(self) -> str:
        return f"{self.company} - {self.name}"
PY

cat > backend/apps/organization/admin.py <<'PY'
from django.contrib import admin

from .models import Area, Company, Department, Management, OrganizationalUnit


@admin.register(Company)
class CompanyAdmin(admin.ModelAdmin):
    list_display = ("name", "rif", "code", "is_active")
    search_fields = ("name", "rif", "code")
    list_filter = ("is_active",)


@admin.register(Management)
class ManagementAdmin(admin.ModelAdmin):
    list_display = ("name", "code", "company", "is_active")
    search_fields = ("name", "code", "company__name")
    list_filter = ("company", "is_active")


@admin.register(Area)
class AreaAdmin(admin.ModelAdmin):
    list_display = ("name", "code", "company", "management", "is_active")
    search_fields = ("name", "code", "company__name", "management__name")
    list_filter = ("company", "management", "is_active")


@admin.register(Department)
class DepartmentAdmin(admin.ModelAdmin):
    list_display = ("name", "code", "company", "area", "is_active")
    search_fields = ("name", "code", "company__name", "area__name")
    list_filter = ("company", "area", "is_active")


@admin.register(OrganizationalUnit)
class OrganizationalUnitAdmin(admin.ModelAdmin):
    list_display = ("name", "code", "company", "management", "area", "department", "is_active")
    search_fields = ("name", "code", "company__name", "department__name")
    list_filter = ("company", "management", "area", "department", "is_active")
PY

cat > backend/apps/organization/migrations/0001_initial.py <<'PY'
# Generated for F1-P06/F1-P07
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="Company",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("is_active", models.BooleanField(default=True, verbose_name="activo")),
                ("created_at", models.DateTimeField(auto_now_add=True, verbose_name="creado")),
                ("updated_at", models.DateTimeField(auto_now=True, verbose_name="actualizado")),
                ("name", models.CharField(max_length=180, unique=True, verbose_name="nombre")),
                ("rif", models.CharField(blank=True, max_length=30, verbose_name="RIF")),
                ("code", models.CharField(max_length=30, unique=True, verbose_name="código")),
            ],
            options={"verbose_name": "empresa", "verbose_name_plural": "empresas", "ordering": ["name"]},
        ),
        migrations.CreateModel(
            name="Management",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("is_active", models.BooleanField(default=True, verbose_name="activo")),
                ("created_at", models.DateTimeField(auto_now_add=True, verbose_name="creado")),
                ("updated_at", models.DateTimeField(auto_now=True, verbose_name="actualizado")),
                ("name", models.CharField(max_length=180, verbose_name="nombre")),
                ("code", models.CharField(max_length=30, verbose_name="código")),
                ("company", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="managements", to="organization.company", verbose_name="empresa")),
            ],
            options={"verbose_name": "gerencia", "verbose_name_plural": "gerencias", "ordering": ["company__name", "name"], "unique_together": {("company", "code"), ("company", "name")}},
        ),
        migrations.CreateModel(
            name="Area",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("is_active", models.BooleanField(default=True, verbose_name="activo")),
                ("created_at", models.DateTimeField(auto_now_add=True, verbose_name="creado")),
                ("updated_at", models.DateTimeField(auto_now=True, verbose_name="actualizado")),
                ("name", models.CharField(max_length=180, verbose_name="nombre")),
                ("code", models.CharField(max_length=30, verbose_name="código")),
                ("company", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="areas", to="organization.company", verbose_name="empresa")),
                ("management", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, related_name="areas", to="organization.management", verbose_name="gerencia")),
            ],
            options={"verbose_name": "área", "verbose_name_plural": "áreas", "ordering": ["company__name", "name"], "unique_together": {("company", "code"), ("company", "name")}},
        ),
        migrations.CreateModel(
            name="Department",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("is_active", models.BooleanField(default=True, verbose_name="activo")),
                ("created_at", models.DateTimeField(auto_now_add=True, verbose_name="creado")),
                ("updated_at", models.DateTimeField(auto_now=True, verbose_name="actualizado")),
                ("name", models.CharField(max_length=180, verbose_name="nombre")),
                ("code", models.CharField(max_length=30, verbose_name="código")),
                ("area", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, related_name="departments", to="organization.area", verbose_name="área")),
                ("company", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="departments", to="organization.company", verbose_name="empresa")),
            ],
            options={"verbose_name": "departamento", "verbose_name_plural": "departamentos", "ordering": ["company__name", "name"], "unique_together": {("company", "code"), ("company", "name")}},
        ),
        migrations.CreateModel(
            name="OrganizationalUnit",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("is_active", models.BooleanField(default=True, verbose_name="activo")),
                ("created_at", models.DateTimeField(auto_now_add=True, verbose_name="creado")),
                ("updated_at", models.DateTimeField(auto_now=True, verbose_name="actualizado")),
                ("name", models.CharField(max_length=180, verbose_name="nombre")),
                ("code", models.CharField(max_length=30, verbose_name="código")),
                ("area", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, related_name="organizational_units", to="organization.area", verbose_name="área")),
                ("company", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="organizational_units", to="organization.company", verbose_name="empresa")),
                ("department", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, related_name="organizational_units", to="organization.department", verbose_name="departamento")),
                ("management", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, related_name="organizational_units", to="organization.management", verbose_name="gerencia")),
            ],
            options={"verbose_name": "unidad organizativa", "verbose_name_plural": "unidades organizativas", "ordering": ["company__name", "name"], "unique_together": {("company", "code"), ("company", "name")}},
        ),
    ]
PY

# Ensure organization app is installed.
python3 - <<'PY'
from pathlib import Path
p = Path('backend/config/settings/base.py')
s = p.read_text()
if '"apps.organization"' not in s and "'apps.organization'" not in s:
    marker = '"apps.accounts",'
    if marker in s:
        s = s.replace(marker, '"apps.organization",\n    "apps.accounts",')
    else:
        marker = "'apps.accounts',"
        if marker in s:
            s = s.replace(marker, "'apps.organization',\n    'apps.accounts',")
        else:
            raise SystemExit('ERROR: apps.accounts not found in INSTALLED_APPS')
p.write_text(s)
PY

# Rewrite accounts model with organization fields in a controlled way.
cat > backend/apps/accounts/models.py <<'PY'
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

    def _create_user(self, email, password, **extra_fields):
        if not email:
            raise ValueError("El correo electrónico es obligatorio")
        email = self.normalize_email(email)
        user = self.model(email=email, username=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)
        return self._create_user(email, password, **extra_fields)

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("role", UserRole.ADMINISTRADOR)

        if extra_fields.get("is_staff") is not True:
            raise ValueError("El superusuario debe tener is_staff=True")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("El superusuario debe tener is_superuser=True")

        return self._create_user(email, password, **extra_fields)


class CustomUser(AbstractUser):
    username = models.CharField(max_length=150, unique=True, blank=True)
    email = models.EmailField(unique=True, verbose_name="correo electrónico")
    role = models.CharField(
        max_length=40,
        choices=UserRole.choices,
        default=UserRole.SOLICITANTE,
        verbose_name="rol",
    )
    primary_company = models.ForeignKey(
        "organization.Company",
        on_delete=models.PROTECT,
        related_name="users",
        null=True,
        blank=True,
        verbose_name="empresa principal",
    )
    primary_organizational_unit = models.ForeignKey(
        "organization.OrganizationalUnit",
        on_delete=models.PROTECT,
        related_name="users",
        null=True,
        blank=True,
        verbose_name="unidad organizativa principal",
    )
    department = models.ForeignKey(
        "organization.Department",
        on_delete=models.PROTECT,
        related_name="users",
        null=True,
        blank=True,
        verbose_name="departamento",
    )
    area = models.ForeignKey(
        "organization.Area",
        on_delete=models.PROTECT,
        related_name="users",
        null=True,
        blank=True,
        verbose_name="área",
    )
    management = models.ForeignKey(
        "organization.Management",
        on_delete=models.PROTECT,
        related_name="users",
        null=True,
        blank=True,
        verbose_name="gerencia",
    )

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []

    objects = CustomUserManager()

    class Meta:
        verbose_name = "usuario"
        verbose_name_plural = "usuarios"

    def save(self, *args, **kwargs):
        if self.email:
            self.email = self.__class__.objects.normalize_email(self.email)
            self.username = self.email
        super().save(*args, **kwargs)

    def __str__(self) -> str:
        return self.email
PY

cat > backend/apps/accounts/migrations/0002_user_organization_fields.py <<'PY'
# Generated for F1-P06/F1-P07
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ("organization", "0001_initial"),
        ("accounts", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="customuser",
            name="area",
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, related_name="users", to="organization.area", verbose_name="área"),
        ),
        migrations.AddField(
            model_name="customuser",
            name="department",
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, related_name="users", to="organization.department", verbose_name="departamento"),
        ),
        migrations.AddField(
            model_name="customuser",
            name="management",
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, related_name="users", to="organization.management", verbose_name="gerencia"),
        ),
        migrations.AddField(
            model_name="customuser",
            name="primary_company",
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, related_name="users", to="organization.company", verbose_name="empresa principal"),
        ),
        migrations.AddField(
            model_name="customuser",
            name="primary_organizational_unit",
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, related_name="users", to="organization.organizationalunit", verbose_name="unidad organizativa principal"),
        ),
    ]
PY

cat > backend/apps/organization/tests/test_models.py <<'PY'
from django.test import TestCase

from apps.accounts.models import CustomUser, UserRole
from apps.organization.models import Area, Company, Department, Management, OrganizationalUnit


class OrganizationModelsTests(TestCase):
    def test_create_company(self):
        company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT", rif="J-00000000-0")
        self.assertEqual(str(company), "Laboratorios Oftalmi")
        self.assertTrue(company.is_active)

    def test_create_full_structure(self):
        company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        management = Management.objects.create(company=company, name="Gerencia General", code="GG")
        area = Area.objects.create(company=company, management=management, name="Administración", code="ADM")
        department = Department.objects.create(company=company, area=area, name="Cuentas por Pagar", code="CXP")
        unit = OrganizationalUnit.objects.create(
            company=company,
            management=management,
            area=area,
            department=department,
            name="Unidad de Pagos",
            code="UPG",
        )

        self.assertEqual(unit.company, company)
        self.assertEqual(unit.management, management)
        self.assertEqual(unit.area, area)
        self.assertEqual(unit.department, department)

    def test_assign_user_to_organization(self):
        company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        unit = OrganizationalUnit.objects.create(company=company, name="Finanzas", code="FIN")
        user = CustomUser.objects.create_user(
            email="finanzas@oftalmi.com",
            password="test-pass-123",
            role=UserRole.FINANZAS,
            primary_company=company,
            primary_organizational_unit=unit,
        )

        self.assertEqual(user.primary_company, company)
        self.assertEqual(user.primary_organizational_unit, unit)
        self.assertEqual(user.role, UserRole.FINANZAS)
PY

cat > docs/05-modelo-datos/estructura_organizativa.md <<'MD'
# Estructura organizativa - Fase 1

## Objetivo

Definir la base organizativa necesaria para que el Sistema de Rutas de Pago Oftalmi pueda controlar solicitudes por empresa, unidad, departamento, área y gerencia.

## Modelos

```text
Company
Management
Area
Department
OrganizationalUnit
```

## Relación con usuarios

El usuario queda relacionado con:

```text
primary_company
primary_organizational_unit
department
area
management
```

## Reglas

```text
ORG-001 Toda solicitud futura deberá estar asociada a una empresa.
ORG-002 Todo usuario solicitante deberá tener alcance organizativo definido.
ORG-003 La unidad organizativa será usada para filtrar solicitudes visibles por rol y responsabilidad.
ORG-004 Las relaciones organizativas deberán protegerse contra eliminación física si existen usuarios o solicitudes asociadas.
```

## Puntos completados

```text
F1-P06 App organization — COMPLETADO
F1-P07 Relación usuario / empresa / unidad — COMPLETADO
```
MD

printf '%s\n' 'OK: F1-P06/F1-P07 v2 files generated.'
printf '%s\n' 'Next: docker compose down -v && docker compose up --build, then run checks/migrations/tests.'
