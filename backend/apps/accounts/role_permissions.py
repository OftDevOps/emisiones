"""Role-based access policy for Apps Emisiones.

This module centralizes the operational access matrix used by critical views.
It intentionally avoids database changes and Django permission rows at this stage.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable


class RolePermissionError(ValueError):
    """Raised when an unknown permission key is requested."""


ROLE_ADMINISTRADOR = "ADMINISTRADOR"
ROLE_SOLICITANTE = "SOLICITANTE"
ROLE_RESPONSABLE_UNIDAD = "RESPONSABLE_UNIDAD"
ROLE_FINANZAS = "FINANZAS"
ROLE_CUENTAS_POR_PAGAR = "CUENTAS_POR_PAGAR"
ROLE_AUDITOR = "AUDITOR"

PERM_VIEW_PAYMENT_REQUEST_DASHBOARD = "payment_requests.view_dashboard"
PERM_VIEW_PAYMENT_REQUESTS = "payment_requests.view_list"
PERM_CREATE_PAYMENT_REQUEST = "payment_requests.create"
PERM_SUBMIT_PAYMENT_REQUEST = "payment_requests.submit"
PERM_VIEW_PENDING_APPROVALS = "payment_approvals.view_pending"
PERM_EXECUTE_APPROVAL_ACTION = "payment_approvals.execute_action"
PERM_VIEW_AUDIT_WORKBENCH = "payment_approvals.view_audit"
PERM_VIEW_ACCOUNTS_PAYABLE = "payment_requests.view_accounts_payable"
PERM_REGISTER_PAYMENT_EXECUTION = "payment_execution.register_payment"

ALL_ROLES = {
    ROLE_ADMINISTRADOR,
    ROLE_SOLICITANTE,
    ROLE_RESPONSABLE_UNIDAD,
    ROLE_FINANZAS,
    ROLE_CUENTAS_POR_PAGAR,
    ROLE_AUDITOR,
}

PERMISSION_MATRIX: dict[str, set[str]] = {
    PERM_VIEW_PAYMENT_REQUEST_DASHBOARD: ALL_ROLES,
    PERM_VIEW_PAYMENT_REQUESTS: ALL_ROLES,
    PERM_CREATE_PAYMENT_REQUEST: {
        ROLE_ADMINISTRADOR,
        ROLE_SOLICITANTE,
        ROLE_RESPONSABLE_UNIDAD,
        ROLE_FINANZAS,
    },
    PERM_SUBMIT_PAYMENT_REQUEST: {
        ROLE_ADMINISTRADOR,
        ROLE_SOLICITANTE,
        ROLE_RESPONSABLE_UNIDAD,
        ROLE_FINANZAS,
    },
    PERM_VIEW_PENDING_APPROVALS: {
        ROLE_ADMINISTRADOR,
        ROLE_RESPONSABLE_UNIDAD,
        ROLE_FINANZAS,
    },
    PERM_EXECUTE_APPROVAL_ACTION: {
        ROLE_ADMINISTRADOR,
        ROLE_RESPONSABLE_UNIDAD,
        ROLE_FINANZAS,
    },
    PERM_VIEW_AUDIT_WORKBENCH: {
        ROLE_ADMINISTRADOR,
        ROLE_AUDITOR,
    },
    PERM_VIEW_ACCOUNTS_PAYABLE: {
        ROLE_ADMINISTRADOR,
        ROLE_CUENTAS_POR_PAGAR,
        ROLE_FINANZAS,
    },
    PERM_REGISTER_PAYMENT_EXECUTION: {
        ROLE_ADMINISTRADOR,
        ROLE_CUENTAS_POR_PAGAR,
    },
}


@dataclass(frozen=True)
class RolePermissionDecision:
    """Small immutable decision object useful for tests and diagnostics."""

    allowed: bool
    role: str | None
    permission: str


def normalize_role(role: str | None) -> str | None:
    if role is None:
        return None
    value = str(role).strip().upper()
    return value or None


def get_user_role(user) -> str | None:
    if not user or not getattr(user, "is_authenticated", False):
        return None
    return normalize_role(getattr(user, "role", None))


def allowed_roles(permission: str) -> set[str]:
    try:
        return set(PERMISSION_MATRIX[permission])
    except KeyError as exc:
        raise RolePermissionError(f"Permiso operativo desconocido: {permission}") from exc


def role_has_permission(role: str | None, permission: str) -> bool:
    normalized = normalize_role(role)
    return bool(normalized and normalized in allowed_roles(permission))


def user_has_permission(user, permission: str) -> bool:
    return role_has_permission(get_user_role(user), permission)


def decide_role_permission(user, permission: str) -> RolePermissionDecision:
    role = get_user_role(user)
    return RolePermissionDecision(
        allowed=role_has_permission(role, permission),
        role=role,
        permission=permission,
    )


def permissions_for_role(role: str | None) -> set[str]:
    normalized = normalize_role(role)
    if not normalized:
        return set()
    return {
        permission
        for permission, roles in PERMISSION_MATRIX.items()
        if normalized in roles
    }


def roles_can(permission: str) -> Iterable[str]:
    return tuple(sorted(allowed_roles(permission)))
