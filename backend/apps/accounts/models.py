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
