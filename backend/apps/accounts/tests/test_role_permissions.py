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
