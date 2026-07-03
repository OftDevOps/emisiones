from django import forms

from .models import PaymentExecution


class PaymentExecutionForm(forms.ModelForm):
    class Meta:
        model = PaymentExecution
        fields = ["paid_at", "paid_amount", "bank_reference", "note"]
        widgets = {
            "paid_at": forms.DateInput(attrs={"type": "date"}),
            "note": forms.Textarea(attrs={"rows": 3}),
        }
