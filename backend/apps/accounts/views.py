from django.contrib.auth import logout
from django.contrib.auth.mixins import LoginRequiredMixin
from django.shortcuts import redirect
from django.views import View
from django.views.generic import TemplateView


class DashboardView(LoginRequiredMixin, TemplateView):
    """Vista inicial autenticada del Sistema de Rutas de Pago."""

    template_name = "accounts/dashboard.html"


class LogoutView(LoginRequiredMixin, View):
    """Cierre de sesion por POST para evitar logout accidental por enlace GET."""

    def post(self, request, *args, **kwargs):
        logout(request)
        return redirect("accounts:login")

    def get(self, request, *args, **kwargs):
        return redirect("accounts:dashboard")
