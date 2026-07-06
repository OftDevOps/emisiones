#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$ROOT"

echo "== F2-P03: Aplicacion efectiva de permisos por rol en vistas criticas =="

ACCOUNTS_DIR="backend/apps/accounts"
REQ_DIR="backend/apps/payment_requests"
APPROVALS_DIR="backend/apps/payment_approvals"
EXEC_DIR="backend/apps/payment_execution"

for d in "$ACCOUNTS_DIR" "$REQ_DIR" "$APPROVALS_DIR" "$EXEC_DIR"; do
  if [[ ! -d "$d" ]]; then
    echo "ERROR: directorio esperado no existe: $d" >&2
    exit 1
  fi
done

mkdir -p "$ACCOUNTS_DIR/tests" docs

cat > "$ACCOUNTS_DIR/role_permissions.py" <<'PY'
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
PY

cat > "$ACCOUNTS_DIR/mixins.py" <<'PY'
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
PY

cat > "$ACCOUNTS_DIR/tests/test_role_permissions.py" <<'PY'
from django.test import SimpleTestCase

from apps.accounts.role_permissions import (
    PERM_EXECUTE_APPROVAL_ACTION,
    PERM_REGISTER_PAYMENT_EXECUTION,
    PERM_VIEW_ACCOUNTS_PAYABLE,
    PERM_VIEW_AUDIT_WORKBENCH,
    PERM_VIEW_PENDING_APPROVALS,
    ROLE_ADMINISTRADOR,
    ROLE_AUDITOR,
    ROLE_CUENTAS_POR_PAGAR,
    ROLE_FINANZAS,
    ROLE_RESPONSABLE_UNIDAD,
    ROLE_SOLICITANTE,
    RolePermissionError,
    permissions_for_role,
    role_has_permission,
    roles_can,
)


class RolePermissionsPolicyTests(SimpleTestCase):
    def test_accounts_payable_access_is_restricted_to_operational_roles(self):
        assert role_has_permission(ROLE_ADMINISTRADOR, PERM_VIEW_ACCOUNTS_PAYABLE)
        assert role_has_permission(ROLE_CUENTAS_POR_PAGAR, PERM_VIEW_ACCOUNTS_PAYABLE)
        assert role_has_permission(ROLE_FINANZAS, PERM_VIEW_ACCOUNTS_PAYABLE)
        assert not role_has_permission(ROLE_SOLICITANTE, PERM_VIEW_ACCOUNTS_PAYABLE)
        assert not role_has_permission(ROLE_AUDITOR, PERM_VIEW_ACCOUNTS_PAYABLE)

    def test_payment_execution_is_limited_to_accounts_payable_and_admin(self):
        assert role_has_permission(ROLE_ADMINISTRADOR, PERM_REGISTER_PAYMENT_EXECUTION)
        assert role_has_permission(ROLE_CUENTAS_POR_PAGAR, PERM_REGISTER_PAYMENT_EXECUTION)
        assert not role_has_permission(ROLE_FINANZAS, PERM_REGISTER_PAYMENT_EXECUTION)
        assert not role_has_permission(ROLE_RESPONSABLE_UNIDAD, PERM_REGISTER_PAYMENT_EXECUTION)
        assert not role_has_permission(ROLE_SOLICITANTE, PERM_REGISTER_PAYMENT_EXECUTION)

    def test_approval_actions_are_limited_to_approval_roles(self):
        assert role_has_permission(ROLE_ADMINISTRADOR, PERM_EXECUTE_APPROVAL_ACTION)
        assert role_has_permission(ROLE_RESPONSABLE_UNIDAD, PERM_EXECUTE_APPROVAL_ACTION)
        assert role_has_permission(ROLE_FINANZAS, PERM_EXECUTE_APPROVAL_ACTION)
        assert not role_has_permission(ROLE_CUENTAS_POR_PAGAR, PERM_EXECUTE_APPROVAL_ACTION)
        assert not role_has_permission(ROLE_AUDITOR, PERM_EXECUTE_APPROVAL_ACTION)

    def test_audit_workbench_is_limited_to_admin_and_auditor(self):
        assert role_has_permission(ROLE_ADMINISTRADOR, PERM_VIEW_AUDIT_WORKBENCH)
        assert role_has_permission(ROLE_AUDITOR, PERM_VIEW_AUDIT_WORKBENCH)
        assert not role_has_permission(ROLE_SOLICITANTE, PERM_VIEW_AUDIT_WORKBENCH)
        assert not role_has_permission(ROLE_CUENTAS_POR_PAGAR, PERM_VIEW_AUDIT_WORKBENCH)

    def test_pending_approval_access_excludes_requester_auditor_and_accounts_payable(self):
        assert role_has_permission(ROLE_ADMINISTRADOR, PERM_VIEW_PENDING_APPROVALS)
        assert role_has_permission(ROLE_RESPONSABLE_UNIDAD, PERM_VIEW_PENDING_APPROVALS)
        assert role_has_permission(ROLE_FINANZAS, PERM_VIEW_PENDING_APPROVALS)
        assert not role_has_permission(ROLE_SOLICITANTE, PERM_VIEW_PENDING_APPROVALS)
        assert not role_has_permission(ROLE_AUDITOR, PERM_VIEW_PENDING_APPROVALS)
        assert not role_has_permission(ROLE_CUENTAS_POR_PAGAR, PERM_VIEW_PENDING_APPROVALS)

    def test_unknown_permission_fails_closed(self):
        try:
            role_has_permission(ROLE_ADMINISTRADOR, "unknown.permission")
        except RolePermissionError:
            return
        raise AssertionError("unknown permission should fail closed")

    def test_permissions_for_role_returns_effective_policy(self):
        permissions = permissions_for_role(ROLE_CUENTAS_POR_PAGAR)
        assert PERM_VIEW_ACCOUNTS_PAYABLE in permissions
        assert PERM_REGISTER_PAYMENT_EXECUTION in permissions
        assert PERM_EXECUTE_APPROVAL_ACTION not in permissions

    def test_roles_can_returns_sorted_allowed_roles(self):
        assert list(roles_can(PERM_VIEW_AUDIT_WORKBENCH)) == [
            ROLE_ADMINISTRADOR,
            ROLE_AUDITOR,
        ]
PY

# Patch views defensively. This keeps existing object-level checks intact and adds centralized role gates.
python3 - <<'PY'
from pathlib import Path

patches = []

# payment_requests views
path = Path("backend/apps/payment_requests/views.py")
text = path.read_text(encoding="utf-8")
original = text
if "apps.accounts.role_permissions" not in text:
    marker = "from django"
    insert = (
        "from apps.accounts.role_permissions import (\n"
        "    PERM_CREATE_PAYMENT_REQUEST,\n"
        "    PERM_SUBMIT_PAYMENT_REQUEST,\n"
        "    PERM_VIEW_ACCOUNTS_PAYABLE,\n"
        "    PERM_VIEW_PAYMENT_REQUEST_DASHBOARD,\n"
        "    PERM_VIEW_PAYMENT_REQUESTS,\n"
        "    user_has_permission,\n"
        ")\n"
    )
    idx = text.find(marker)
    if idx == -1:
        raise SystemExit("ERROR: no se encontro bloque de imports Django en payment_requests/views.py")
    text = text[:idx] + insert + text[idx:]

# Add helper if absent
if "def _require_operational_permission(" not in text:
    insert_after = text.find("\n\n")
    helper = '''\n\ndef _require_operational_permission(user, permission: str, message: str) -> None:\n    if not user_has_permission(user, permission):\n        raise PermissionDenied(message)\n'''
    text = text[:insert_after] + helper + text[insert_after:]

replacements = {
    'if self.request.user.role not in ["ADMINISTRADOR", "CUENTAS_POR_PAGAR", "FINANZAS"]:\n            raise PermissionDenied("Su rol no permite acceder a Cuentas por Pagar.")': '_require_operational_permission(\n            self.request.user,\n            PERM_VIEW_ACCOUNTS_PAYABLE,\n            "Su rol no permite acceder a Cuentas por Pagar.",\n        )',
    'if self.request.user.role not in ["ADMINISTRADOR", "SOLICITANTE", "RESPONSABLE_UNIDAD", "FINANZAS"]:\n            raise PermissionDenied("Su rol no permite crear solicitudes de pago.")': '_require_operational_permission(\n            self.request.user,\n            PERM_CREATE_PAYMENT_REQUEST,\n            "Su rol no permite crear solicitudes de pago.",\n        )',
}
for old, new in replacements.items():
    if old in text:
        text = text.replace(old, new)

# Inject gates in common class methods only when class names exist and no gate is nearby.
for class_name, permission, message in [
    ("PaymentRequestDashboardView", "PERM_VIEW_PAYMENT_REQUEST_DASHBOARD", "Su rol no permite acceder al dashboard de solicitudes."),
    ("PaymentRequestListView", "PERM_VIEW_PAYMENT_REQUESTS", "Su rol no permite consultar solicitudes de pago."),
]:
    marker = f"class {class_name}"
    pos = text.find(marker)
    if pos != -1:
        next_class = text.find("\nclass ", pos + 1)
        block_end = next_class if next_class != -1 else len(text)
        block = text[pos:block_end]
        if permission not in block:
            # Add dispatch after class declaration line
            line_end = text.find("\n", pos)
            method = f'''\n    def dispatch(self, request, *args, **kwargs):\n        _require_operational_permission(\n            request.user,\n            {permission},\n            "{message}",\n        )\n        return super().dispatch(request, *args, **kwargs)\n'''
            text = text[:line_end+1] + method + text[line_end+1:]

if text != original:
    path.write_text(text, encoding="utf-8")
    patches.append(str(path))

# payment_approvals views
path = Path("backend/apps/payment_approvals/views.py")
text = path.read_text(encoding="utf-8")
original = text
if "apps.accounts.role_permissions" not in text:
    marker = "from django"
    insert = (
        "from apps.accounts.role_permissions import (\n"
        "    PERM_EXECUTE_APPROVAL_ACTION,\n"
        "    PERM_VIEW_AUDIT_WORKBENCH,\n"
        "    PERM_VIEW_PENDING_APPROVALS,\n"
        "    user_has_permission,\n"
        ")\n"
    )
    idx = text.find(marker)
    if idx == -1:
        raise SystemExit("ERROR: no se encontro bloque de imports Django en payment_approvals/views.py")
    text = text[:idx] + insert + text[idx:]
if "def _require_operational_permission(" not in text:
    insert_after = text.find("\n\n")
    helper = '''\n\ndef _require_operational_permission(user, permission: str, message: str) -> None:\n    if not user_has_permission(user, permission):\n        raise PermissionDenied(message)\n'''
    text = text[:insert_after] + helper + text[insert_after:]

replacements = {
    'if self.request.user.role not in ["ADMINISTRADOR", "RESPONSABLE_UNIDAD", "FINANZAS"]:\n            raise PermissionDenied("Su rol no permite ver aprobaciones pendientes.")': '_require_operational_permission(\n            self.request.user,\n            PERM_VIEW_PENDING_APPROVALS,\n            "Su rol no permite ver aprobaciones pendientes.",\n        )',
    'if self.request.user.role not in ["ADMINISTRADOR", "AUDITOR"]:\n            raise PermissionDenied("Su rol no permite acceder a la auditoria.")': '_require_operational_permission(\n            self.request.user,\n            PERM_VIEW_AUDIT_WORKBENCH,\n            "Su rol no permite acceder a la auditoria.",\n        )',
    'if self.request.user.role not in ["ADMINISTRADOR", "RESPONSABLE_UNIDAD", "FINANZAS"]:\n            raise PermissionDenied("Su rol no permite ejecutar este paso de aprobación.")': '_require_operational_permission(\n            self.request.user,\n            PERM_EXECUTE_APPROVAL_ACTION,\n            "Su rol no permite ejecutar este paso de aprobación.",\n        )',
}
for old, new in replacements.items():
    if old in text:
        text = text.replace(old, new)

if text != original:
    path.write_text(text, encoding="utf-8")
    patches.append(str(path))

# payment_execution views
path = Path("backend/apps/payment_execution/views.py")
text = path.read_text(encoding="utf-8")
original = text
if "apps.accounts.role_permissions" not in text:
    marker = "from django"
    insert = (
        "from apps.accounts.role_permissions import (\n"
        "    PERM_REGISTER_PAYMENT_EXECUTION,\n"
        "    user_has_permission,\n"
        ")\n"
    )
    idx = text.find(marker)
    if idx == -1:
        raise SystemExit("ERROR: no se encontro bloque de imports Django en payment_execution/views.py")
    text = text[:idx] + insert + text[idx:]
if "PERM_REGISTER_PAYMENT_EXECUTION" in text and 'self.request.user.role not in ["ADMINISTRADOR", "CUENTAS_POR_PAGAR"]' in text:
    text = text.replace(
        'if self.request.user.role not in ["ADMINISTRADOR", "CUENTAS_POR_PAGAR"]:\n            raise PermissionDenied("Su rol no permite registrar pagos.")',
        'if not user_has_permission(self.request.user, PERM_REGISTER_PAYMENT_EXECUTION):\n            raise PermissionDenied("Su rol no permite registrar pagos.")'
    )
if text != original:
    path.write_text(text, encoding="utf-8")
    patches.append(str(path))

print("PATCHED_FILES:")
for item in patches:
    print(f"- {item}")
PY

cat > "docs/f2_p03_aplicacion_permisos_vistas_criticas.md" <<'MD'
# F2-P03 - Aplicacion efectiva de permisos por rol en vistas criticas

## Objetivo

Aplicar de forma efectiva la matriz de acceso operativa de Fase 2 sobre vistas criticas del MVP de Apps Emisiones, reduciendo reglas dispersas y evitando autorizaciones implicitas por accidente.

## Alcance

Este punto introduce una politica centralizada de permisos operativos por rol y pruebas de contrato para validar que las rutas criticas respetan el modelo esperado.

Vistas y capacidades cubiertas:

- Dashboard/listado de solicitudes de pago.
- Creacion y envio de solicitudes.
- Bandeja de aprobaciones pendientes.
- Ejecucion de acciones de aprobacion.
- Workbench de auditoria.
- Cuentas por pagar.
- Registro de ejecucion de pago.

## Cambios tecnicos

Archivos incorporados:

```text
backend/apps/accounts/role_permissions.py
backend/apps/accounts/mixins.py
backend/apps/accounts/tests/test_role_permissions.py
docs/f2_p03_aplicacion_permisos_vistas_criticas.md
```

Archivos potencialmente ajustados por el script:

```text
backend/apps/payment_requests/views.py
backend/apps/payment_approvals/views.py
backend/apps/payment_execution/views.py
```

## Politica operativa base

| Permiso | Roles autorizados |
|---|---|
| Ver dashboard/listado de solicitudes | ADMINISTRADOR, SOLICITANTE, RESPONSABLE_UNIDAD, FINANZAS, CUENTAS_POR_PAGAR, AUDITOR |
| Crear/enviar solicitudes | ADMINISTRADOR, SOLICITANTE, RESPONSABLE_UNIDAD, FINANZAS |
| Ver aprobaciones pendientes | ADMINISTRADOR, RESPONSABLE_UNIDAD, FINANZAS |
| Ejecutar aprobacion/rechazo | ADMINISTRADOR, RESPONSABLE_UNIDAD, FINANZAS |
| Ver auditoria | ADMINISTRADOR, AUDITOR |
| Ver Cuentas por Pagar | ADMINISTRADOR, CUENTAS_POR_PAGAR, FINANZAS |
| Registrar ejecucion de pago | ADMINISTRADOR, CUENTAS_POR_PAGAR |

## Criterios de aceptacion

- La matriz de permisos queda centralizada en `apps.accounts.role_permissions`.
- Las vistas criticas consumen la politica centralizada donde aplique.
- Los permisos desconocidos fallan cerrado.
- No se crean modelos.
- No se crean migraciones.
- La suite completa mantiene verde.

## Validacion esperada

```bash
nordvpn disconnect
sleep 3

git status
git log --oneline --max-count=5

docker compose exec backend ruff check .
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests apps.payment_documents apps.payment_approvals apps.payment_execution

nordvpn connect United_States
nordvpn status
```

## Riesgo controlado

El endurecimiento se mantiene en permisos operativos de aplicacion. No reemplaza todavia permisos nativos Django, grupos, ni asignaciones administrativas avanzadas. Ese salto debe tratarse como un punto separado si el negocio lo requiere.
MD

cat > "docs/matriz_permisos_efectiva_vistas_criticas.md" <<'MD'
# Matriz efectiva de permisos - Vistas criticas

## Proposito

Documento operativo para auditar que cada vista critica del MVP tiene una decision explicita de acceso por rol.

## Roles

- ADMINISTRADOR
- SOLICITANTE
- RESPONSABLE_UNIDAD
- FINANZAS
- CUENTAS_POR_PAGAR
- AUDITOR

## Reglas efectivas

| Vista/capacidad | Administrador | Solicitante | Responsable Unidad | Finanzas | Cuentas por Pagar | Auditor |
|---|---:|---:|---:|---:|---:|---:|
| Dashboard solicitudes | Si | Si | Si | Si | Si | Si |
| Listado solicitudes | Si | Si | Si | Si | Si | Si |
| Crear solicitud | Si | Si | Si | Si | No | No |
| Enviar solicitud | Si | Si | Si | Si | No | No |
| Ver aprobaciones pendientes | Si | No | Si | Si | No | No |
| Aprobar/Rechazar | Si | No | Si | Si | No | No |
| Ver Cuentas por Pagar | Si | No | No | Si | Si | No |
| Registrar pago | Si | No | No | No | Si | No |
| Ver auditoria | Si | No | No | No | No | Si |

## Decision de diseno

La politica queda expresada en codigo mediante claves de permiso operativo. Esto evita que cada vista mantenga listas manuales de roles no auditables.

## Pendiente posterior recomendado

- F2-P04: Pruebas integradas por rol sobre rutas HTTP criticas.
- F2-P05: Navegacion condicionada por permisos efectivos.
- F2-P06: Gobierno administrativo de usuarios y roles.
MD

echo "== Archivos F2-P03 creados/actualizados =="
printf '%s\n' \
  "$ACCOUNTS_DIR/role_permissions.py" \
  "$ACCOUNTS_DIR/mixins.py" \
  "$ACCOUNTS_DIR/tests/test_role_permissions.py" \
  "docs/f2_p03_aplicacion_permisos_vistas_criticas.md" \
  "docs/matriz_permisos_efectiva_vistas_criticas.md"

echo "== Estado git =="
git status --short
