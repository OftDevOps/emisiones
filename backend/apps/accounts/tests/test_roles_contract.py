"""Role contract tests for Apps Emisiones Phase 2.

These tests intentionally validate the public role contract without changing
business flows or database schema.
"""

from django.test import SimpleTestCase

from apps.accounts.models import UserRole


class UserRoleContractTests(SimpleTestCase):
    def test_phase2_operational_roles_exist(self):
        expected_roles = {
            "ADMINISTRADOR",
            "SOLICITANTE",
            "RESPONSABLE_UNIDAD",
            "FINANZAS",
            "CUENTAS_POR_PAGAR",
            "AUDITOR",
        }

        current_roles = {role.value for role in UserRole}

        self.assertTrue(
            expected_roles.issubset(current_roles),
            f"Missing roles: {sorted(expected_roles - current_roles)}",
        )

    def test_roles_are_stable_uppercase_identifiers(self):
        for role in UserRole:
            self.assertEqual(role.value, role.value.upper())
            self.assertNotIn(" ", role.value)
