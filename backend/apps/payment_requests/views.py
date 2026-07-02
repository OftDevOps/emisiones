from django.contrib.auth.mixins import LoginRequiredMixin
from django.core.exceptions import ValidationError
from django.shortcuts import get_object_or_404, redirect
from django.urls import reverse_lazy
from django.views import View
from django.views.generic import CreateView, DetailView, ListView

from apps.payment_approvals.models import ApprovalActionType, PaymentApprovalAction

from .forms import PaymentRequestCreateForm
from .models import PaymentRequest, PaymentRequestStatus


def scoped_payment_request_queryset(user):
    queryset = PaymentRequest.objects.select_related("company", "beneficiary", "requested_by")

    if not user.is_superuser and getattr(user, "primary_company_id", None):
        queryset = queryset.filter(company=user.primary_company)

    return queryset


class PaymentRequestListView(LoginRequiredMixin, ListView):
    model = PaymentRequest
    template_name = "payment_requests/paymentrequest_list.html"
    context_object_name = "payment_requests"
    paginate_by = 20

    def get_queryset(self):
        return scoped_payment_request_queryset(self.request.user).order_by("-created_at")


class PaymentRequestDetailView(LoginRequiredMixin, DetailView):
    model = PaymentRequest
    template_name = "payment_requests/paymentrequest_detail.html"
    context_object_name = "payment_request"

    def get_queryset(self):
        return scoped_payment_request_queryset(self.request.user).prefetch_related(
            "approval_steps",
            "approval_actions",
        )


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


class PaymentRequestSubmitView(LoginRequiredMixin, View):
    def post(self, request, pk):
        payment_request = get_object_or_404(scoped_payment_request_queryset(request.user), pk=pk)

        try:
            payment_request.submit_for_approval(request.user)
        except ValidationError:
            pass

        return redirect("payment_requests:detail", pk=payment_request.pk)


class PaymentRequestCancelView(LoginRequiredMixin, View):
    def post(self, request, pk):
        payment_request = get_object_or_404(scoped_payment_request_queryset(request.user), pk=pk)

        if payment_request.status == PaymentRequestStatus.DRAFT:
            payment_request.status = PaymentRequestStatus.CANCELLED
            payment_request.save(update_fields=["status", "updated_at"])
            PaymentApprovalAction.objects.create(
                payment_request=payment_request,
                action=ApprovalActionType.CANCEL,
                performed_by=request.user,
                role=request.user.role,
                comment="Solicitud cancelada por el solicitante.",
            )

        return redirect("payment_requests:detail", pk=payment_request.pk)
