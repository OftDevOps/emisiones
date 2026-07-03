from django.contrib.auth.mixins import LoginRequiredMixin
from django.core.exceptions import PermissionDenied, ValidationError
from django.db.models import Count
from django.shortcuts import get_object_or_404, redirect
from django.urls import reverse_lazy
from django.views import View
from django.views.generic import CreateView, DetailView, ListView, TemplateView
from apps.accounts.models import UserRole

from apps.payment_approvals.models import (
    ApprovalActionType,
    ApprovalStepStatus,
    PaymentApprovalAction,
    PaymentApprovalStep,
)

from .forms import PaymentRequestCreateForm
from .models import PaymentRequest, PaymentRequestStatus


def scoped_payment_request_queryset(user):
    queryset = PaymentRequest.objects.select_related("company", "beneficiary", "requested_by")

    if user.is_superuser:
        return queryset

    if getattr(user, "primary_company_id", None):
        return queryset.filter(company_id=user.primary_company_id)

    return queryset.none()


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

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        payment_request = self.object
        user = self.request.user
        approval_steps = list(payment_request.approval_steps.all().order_by("sequence"))

        for step in approval_steps:
            step.can_current_user_act = (
                step.status == "PENDING"
                and step.required_role == user.role
                and payment_request.company_id == getattr(user, "primary_company_id", None)
            )

        payment_execution = getattr(payment_request, "payment_execution", None)
        can_execute_payment = (
            payment_execution is None
            and payment_request.status == PaymentRequestStatus.APPROVED
            and (
                user.is_superuser
                or user.role == UserRole.CUENTAS_POR_PAGAR
            )
        )

        context["approval_steps"] = approval_steps
        context["approval_actions"] = payment_request.approval_actions.all().order_by("-created_at")
        context["payment_execution"] = payment_execution
        context["can_execute_payment"] = can_execute_payment
        return context




class AccountsPayablePendingView(LoginRequiredMixin, ListView):
    model = PaymentRequest
    template_name = "payment_requests/accounts_payable_pending.html"
    context_object_name = "payment_requests"
    paginate_by = 25

    def dispatch(self, request, *args, **kwargs):
        user = request.user
        if not user.is_authenticated:
            return super().dispatch(request, *args, **kwargs)

        if not user.is_superuser and user.role != UserRole.CUENTAS_POR_PAGAR:
            raise PermissionDenied("Su rol no permite acceder a Cuentas por Pagar.")

        return super().dispatch(request, *args, **kwargs)

    def get_queryset(self):
        return scoped_payment_request_queryset(self.request.user).filter(
            status=PaymentRequestStatus.APPROVED,
            payment_execution__isnull=True,
        ).order_by("due_date", "-updated_at", "-created_at")

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context["pending_payment_count"] = self.object_list.count()
        return context


class PaymentRequestDashboardView(LoginRequiredMixin, TemplateView):
    template_name = "payment_requests/paymentrequest_dashboard.html"

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        user = self.request.user
        payment_requests = scoped_payment_request_queryset(user)

        status_totals = dict(
            payment_requests.values_list("status").annotate(total=Count("id"))
        )
        status_cards = [
            {
                "code": status_code,
                "label": status_label,
                "total": status_totals.get(status_code, 0),
            }
            for status_code, status_label in PaymentRequestStatus.choices
        ]

        pending_steps = PaymentApprovalStep.objects.select_related(
            "payment_request",
            "payment_request__company",
            "payment_request__beneficiary",
        ).filter(
            status=ApprovalStepStatus.PENDING,
            required_role=user.role,
            payment_request__in=payment_requests,
        ).order_by("sequence", "-payment_request__created_at")[:10]

        context["total_requests"] = payment_requests.count()
        context["status_cards"] = status_cards
        context["latest_requests"] = payment_requests.order_by("-created_at")[:10]
        context["pending_approval_steps"] = pending_steps
        return context


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
