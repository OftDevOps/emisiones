from django.contrib import admin

from .models import Area, Company, Department, Management, OrganizationalUnit


@admin.register(Company)
class CompanyAdmin(admin.ModelAdmin):
    list_display = ("name", "rif", "code", "is_active")
    search_fields = ("name", "rif", "code")
    list_filter = ("is_active",)


@admin.register(Management)
class ManagementAdmin(admin.ModelAdmin):
    list_display = ("name", "code", "company", "is_active")
    search_fields = ("name", "code", "company__name")
    list_filter = ("company", "is_active")


@admin.register(Area)
class AreaAdmin(admin.ModelAdmin):
    list_display = ("name", "code", "company", "management", "is_active")
    search_fields = ("name", "code", "company__name", "management__name")
    list_filter = ("company", "management", "is_active")


@admin.register(Department)
class DepartmentAdmin(admin.ModelAdmin):
    list_display = ("name", "code", "company", "area", "is_active")
    search_fields = ("name", "code", "company__name", "area__name")
    list_filter = ("company", "area", "is_active")


@admin.register(OrganizationalUnit)
class OrganizationalUnitAdmin(admin.ModelAdmin):
    list_display = ("name", "code", "company", "management", "area", "department", "is_active")
    search_fields = ("name", "code", "company__name", "department__name")
    list_filter = ("company", "management", "area", "department", "is_active")
