from django.contrib.auth import get_user_model
from django.test import TestCase

from apps.accounts.models import UserRole


class CustomUserModelTests(TestCase):
    def test_create_user_with_email(self):
        User = get_user_model()
        user = User.objects.create_user(
            email="solicitante@oftalmi.com",
            password="test-password-123",
        )

        self.assertEqual(user.email, "solicitante@oftalmi.com")
        self.assertEqual(user.username, "solicitante@oftalmi.com")
        self.assertEqual(user.role, UserRole.SOLICITANTE)
        self.assertTrue(user.check_password("test-password-123"))

    def test_email_is_required(self):
        User = get_user_model()
        with self.assertRaises(ValueError):
            User.objects.create_user(email="", password="test-password-123")

    def test_email_is_unique(self):
        User = get_user_model()
        User.objects.create_user(email="finanzas@oftalmi.com", password="test-password-123")

        with self.assertRaises(Exception):
            User.objects.create_user(email="finanzas@oftalmi.com", password="test-password-456")

    def test_create_superuser(self):
        User = get_user_model()
        user = User.objects.create_superuser(
            email="admin@oftalmi.com",
            password="admin-password-123",
        )

        self.assertTrue(user.is_staff)
        self.assertTrue(user.is_superuser)
        self.assertEqual(user.role, UserRole.ADMINISTRADOR)
