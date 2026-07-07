from datetime import date
from decimal import Decimal

from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary, BeneficiaryType
from apps.organization.models import Company
from apps.payment_requests.models import Currency, PaymentRequest, PaymentRequestStatus


class PaymentRequestReportViewTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.other_company = Company.objects.create(name="Otra Empresa", code="OTH")
        self.finance_user = CustomUser.objects.create_user(
            email="finanzas.reportes@oftalmi.com",
            password="test-pass-123",
            role=UserRole.FINANZAS,
            primary_company=self.company,
        )
        self.requester = CustomUser.objects.create_user(
            email="solicitante.reportes@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.company,
        )
        self.other_user = CustomUser.objects.create_user(
            email="otro.reportes@oftalmi.com",
            password="test-pass-123",
            role=UserRole.FINANZAS,
            primary_company=self.other_company,
        )
        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Reportes C.A.",
            document_number="J-11111111-1",
            email="proveedor.reportes@example.com",
        )
        self.other_beneficiary = Beneficiary.objects.create(
            company=self.other_company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Externo Reportes C.A.",
            document_number="J-22222222-2",
            email="proveedor.externo.reportes@example.com",
        )
        self.url = reverse("payment_requests:report")

    def create_payment_request(self, company, beneficiary, user, status, concept, due_date):
        return PaymentRequest.objects.create(
            company=company,
            beneficiary=beneficiary,
            requested_by=user,
            amount=Decimal("250.00"),
            currency=Currency.VES,
            concept=concept,
            status=status,
            due_date=due_date,
        )

    def test_report_requires_login(self):
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 302)

    def test_finance_user_can_access_report(self):
        self.client.force_login(self.finance_user)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, "payment_requests/paymentrequest_report.html")
        self.assertContains(response, "Reporte operativo de solicitudes")

    def test_solicitante_cannot_access_report(self):
        self.client.force_login(self.requester)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 403)

    def test_report_scopes_results_to_user_company(self):
        self.client.force_login(self.finance_user)
        self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            PaymentRequestStatus.APPROVED,
            "Solicitud visible reporte",
            date(2026, 7, 10),
        )
        self.create_payment_request(
            self.other_company,
            self.other_beneficiary,
            self.other_user,
            PaymentRequestStatus.APPROVED,
            "Solicitud oculta reporte",
            date(2026, 7, 10),
        )

        response = self.client.get(self.url)

        self.assertEqual(response.context["total_requests"], 1)
        self.assertContains(response, "Solicitud visible reporte")
        self.assertNotContains(response, "Solicitud oculta reporte")

    def test_report_filters_by_status_and_date_range(self):
        self.client.force_login(self.finance_user)
        expected = self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            PaymentRequestStatus.APPROVED,
            "Aprobada dentro del rango",
            date(2026, 7, 15),
        )
        self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            PaymentRequestStatus.REJECTED,
            "Rechazada fuera del filtro",
            date(2026, 7, 15),
        )
        self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            PaymentRequestStatus.APPROVED,
            "Aprobada fuera de fecha",
            date(2026, 8, 1),
        )

        response = self.client.get(
            self.url,
            {
                "status": PaymentRequestStatus.APPROVED,
                "date_from": "2026-07-01",
                "date_to": "2026-07-31",
            },
        )

        self.assertEqual(list(response.context["payment_requests"]), [expected])
        self.assertEqual(response.context["total_requests"], 1)
        self.assertContains(response, "Aprobada dentro del rango")
        self.assertNotContains(response, "Rechazada fuera del filtro")
        self.assertNotContains(response, "Aprobada fuera de fecha")

    def test_report_export_requires_login(self):
        response = self.client.get(reverse("payment_requests:report_export"))

        self.assertEqual(response.status_code, 302)

    def test_solicitante_cannot_export_report(self):
        self.client.force_login(self.requester)

        response = self.client.get(reverse("payment_requests:report_export"))

        self.assertEqual(response.status_code, 403)

    def test_finance_user_can_export_filtered_report_as_csv(self):
        self.client.force_login(self.finance_user)
        self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            PaymentRequestStatus.APPROVED,
            "Exportable dentro del rango",
            date(2026, 7, 15),
        )
        self.create_payment_request(
            self.company,
            self.beneficiary,
            self.finance_user,
            PaymentRequestStatus.REJECTED,
            "No exportable por estado",
            date(2026, 7, 15),
        )
        self.create_payment_request(
            self.other_company,
            self.other_beneficiary,
            self.other_user,
            PaymentRequestStatus.APPROVED,
            "No exportable por empresa",
            date(2026, 7, 15),
        )

        response = self.client.get(
            reverse("payment_requests:report_export"),
            {
                "status": PaymentRequestStatus.APPROVED,
                "date_from": "2026-07-01",
                "date_to": "2026-07-31",
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Content-Type"], "text/csv; charset=utf-8")
        self.assertIn("attachment;", response["Content-Disposition"])
        content = response.content.decode("utf-8-sig")
        self.assertIn("Empresa,Beneficiario,Concepto,Estado", content)
        self.assertIn("Exportable dentro del rango", content)
        self.assertNotIn("No exportable por estado", content)
        self.assertNotIn("No exportable por empresa", content)

    def test_report_screen_exposes_export_action(self):
        self.client.force_login(self.finance_user)

        response = self.client.get(self.url)

        self.assertContains(response, "Exportar CSV")
        self.assertContains(response, reverse("payment_requests:report_export"))
