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
