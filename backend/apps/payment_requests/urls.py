from django.urls import path

from .views import PaymentRequestCreateView, PaymentRequestDetailView, PaymentRequestListView

app_name = "payment_requests"

urlpatterns = [
    path("", PaymentRequestListView.as_view(), name="list"),
    path("new/", PaymentRequestCreateView.as_view(), name="create"),
    path("<int:pk>/", PaymentRequestDetailView.as_view(), name="detail"),
]
