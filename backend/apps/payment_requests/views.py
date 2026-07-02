from django.contrib.auth.mixins import LoginRequiredMixin
from django.urls import reverse_lazy
from django.views.generic import CreateView, DetailView, ListView

from .forms import PaymentRequestCreateForm
from .models import PaymentRequest


class PaymentRequestListView(LoginRequiredMixin, ListView):
    model = PaymentRequest
    template_name = "payment_requests/paymentrequest_list.html"
    context_object_name = "payment_requests"
    paginate_by = 20

    def get_queryset(self):
        queryset = (
            PaymentRequest.objects.select_related("company", "beneficiary", "requested_by")
            .order_by("-created_at")
        )
        user = self.request.user

        if not user.is_superuser and getattr(user, "primary_company_id", None):
            queryset = queryset.filter(company=user.primary_company)

        return queryset


class PaymentRequestDetailView(LoginRequiredMixin, DetailView):
    model = PaymentRequest
    template_name = "payment_requests/paymentrequest_detail.html"
    context_object_name = "payment_request"

    def get_queryset(self):
        queryset = PaymentRequest.objects.select_related("company", "beneficiary", "requested_by")
        user = self.request.user

        if not user.is_superuser and getattr(user, "primary_company_id", None):
            queryset = queryset.filter(company=user.primary_company)

        return queryset


class PaymentRequestCreateView(LoginRequiredMixin, CreateView):
    model = PaymentRequest
    form_class = PaymentRequestCreateForm
    template_name = "payment_requests/paymentrequest_form.html"
    success_url = reverse_lazy("payment_requests:list")

    def get_form_kwargs(self):
        kwargs = super().get_form_kwargs()
        kwargs["user"] = self.request.user
        return kwargs

    def form_valid(self, form):
        form.instance.requested_by = self.request.user
        return super().form_valid(form)
