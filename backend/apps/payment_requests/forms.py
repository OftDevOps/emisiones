from django import forms

from .models import PaymentRequest
from apps.beneficiaries.models import Beneficiary


class PaymentRequestCreateForm(forms.ModelForm):
    class Meta:
        model = PaymentRequest
        fields = [
            "company",
            "beneficiary",
            "amount",
            "currency",
            "concept",
            "description",
            "due_date",
        ]
        widgets = {
            "due_date": forms.DateInput(attrs={"type": "date"}),
            "description": forms.Textarea(attrs={"rows": 4}),
        }

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.user = user

        if user is not None and getattr(user, "primary_company_id", None):
            self.fields["company"].queryset = self.fields["company"].queryset.filter(
                id=user.primary_company_id
            )
            self.fields["company"].initial = user.primary_company
            self.fields["beneficiary"].queryset = Beneficiary.objects.filter(
                company=user.primary_company,
                is_active=True,
            )
        else:
            self.fields["beneficiary"].queryset = Beneficiary.objects.filter(is_active=True)

    def clean(self):
        cleaned_data = super().clean()
        company = cleaned_data.get("company")
        beneficiary = cleaned_data.get("beneficiary")

        if company and beneficiary and beneficiary.company_id != company.id:
            self.add_error(
                "beneficiary",
                "El beneficiario debe pertenecer a la empresa seleccionada.",
            )

        return cleaned_data
