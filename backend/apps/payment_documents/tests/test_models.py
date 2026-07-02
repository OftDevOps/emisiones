from decimal import Decimal
from tempfile import TemporaryDirectory

from django.core.exceptions import ValidationError
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings

from apps.accounts.models import CustomUser, UserRole
from apps.beneficiaries.models import Beneficiary, BeneficiaryType
from apps.organization.models import Company
from apps.payment_documents.models import PaymentDocumentType, PaymentRequestDocument, payment_request_document_upload_to
from apps.payment_requests.models import Currency, PaymentRequest


class PaymentRequestDocumentModelTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.user = CustomUser.objects.create_user(
            email="solicitante.docs@oftalmi.com",
            password="test-pass-123",
            role=UserRole.SOLICITANTE,
            primary_company=self.company,
        )
        self.beneficiary = Beneficiary.objects.create(
            company=self.company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            legal_name="Proveedor Documentos C.A.",
            document_number="J-22222222-2",
            email="proveedor.docs@example.com",
        )
        self.payment_request = PaymentRequest.objects.create(
            company=self.company,
            beneficiary=self.beneficiary,
            requested_by=self.user,
            amount=Decimal("150.00"),
            currency=Currency.VES,
            concept="Pago con soporte",
        )

    def make_file(self, name="factura.pdf", content=b"PDF content"):
        return SimpleUploadedFile(name, content, content_type="application/pdf")

    @override_settings(MEDIA_ROOT=TemporaryDirectory().name)
    def test_create_payment_document(self):
        document = PaymentRequestDocument.objects.create(
            payment_request=self.payment_request,
            document_type=PaymentDocumentType.INVOICE,
            file=self.make_file(),
            uploaded_by=self.user,
            notes="Factura principal",
            is_required=True,
        )

        self.assertEqual(document.payment_request, self.payment_request)
        self.assertEqual(document.uploaded_by, self.user)
        self.assertEqual(document.original_filename, "factura.pdf")
        self.assertTrue(document.is_active)
        self.assertTrue(document.is_required)

    def test_file_is_required(self):
        document = PaymentRequestDocument(
            payment_request=self.payment_request,
            document_type=PaymentDocumentType.SUPPORT,
            uploaded_by=self.user,
            original_filename="sin_archivo.pdf",
        )

        with self.assertRaises(ValidationError):
            document.full_clean()

    @override_settings(MEDIA_ROOT=TemporaryDirectory().name)
    def test_deactivate_document(self):
        document = PaymentRequestDocument.objects.create(
            payment_request=self.payment_request,
            document_type=PaymentDocumentType.SUPPORT,
            file=self.make_file("soporte.pdf"),
            uploaded_by=self.user,
        )

        document.deactivate()
        document.refresh_from_db()
        self.assertFalse(document.is_active)

    def test_upload_path_uses_payment_request_id(self):
        document = PaymentRequestDocument(payment_request=self.payment_request)
        path = payment_request_document_upload_to(document, "Factura Original.PDF")

        self.assertEqual(path, f"payment_requests/{self.payment_request.id}/documents/document.pdf")

    @override_settings(MEDIA_ROOT=TemporaryDirectory().name)
    def test_related_documents_from_payment_request(self):
        PaymentRequestDocument.objects.create(
            payment_request=self.payment_request,
            document_type=PaymentDocumentType.PURCHASE_ORDER,
            file=self.make_file("orden.pdf"),
            uploaded_by=self.user,
        )

        self.assertEqual(self.payment_request.documents.count(), 1)
