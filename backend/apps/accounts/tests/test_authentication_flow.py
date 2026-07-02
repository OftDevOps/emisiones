from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import CustomUser, UserRole
from apps.organization.models import Company, OrganizationalUnit


class AuthenticationFlowTests(TestCase):
    def setUp(self):
        self.password = "Test-pass-12345"
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.unit = OrganizationalUnit.objects.create(
            company=self.company,
            name="Finanzas",
            code="FIN",
        )
        self.user = CustomUser.objects.create_user(
            email="usuario.login@oftalmi.com",
            password=self.password,
            role=UserRole.FINANZAS,
            primary_company=self.company,
            primary_organizational_unit=self.unit,
        )

    def test_login_page_is_public(self):
        response = self.client.get(reverse("accounts:login"))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Iniciar sesión")

    def test_dashboard_requires_authentication(self):
        dashboard_url = reverse("accounts:dashboard")
        login_url = reverse("accounts:login")

        response = self.client.get(dashboard_url)

        self.assertRedirects(response, f"{login_url}?next={dashboard_url}")

    def test_user_can_login_and_access_dashboard(self):
        response = self.client.post(
            reverse("accounts:login"),
            {"username": self.user.email, "password": self.password},
            follow=True,
        )

        self.assertRedirects(response, reverse("accounts:dashboard"))
        self.assertContains(response, "Panel principal")
        self.assertContains(response, self.user.email)
        self.assertContains(response, "Finanzas")

    def test_authenticated_user_redirected_away_from_login(self):
        self.client.force_login(self.user)

        response = self.client.get(reverse("accounts:login"))

        self.assertRedirects(response, reverse("accounts:dashboard"))

    def test_user_can_logout_by_post(self):
        self.client.force_login(self.user)

        response = self.client.post(reverse("accounts:logout"), follow=True)

        self.assertRedirects(response, reverse("accounts:login"))
        dashboard_response = self.client.get(reverse("accounts:dashboard"))
        self.assertEqual(dashboard_response.status_code, 302)

    def test_logout_get_does_not_end_session(self):
        self.client.force_login(self.user)

        response = self.client.get(reverse("accounts:logout"))

        self.assertRedirects(response, reverse("accounts:dashboard"))
        dashboard_response = self.client.get(reverse("accounts:dashboard"))
        self.assertEqual(dashboard_response.status_code, 200)
