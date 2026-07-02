from django import forms

from .models import ApprovalActionType


class ApprovalActionForm(forms.Form):
    action = forms.ChoiceField(
        choices=(
            (ApprovalActionType.APPROVE, "Aprobar"),
            (ApprovalActionType.REJECT, "Rechazar"),
        ),
        label="Acción",
    )
    comment = forms.CharField(
        label="Comentario",
        required=False,
        widget=forms.Textarea(attrs={"rows": 3}),
    )

    def clean(self):
        cleaned_data = super().clean()
        action = cleaned_data.get("action")
        comment = (cleaned_data.get("comment") or "").strip()

        if action == ApprovalActionType.REJECT and not comment:
            self.add_error("comment", "El comentario es obligatorio para rechazar una solicitud.")

        cleaned_data["comment"] = comment
        return cleaned_data
