from .models import PaymentRequest, PaymentRequestItem, TaxRate
from django import forms
from django.forms import inlineformset_factory

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

class PaymentRequestItemForm(forms.ModelForm):
    """Form for one invoice/emission item in the payment request creation flow."""

    tax_rate = forms.ModelChoiceField(
        queryset=TaxRate.objects.filter(is_active=True),
        required=False,
        label="IVA",
        empty_label="Sin IVA",
    )

    class Meta:
        model = PaymentRequestItem
        fields = ("description", "quantity", "unit_price", "tax_rate")
        labels = {
            "description": "Descripción",
            "quantity": "Cantidad",
            "unit_price": "Precio unitario",
            "tax_rate": "IVA",
        }
        widgets = {
            "description": forms.TextInput(attrs={"class": "form-control", "placeholder": "Descripción del ítem"}),
            "quantity": forms.NumberInput(attrs={"class": "form-control", "min": "0.01", "step": "0.01"}),
            "unit_price": forms.NumberInput(attrs={"class": "form-control", "min": "0.00", "step": "0.01"}),
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["tax_rate"].widget.attrs.update({"class": "form-select"})

    def clean(self):
        cleaned_data = super().clean()
        if cleaned_data.get("DELETE"):
            return cleaned_data

        description = cleaned_data.get("description")
        quantity = cleaned_data.get("quantity")
        unit_price = cleaned_data.get("unit_price")

        if description or quantity or unit_price:
            if not description:
                self.add_error("description", "Debe indicar la descripción del ítem.")
            if quantity is None:
                self.add_error("quantity", "Debe indicar la cantidad del ítem.")
            if unit_price is None:
                self.add_error("unit_price", "Debe indicar el precio unitario del ítem.")

        return cleaned_data


PaymentRequestItemFormSet = inlineformset_factory(
    PaymentRequest,
    PaymentRequestItem,
    form=PaymentRequestItemForm,
    fields=("description", "quantity", "unit_price", "tax_rate"),
    extra=1,
    min_num=1,
    validate_min=True,
    can_delete=False,
)
