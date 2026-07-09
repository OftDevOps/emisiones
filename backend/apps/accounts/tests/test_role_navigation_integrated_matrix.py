import re

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import UserRole
from apps.accounts.role_permissions import (
    PERM_CREATE_PAYMENT_REQUEST,
    PERM_VIEW_AUDIT_WORKBENCH,
    PERM_VIEW_PAYMENT_REQUEST_DASHBOARD,
    PERM_VIEW_PAYMENT_REQUESTS,
    PERM_VIEW_PENDING_APPROVALS,
    user_has_permission,
)


NAVIGATION_CASES = (
    ("Emisiones", "payment_requests:dashboard", PERM_VIEW_PAYMENT_REQUEST_DASHBOARD),
    ("Listado", "payment_requests:list", PERM_VIEW_PAYMENT_REQUESTS),
    ("Nueva emisión", "payment_requests:create", PERM_CREATE_PAYMENT_REQUEST),
    ("Aprobaciones", "payment_approvals:pending", PERM_VIEW_PENDING_APPROVALS),
    ("Auditoria", "payment_approvals:audit", PERM_VIEW_AUDIT_WORKBENCH),
)


class RoleNavigationIntegratedMatrixTests(TestCase):
    password = "Demo123456*"

    def create_user(self, role):
        user_model = get_user_model()
        role_value = role.value
        email = f"{role_value.lower()}@nav-matrix.oftalmi.com"
        return user_model.objects.create_user(
            email=email,
            password=self.password,
            role=role_value,
        )

    def get_dashboard_response(self, user):
        self.client.force_login(user)
        return self.client.get(reverse("payment_requests:dashboard"))

    def extract_navigation_html(self, response):
        content = response.content.decode("utf-8")
        match = re.search(
            r'<nav class="oftalmi-nav"[^>]*>[\s\S]*?</nav>',
            content,
        )
        self.assertIsNotNone(match, "No se encontro el bloque nav.oftalmi-nav.")
        return match.group(0)

    def test_navigation_visibility_matches_backend_permission_matrix_for_all_roles(self):
        for role in UserRole:
            with self.subTest(role=role.value):
                user = self.create_user(role)
                response = self.get_dashboard_response(user)

                if not user_has_permission(user, PERM_VIEW_PAYMENT_REQUEST_DASHBOARD):
                    self.assertIn(response.status_code, (403, 302))
                    continue

                self.assertEqual(response.status_code, 200)
                nav_html = self.extract_navigation_html(response)

                for label, route_name, permission in NAVIGATION_CASES:
                    expected_url = reverse(route_name)
                    has_permission = user_has_permission(user, permission)

                    if has_permission:
                        self.assertIn(label, nav_html)
                        self.assertIn(f'href="{expected_url}"', nav_html)
                    else:
                        self.assertNotIn(label, nav_html)
                        self.assertNotIn(f'href="{expected_url}"', nav_html)

    def test_backend_permissions_remain_authoritative_for_hidden_links(self):
        user = self.create_user(UserRole.SOLICITANTE)
        self.client.force_login(user)

        protected_urls = (
            reverse("payment_requests:accounts_payable"),
            reverse("payment_approvals:audit"),
        )

        for protected_url in protected_urls:
            with self.subTest(url=protected_url):
                response = self.client.get(protected_url)
                self.assertEqual(response.status_code, 403)

    def test_nav_matrix_routes_are_resolvable(self):
        for _label, route_name, _permission in NAVIGATION_CASES:
            with self.subTest(route_name=route_name):
                self.assertTrue(reverse(route_name).startswith("/"))
