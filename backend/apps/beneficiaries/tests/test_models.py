from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.test import TestCase

from apps.beneficiaries.models import (
    AccountType,
    Beneficiary,
    BeneficiaryBankAccount,
    BeneficiaryType,
    Currency,
    DocumentType,
)
from apps.organization.models import Company


class BeneficiaryModelsTests(TestCase):
    def setUp(self):
        self.company = Company.objects.create(name="Laboratorios Oftalmi", code="OFT")
        self.other_company = Company.objects.create(name="Oftalmi Distribución", code="OFD")

    def test_create_supplier_beneficiary(self):
        beneficiary = Beneficiary.objects.create(
            company=self.company,
            beneficiary_type=BeneficiaryType.SUPPLIER,
            document_type=DocumentType.RIF,
            document_number="j-12345678-9",
            legal_name="  Proveedor   Médico  CA  ",
            email="proveedor@example.com",
        )

        self.assertEqual(beneficiary.document_number, "J-12345678-9")
        self.assertEqual(beneficiary.legal_name, "Proveedor Médico CA")
        self.assertEqual(str(beneficiary), "Proveedor Médico CA (J-12345678-9)")
        self.assertTrue(beneficiary.is_active)

    def test_document_must_be_unique_by_company(self):
        Beneficiary.objects.create(
            company=self.company,
            document_type=DocumentType.RIF,
            document_number="J-12345678-9",
            legal_name="Proveedor Uno",
        )

        with self.assertRaises(ValidationError):
            Beneficiary.objects.create(
                company=self.company,
                document_type=DocumentType.RIF,
                document_number="J-12345678-9",
                legal_name="Proveedor Duplicado",
            )

    def test_same_document_can_exist_in_another_company(self):
        Beneficiary.objects.create(
            company=self.company,
            document_type=DocumentType.RIF,
            document_number="J-12345678-9",
            legal_name="Proveedor Uno",
        )
        beneficiary = Beneficiary.objects.create(
            company=self.other_company,
            document_type=DocumentType.RIF,
            document_number="J-12345678-9",
            legal_name="Proveedor Otra Empresa",
        )

        self.assertEqual(beneficiary.company, self.other_company)

    def test_create_bank_account(self):
        beneficiary = Beneficiary.objects.create(
            company=self.company,
            document_type=DocumentType.RIF,
            document_number="J-12345678-9",
            legal_name="Proveedor Médico CA",
        )
        account = BeneficiaryBankAccount.objects.create(
            beneficiary=beneficiary,
            bank_name=" Banco Nacional ",
            account_number=" 0102 0000 0000 0000 0000 ",
            account_holder=" Proveedor Médico CA ",
            account_type=AccountType.CHECKING,
            currency=Currency.VES,
            is_primary=True,
        )

        self.assertEqual(account.bank_name, "Banco Nacional")
        self.assertEqual(account.account_number, "01020000000000000000")
        self.assertEqual(account.account_holder, "Proveedor Médico CA")
        self.assertTrue(account.is_primary)

    def test_bank_account_unique_by_beneficiary_number_and_currency(self):
        beneficiary = Beneficiary.objects.create(
            company=self.company,
            document_type=DocumentType.RIF,
            document_number="J-12345678-9",
            legal_name="Proveedor Médico CA",
        )
        BeneficiaryBankAccount.objects.create(
            beneficiary=beneficiary,
            bank_name="Banco Nacional",
            account_number="01020000000000000000",
            account_holder="Proveedor Médico CA",
            currency=Currency.VES,
        )

        with self.assertRaises(ValidationError):
            BeneficiaryBankAccount.objects.create(
                beneficiary=beneficiary,
                bank_name="Banco Nacional",
                account_number="0102 0000 0000 0000 0000",
                account_holder="Proveedor Médico CA",
                currency=Currency.VES,
            )

    def test_database_constraint_blocks_duplicate_document_if_clean_is_bypassed(self):
        Beneficiary.objects.create(
            company=self.company,
            document_type=DocumentType.RIF,
            document_number="J-12345678-9",
            legal_name="Proveedor Uno",
        )

        duplicate = Beneficiary(
            company=self.company,
            document_type=DocumentType.RIF,
            document_number="J-12345678-9",
            legal_name="Proveedor Duplicado",
        )

        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                Beneficiary.objects.bulk_create([duplicate])
