from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path


def health_check(request):
    return JsonResponse({
        "status": "ok",
        "service": "emisiones",
    })


urlpatterns = [
    path("payment-requests/", include("apps.payment_requests.urls")),
    path("payment-approvals/", include("apps.payment_approvals.urls")),
    path("", include("apps.accounts.urls")),
    path("admin/", admin.site.urls),
    path("health/", health_check, name="health_check"),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
