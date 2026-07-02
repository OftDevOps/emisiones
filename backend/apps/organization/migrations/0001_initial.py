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
