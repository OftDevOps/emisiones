from django.urls import path

from .views import (
    PaymentRequestCancelView,
    PaymentRequestCreateView,
    PaymentRequestDashboardView,
    AccountsPayablePendingView,
    PaymentRequestDetailView,
    PaymentRequestListView,
    PaymentRequestSubmitView,
)

app_name = "payment_requests"

urlpatterns = [
    path("", PaymentRequestListView.as_view(), name="list"),
    path("new/", PaymentRequestCreateView.as_view(), name="create"),
    path("dashboard/", PaymentRequestDashboardView.as_view(), name="dashboard"),
    path("accounts-payable/", AccountsPayablePendingView.as_view(), name="accounts_payable"),
    path("<int:pk>/", PaymentRequestDetailView.as_view(), name="detail"),
    path("<int:pk>/submit/", PaymentRequestSubmitView.as_view(), name="submit"),
    path("<int:pk>/cancel/", PaymentRequestCancelView.as_view(), name="cancel"),
]
