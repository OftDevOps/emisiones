from django.contrib import messages
from django.contrib.auth.mixins import LoginRequiredMixin
from django.core.exceptions import PermissionDenied, ValidationError
from django.shortcuts import get_object_or_404, redirect
from django.views.generic import ListView, View
from .models import ApprovalActionType
from apps.payment_approvals.models import ApprovalStepStatus, PaymentApprovalStep

from .forms import ApprovalActionForm



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
