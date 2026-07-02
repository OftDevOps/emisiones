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
