from django.conf import settings
from apps.accounts.role_permissions import (
    PERM_CREATE_PAYMENT_REQUEST,
    PERM_VIEW_ACCOUNTS_PAYABLE,
    PERM_VIEW_AUDIT_WORKBENCH,
    PERM_VIEW_PAYMENT_REQUEST_DASHBOARD,
    PERM_VIEW_PAYMENT_REQUESTS,
    PERM_VIEW_PAYMENT_REQUEST_REPORT,
    PERM_VIEW_PENDING_APPROVALS,
    user_has_permission,
)


def role_navigation(request):
    """Expose role-aware navigation flags to templates.

    Backend permissions remain authoritative. These flags only prevent
    showing links that the current user cannot use.
    """

    user = getattr(request, "user", None)

    nav_permissions = {
        "can_view_payment_dashboard": user_has_permission(user, PERM_VIEW_PAYMENT_REQUEST_DASHBOARD),
        "can_view_payment_requests": user_has_permission(user, PERM_VIEW_PAYMENT_REQUESTS),
        "can_create_payment_request": user_has_permission(user, PERM_CREATE_PAYMENT_REQUEST),
        "can_view_pending_approvals": user_has_permission(user, PERM_VIEW_PENDING_APPROVALS),
        "can_view_audit_workbench": user_has_permission(user, PERM_VIEW_AUDIT_WORKBENCH),
        "can_view_accounts_payable": user_has_permission(user, PERM_VIEW_ACCOUNTS_PAYABLE),
            "can_view_payment_request_report": user_has_permission(user, PERM_VIEW_PAYMENT_REQUEST_REPORT),
    }

    return {"role_nav": nav_permissions}



def app_branding(request):
    """Expose company/app branding parameters to templates.

    This keeps the UI reusable for separate deployments per company
    without hardcoding visual identity in templates.
    """

    return {
        "app_branding": {
            "company_name": settings.APP_COMPANY_NAME,
            "company_short_name": settings.APP_COMPANY_SHORT_NAME,
            "product_name": settings.APP_PRODUCT_NAME,
            "product_short_name": settings.APP_PRODUCT_SHORT_NAME,
            "primary": settings.APP_BRAND_PRIMARY,
            "secondary": settings.APP_BRAND_SECONDARY,
            "accent": settings.APP_BRAND_ACCENT,
            "info": settings.APP_BRAND_INFO,
            "logo_path": settings.APP_BRAND_LOGO,
            "favicon_path": settings.APP_BRAND_FAVICON,
            "capsule_enabled": settings.APP_BRAND_CAPSULE_ENABLED,
        }
    }
