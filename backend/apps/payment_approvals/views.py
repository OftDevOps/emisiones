from apps.accounts.role_permissions import (
    user_has_permission,
)
from django.contrib import messages
from django.contrib.auth.mixins import LoginRequiredMixin
from django.core.exceptions import PermissionDenied, ValidationError
from django.shortcuts import get_object_or_404, redirect
from django.views.generic import ListView, View

from .forms import ApprovalActionForm
from .models import (
    ApprovalActionType,
    ApprovalStepStatus,
    PaymentApprovalAction,
    PaymentApprovalStep,
)


def _require_operational_permission(user, permission: str, message: str) -> None:
    if not user_has_permission(user, permission):
        raise PermissionDenied(message)


class PendingApprovalStepsView(LoginRequiredMixin, ListView):
    model = PaymentApprovalStep
    template_name = "payment_approvals/pending_approval_steps.html"
    context_object_name = "pending_steps"
    paginate_by = 25

    def get_queryset(self):
        user = self.request.user
        queryset = PaymentApprovalStep.objects.select_related(
            "payment_request",
            "payment_request__company",
            "payment_request__beneficiary",
            "payment_request__requested_by",
        ).filter(status=ApprovalStepStatus.PENDING)

        if user.is_superuser:
            return queryset.order_by("sequence", "-payment_request__created_at")

        if not getattr(user, "primary_company_id", None):
            return queryset.none()

        return queryset.filter(
            required_role=user.role,
            payment_request__company_id=user.primary_company_id,
        ).order_by("sequence", "-payment_request__created_at")

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context["pending_count"] = self.object_list.count()
        return context


class ApprovalStepActionView(LoginRequiredMixin, View):
    http_method_names = ["post"]

    def get_step(self):
        user = self.request.user
        queryset = PaymentApprovalStep.objects.select_related("payment_request", "payment_request__company")
        step = get_object_or_404(queryset, pk=self.kwargs["pk"])

        if step.payment_request.company_id != user.primary_company_id:
            raise PermissionDenied("No tiene acceso a esta solicitud.")

        if step.required_role != user.role:
            raise PermissionDenied("Su rol no permite ejecutar este paso de aprobación.")

        return step

    def post(self, request, *args, **kwargs):
        step = self.get_step()
        form = ApprovalActionForm(request.POST)
        payment_request = step.payment_request

        if not form.is_valid():
            for field_errors in form.errors.values():
                for error in field_errors:
                    messages.error(request, error)
            return redirect("payment_requests:detail", pk=payment_request.pk)

        action = form.cleaned_data["action"]
        comment = form.cleaned_data["comment"]

        try:
            if action == ApprovalActionType.APPROVE:
                step.approve(user=request.user, comment=comment)
                messages.success(request, "Paso aprobado correctamente.")
            elif action == ApprovalActionType.REJECT:
                step.reject(user=request.user, comment=comment)
                messages.success(request, "Solicitud rechazada correctamente.")
            else:
                messages.error(request, "Acción no válida.")
        except ValidationError as exc:
            if hasattr(exc, "messages"):
                for error in exc.messages:
                    messages.error(request, error)
            else:
                messages.error(request, str(exc))

        return redirect("payment_requests:detail", pk=payment_request.pk)

class CrossActionAuditWorkbenchView(LoginRequiredMixin, ListView):
    model = PaymentApprovalAction
    template_name = "payment_approvals/cross_action_audit_workbench.html"
    context_object_name = "actions"
    paginate_by = 25

    def get_queryset(self):
        user = self.request.user
        queryset = PaymentApprovalAction.objects.select_related(
            "payment_request",
            "payment_request__company",
            "payment_request__beneficiary",
            "performed_by",
            "step",
        ).order_by("-created_at", "-id")

        if not user.is_superuser:
            if not getattr(user, "primary_company_id", None):
                return queryset.none()
            queryset = queryset.filter(payment_request__company_id=user.primary_company_id)

        action = self.request.GET.get("action", "").strip()
        company = self.request.GET.get("company", "").strip()
        date_from = self.request.GET.get("date_from", "").strip()
        date_to = self.request.GET.get("date_to", "").strip()

        if action:
            queryset = queryset.filter(action=action)
        if company:
            queryset = queryset.filter(payment_request__company_id=company)
        if date_from:
            queryset = queryset.filter(created_at__date__gte=date_from)
        if date_to:
            queryset = queryset.filter(created_at__date__lte=date_to)

        return queryset

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        user = self.request.user

        actions_queryset = PaymentApprovalAction.objects.select_related("payment_request__company")
        if not user.is_superuser:
            if getattr(user, "primary_company_id", None):
                actions_queryset = actions_queryset.filter(payment_request__company_id=user.primary_company_id)
            else:
                actions_queryset = actions_queryset.none()

        companies = []
        seen_company_ids = set()
        for action in actions_queryset.order_by("payment_request__company__name"):
            company = action.payment_request.company
            if company.pk not in seen_company_ids:
                seen_company_ids.add(company.pk)
                companies.append(company)

        context["action_choices"] = ApprovalActionType.choices
        context["companies"] = companies
        context["filters"] = {
            "action": self.request.GET.get("action", "").strip(),
            "company": self.request.GET.get("company", "").strip(),
            "date_from": self.request.GET.get("date_from", "").strip(),
            "date_to": self.request.GET.get("date_to", "").strip(),
        }
        context["total_actions"] = self.object_list.count()
        return context
