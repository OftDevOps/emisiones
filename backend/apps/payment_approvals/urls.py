from .views import PendingApprovalStepsView
from django.urls import path

from . import views

app_name = "payment_approvals"

urlpatterns = [
    path("pending/", PendingApprovalStepsView.as_view(), name="pending"),
    path("steps/<int:pk>/action/", views.ApprovalStepActionView.as_view(), name="step_action"),
]
