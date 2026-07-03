from .views import CrossActionAuditWorkbenchView, PendingApprovalStepsView
from django.urls import path

from . import views

app_name = "payment_approvals"

urlpatterns = [
    path("audit/", CrossActionAuditWorkbenchView.as_view(), name="audit"),
    path("pending/", PendingApprovalStepsView.as_view(), name="pending"),
    path("steps/<int:pk>/action/", views.ApprovalStepActionView.as_view(), name="step_action"),
]
