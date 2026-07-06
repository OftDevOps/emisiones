from django.contrib.auth import get_user_model
from django.test import RequestFactory, TestCase

from apps.accounts.context_processors import role_navigation
from apps.accounts.models import UserRole


class RoleNavigationContextTests(TestCase):
    def setUp(self):
        self.factory = RequestFactory()
        self.user_model = get_user_model()

    def _request_for_role(self, role):
        request = self.factory.get("/")
        request.user = self.user_model.objects.create_user(
            email=f"{role.lower()}@example.com",
            password="test-pass-123",
            role=role,
        )
        return request

    def test_solicitante_navigation_flags(self):
        context = role_navigation(self._request_for_role(UserRole.SOLICITANTE))

        self.assertTrue(context["role_nav"]["can_view_payment_dashboard"])
        self.assertTrue(context["role_nav"]["can_view_payment_requests"])
        self.assertTrue(context["role_nav"]["can_create_payment_request"])
        self.assertFalse(context["role_nav"]["can_view_accounts_payable"])
        self.assertFalse(context["role_nav"]["can_view_audit_workbench"])

    def test_cuentas_por_pagar_navigation_flags(self):
        context = role_navigation(self._request_for_role(UserRole.CUENTAS_POR_PAGAR))

        self.assertTrue(context["role_nav"]["can_view_accounts_payable"])
        self.assertTrue(context["role_nav"]["can_view_payment_requests"])
        self.assertFalse(context["role_nav"]["can_create_payment_request"])

    def test_auditor_navigation_flags(self):
        context = role_navigation(self._request_for_role(UserRole.AUDITOR))

        self.assertTrue(context["role_nav"]["can_view_audit_workbench"])
        self.assertTrue(context["role_nav"]["can_view_payment_requests"])
        self.assertFalse(context["role_nav"]["can_create_payment_request"])

    def test_anonymous_navigation_flags_are_false(self):
        request = self.factory.get("/")

        class AnonymousLikeUser:
            is_authenticated = False

        request.user = AnonymousLikeUser()
        context = role_navigation(request)

        self.assertTrue(context["role_nav"])
        self.assertTrue(all(value is False for value in context["role_nav"].values()))
