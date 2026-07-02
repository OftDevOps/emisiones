from django.contrib.auth.views import LoginView
from django.urls import path
from django.views.generic import RedirectView

from .views import DashboardView, LogoutView

app_name = "accounts"

urlpatterns = [
    path("", RedirectView.as_view(pattern_name="accounts:dashboard", permanent=False), name="home"),
    path(
        "login/",
        LoginView.as_view(
            template_name="registration/login.html",
            redirect_authenticated_user=True,
        ),
        name="login",
    ),
    path("logout/", LogoutView.as_view(), name="logout"),
    path("dashboard/", DashboardView.as_view(), name="dashboard"),
]
