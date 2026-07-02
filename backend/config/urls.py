from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path


def health_check(request):
    return JsonResponse({
        "status": "ok",
        "service": "emisiones",
    })


urlpatterns = [
    path("", include("apps.accounts.urls")),
    path("admin/", admin.site.urls),
    path("health/", health_check, name="health_check"),
]
