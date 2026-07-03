from django.contrib.auth.mixins import LoginRequiredMixin
from django.core.exceptions import PermissionDenied
from django.shortcuts import get_object_or_404, redirect
from django.views.generic import CreateView

from apps.accounts.models import UserRole
from apps.payment_requests.models import PaymentRequestStatus
from apps.payment_requests.views import scoped_payment_request_queryset

from .forms import PaymentExecutionForm
from .models import PaymentExecution


class PaymentExecutionCreateView(LoginRequiredMixin, CreateView):
    model = PaymentExecution
    form_class = PaymentExecutionForm
    template_name = "payment_execution/paymentexecution_form.html"

    def dispatch(self, request, *args, **kwargs):
        user = request.user
        if not user.is_authenticated:
            return super().dispatch(request, *args, **kwargs)
        if not user.is_superuser and user.role != UserRole.CUENTAS_POR_PAGAR:
            raise PermissionDenied("Su rol no permite registrar pagos.")
        self.payment_request = get_object_or_404(
            scoped_payment_request_queryset(user).filter(status=PaymentRequestStatus.APPROVED),
            pk=kwargs["pk"],
        )
        if hasattr(self.payment_request, "payment_execution"):
            raise PermissionDenied("Esta solicitud ya tiene una ejecucion de pago registrada.")
        return super().dispatch(request, *args, **kwargs)

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context["payment_request"] = self.payment_request
        return context

    def form_valid(self, form):
        form.instance.payment_request = self.payment_request
        form.instance.executed_by = self.request.user
        form.save()
        return redirect("payment_requests:detail", pk=self.payment_request.pk)
