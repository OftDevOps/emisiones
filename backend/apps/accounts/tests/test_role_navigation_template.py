from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import UserRole


class RoleBasedNavigationTemplateTests(TestCase):
    password = "Demo123456*"

    def create_user(self, email, role):
        user_model = get_user_model()
        return user_model.objects.create_user(
            email=email,
            password=self.password,
            role=role,
        )

    def test_solicitante_does_not_see_accounts_payable_or_audit_links(self):
        user = self.create_user("solicitante.nav@oftalmi.com", UserRole.SOLICITANTE)
        self.client.force_login(user)

        response = self.client.get(reverse("payment_requests:dashboard"))

        self.assertEqual(response.status_code, 200)
        content = response.content.decode("utf-8")
        self.assertIn("Emisiones", content)
        self.assertNotIn("Compras", content)
        self.assertNotIn("Auditoria", content)

    def test_cuentas_por_pagar_sees_compras_link(self):
        user = self.create_user("cxp.nav@oftalmi.com", UserRole.CUENTAS_POR_PAGAR)
        self.client.force_login(user)

        response = self.client.get(reverse("payment_requests:dashboard"))

        self.assertEqual(response.status_code, 200)
        content = response.content.decode("utf-8")
        self.assertIn("Compras", content)

    def test_auditor_sees_audit_link(self):
        user = self.create_user("auditor.nav@oftalmi.com", UserRole.AUDITOR)
        self.client.force_login(user)

        response = self.client.get(reverse("payment_requests:dashboard"))

        self.assertEqual(response.status_code, 200)
        content = response.content.decode("utf-8")
        self.assertIn("Auditoria", content)
