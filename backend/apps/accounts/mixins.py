"""Reusable access-control mixins for class-based views."""

from __future__ import annotations

from django.core.exceptions import PermissionDenied

from .role_permissions import user_has_permission


class OperationalPermissionRequiredMixin:
    """Require one centralized operational permission before dispatching a view."""

    required_operational_permission: str | None = None
    permission_denied_message = "Su rol no permite acceder a esta funcionalidad."

    def get_required_operational_permission(self) -> str:
        if not self.required_operational_permission:
            raise ImproperlyConfiguredOperationalPermission(
                f"{self.__class__.__name__} debe definir required_operational_permission."
            )
        return self.required_operational_permission

    def dispatch(self, request, *args, **kwargs):
        permission = self.get_required_operational_permission()
        if not user_has_permission(request.user, permission):
            raise PermissionDenied(self.permission_denied_message)
        return super().dispatch(request, *args, **kwargs)


class ImproperlyConfiguredOperationalPermission(RuntimeError):
    """Raised when a view declares the mixin without a permission key."""
