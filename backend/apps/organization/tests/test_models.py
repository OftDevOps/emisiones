from django.test import TestCase

from apps.accounts.models import CustomUser, UserRole
from apps.organization.models import Area, Company, Department, Management, OrganizationalUnit


class OrganizationModelsTests(TestCase):
    def test_create_company(self):
        company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT", rif="J-00000000-0")
        self.assertEqual(str(company), "Laboratorios Oftalmi")
        self.assertTrue(company.is_active)

    def test_create_full_structure(self):
        company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        management = Management.objects.create(company=company, name="Gerencia General", code="GG")
        area = Area.objects.create(company=company, management=management, name="Administración", code="ADM")
        department = Department.objects.create(company=company, area=area, name="Cuentas por Pagar", code="CXP")
        unit = OrganizationalUnit.objects.create(
            company=company,
            management=management,
            area=area,
            department=department,
            name="Unidad de Pagos",
            code="UPG",
        )

        self.assertEqual(unit.company, company)
        self.assertEqual(unit.management, management)
        self.assertEqual(unit.area, area)
        self.assertEqual(unit.department, department)

    def test_assign_user_to_organization(self):
        company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        unit = OrganizationalUnit.objects.create(company=company, name="Finanzas", code="FIN")
        user = CustomUser.objects.create_user(
            email="finanzas@oftalmi.com",
            password="test-pass-123",
            role=UserRole.FINANZAS,
            primary_company=company,
            primary_organizational_unit=unit,
        )

        self.assertEqual(user.primary_company, company)
        self.assertEqual(user.primary_organizational_unit, unit)
        self.assertEqual(user.role, UserRole.FINANZAS)
