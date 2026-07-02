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
