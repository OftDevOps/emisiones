#!/usr/bin/env bash
set -euo pipefail

EXPECTED_BRANCH="feature/payment-execution-basic"

echo "== F1-P21: Registro basico de ejecucion de pago =="

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "ERROR: este directorio no parece ser un repositorio Git."
  exit 1
fi

cd "$(git rev-parse --show-toplevel)"

CURRENT_BRANCH="$(git branch --show-current)"
if [ "$CURRENT_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ERROR: rama incorrecta."
  echo "Actual:   $CURRENT_BRANCH"
  echo "Esperada: $EXPECTED_BRANCH"
  echo
  echo "Crea la rama con:"
  echo "  git switch develop"
  echo "  git pull origin develop"
  echo "  git switch -c $EXPECTED_BRANCH"
  exit 1
fi

echo "== Git status antes de aplicar cambios =="
git status --short

python3 - <<'PY'
from pathlib import Path

# ---------- helpers ----------

def add_app_to_settings():
    for path in Path("backend").rglob("*.py"):
        if "__pycache__" in path.parts:
            continue
        text = path.read_text(errors="ignore")
        if "INSTALLED_APPS" not in text or "apps.payment_requests" not in text:
            continue
        if "apps.payment_execution" in text:
            return
        for anchor in [
            '"apps.payment_documents",', "'apps.payment_documents',",
            '"apps.payment_approvals",', "'apps.payment_approvals',",
            '"apps.payment_requests",', "'apps.payment_requests',",
        ]:
            if anchor in text:
                path.write_text(text.replace(anchor, anchor + '\n    "apps.payment_execution",', 1))
                print(f"OK: apps.payment_execution agregado a {path}")
                return
        raise SystemExit(f"ERROR: no se pudo insertar apps.payment_execution en {path}")
    print("WARN: no se encontro settings con INSTALLED_APPS; verifica app instalada manualmente.")


def write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)

# ---------- paths ----------

pr_models = Path("backend/apps/payment_requests/models.py")
pr_views = Path("backend/apps/payment_requests/views.py")
pr_urls = Path("backend/apps/payment_requests/urls.py")
pr_mig = Path("backend/apps/payment_requests/migrations/0004_paymentrequest_paid_status.py")
ap_template = Path("backend/templates/payment_requests/accounts_payable_pending.html")

exec_dir = Path("backend/apps/payment_execution")
exec_mig_dir = exec_dir / "migrations"
exec_tests_dir = exec_dir / "tests"
exec_template_dir = Path("backend/templates/payment_execution")

for path in [pr_models, pr_views, pr_urls, ap_template]:
    if not path.exists():
        raise SystemExit(f"ERROR: no existe {path}")

for path in [exec_dir, exec_mig_dir, exec_tests_dir, exec_template_dir]:
    path.mkdir(parents=True, exist_ok=True)
for path in [exec_dir/"__init__.py", exec_mig_dir/"__init__.py", exec_tests_dir/"__init__.py"]:
    path.touch(exist_ok=True)

add_app_to_settings()

# ---------- PaymentRequestStatus.PAID ----------

text = pr_models.read_text()
if 'PAID = "PAID", "Pagada"' not in text:
    text = text.replace('    APPROVED = "APPROVED", "Aprobada"\n', '    APPROVED = "APPROVED", "Aprobada"\n    PAID = "PAID", "Pagada"\n', 1)
pr_models.write_text(text)

# ---------- app files ----------

write(exec_dir/"apps.py", '''from django.apps import AppConfig\n\n\nclass PaymentExecutionConfig(AppConfig):\n    default_auto_field = "django.db.models.BigAutoField"\n    name = "apps.payment_execution"\n    verbose_name = "ejecucion de pagos"\n''')

write(exec_dir/"models.py", '''from decimal import Decimal\n\nfrom django.conf import settings\nfrom django.core.exceptions import ValidationError\nfrom django.db import models\n\nfrom apps.payment_requests.models import PaymentRequest, PaymentRequestStatus\n\n\nclass PaymentExecution(models.Model):\n    payment_request = models.OneToOneField(\n        PaymentRequest,\n        on_delete=models.PROTECT,\n        related_name="payment_execution",\n        verbose_name="solicitud de pago",\n    )\n    executed_by = models.ForeignKey(\n        settings.AUTH_USER_MODEL,\n        on_delete=models.PROTECT,\n        related_name="payment_executions",\n        verbose_name="ejecutado por",\n    )\n    paid_at = models.DateField(verbose_name="fecha de pago")\n    paid_amount = models.DecimalField(max_digits=18, decimal_places=2, verbose_name="monto pagado")\n    bank_reference = models.CharField(max_length=120, verbose_name="referencia bancaria")\n    note = models.TextField(blank=True, verbose_name="observacion")\n    created_at = models.DateTimeField(auto_now_add=True, verbose_name="creado")\n    updated_at = models.DateTimeField(auto_now=True, verbose_name="actualizado")\n\n    class Meta:\n        ordering = ["-paid_at", "-created_at", "-id"]\n        verbose_name = "ejecucion de pago"\n        verbose_name_plural = "ejecuciones de pago"\n        indexes = [\n            models.Index(fields=["paid_at"], name="payexec_paid_at_idx"),\n            models.Index(fields=["bank_reference"], name="payexec_bank_ref_idx"),\n        ]\n\n    def clean(self):\n        super().clean()\n        if self.paid_amount is not None and self.paid_amount <= Decimal("0"):\n            raise ValidationError({"paid_amount": "El monto pagado debe ser mayor que cero."})\n        if not self.pk and self.payment_request_id and self.payment_request.status != PaymentRequestStatus.APPROVED:\n            raise ValidationError("Solo solicitudes aprobadas pueden registrarse como pagadas.")\n\n    def save(self, *args, **kwargs):\n        self.full_clean()\n        result = super().save(*args, **kwargs)\n        if self.payment_request.status != PaymentRequestStatus.PAID:\n            self.payment_request.status = PaymentRequestStatus.PAID\n            self.payment_request.save(update_fields=["status", "updated_at"])\n        return result\n\n    def __str__(self) -> str:\n        return f"{self.payment_request_id} - {self.paid_amount} - {self.bank_reference}"\n''')

write(exec_dir/"forms.py", '''from django import forms\n\nfrom .models import PaymentExecution\n\n\nclass PaymentExecutionForm(forms.ModelForm):\n    class Meta:\n        model = PaymentExecution\n        fields = ["paid_at", "paid_amount", "bank_reference", "note"]\n        widgets = {\n            "paid_at": forms.DateInput(attrs={"type": "date"}),\n            "note": forms.Textarea(attrs={"rows": 3}),\n        }\n''')

write(exec_dir/"admin.py", '''from django.contrib import admin\n\nfrom .models import PaymentExecution\n\n\n@admin.register(PaymentExecution)\nclass PaymentExecutionAdmin(admin.ModelAdmin):\n    list_display = ("id", "payment_request", "paid_at", "paid_amount", "bank_reference", "executed_by", "created_at")\n    list_filter = ("paid_at", "created_at")\n    search_fields = ("bank_reference", "payment_request__concept", "executed_by__email")\n    readonly_fields = ("created_at", "updated_at")\n''')

write(exec_dir/"views.py", '''from django.contrib.auth.mixins import LoginRequiredMixin\nfrom django.core.exceptions import PermissionDenied\nfrom django.shortcuts import get_object_or_404, redirect\nfrom django.views.generic import CreateView\n\nfrom apps.accounts.models import UserRole\nfrom apps.payment_requests.models import PaymentRequestStatus\nfrom apps.payment_requests.views import scoped_payment_request_queryset\n\nfrom .forms import PaymentExecutionForm\nfrom .models import PaymentExecution\n\n\nclass PaymentExecutionCreateView(LoginRequiredMixin, CreateView):\n    model = PaymentExecution\n    form_class = PaymentExecutionForm\n    template_name = "payment_execution/paymentexecution_form.html"\n\n    def dispatch(self, request, *args, **kwargs):\n        user = request.user\n        if not user.is_authenticated:\n            return super().dispatch(request, *args, **kwargs)\n        if not user.is_superuser and user.role != UserRole.CUENTAS_POR_PAGAR:\n            raise PermissionDenied("Su rol no permite registrar pagos.")\n        self.payment_request = get_object_or_404(\n            scoped_payment_request_queryset(user).filter(status=PaymentRequestStatus.APPROVED),\n            pk=kwargs["pk"],\n        )\n        if hasattr(self.payment_request, "payment_execution"):\n            raise PermissionDenied("Esta solicitud ya tiene una ejecucion de pago registrada.")\n        return super().dispatch(request, *args, **kwargs)\n\n    def get_context_data(self, **kwargs):\n        context = super().get_context_data(**kwargs)\n        context["payment_request"] = self.payment_request\n        return context\n\n    def form_valid(self, form):\n        form.instance.payment_request = self.payment_request\n        form.instance.executed_by = self.request.user\n        form.save()\n        return redirect("payment_requests:detail", pk=self.payment_request.pk)\n''')

# ---------- migrations ----------

write(pr_mig, '''# Generated by F1-P21 payment execution basic.\n\nfrom django.db import migrations, models\n\n\nclass Migration(migrations.Migration):\n\n    dependencies = [\n        ("payment_requests", "0003_alter_paymentrequest_status"),\n    ]\n\n    operations = [\n        migrations.AlterField(\n            model_name="paymentrequest",\n            name="status",\n            field=models.CharField(\n                choices=[\n                    ("DRAFT", "Borrador"),\n                    ("SUBMITTED", "Enviada"),\n                    ("UNIT_REVIEW", "Revision unidad"),\n                    ("FINANCE_REVIEW", "Revision finanzas"),\n                    ("MANAGEMENT_REVIEW", "Revision gerencia"),\n                    ("APPROVED", "Aprobada"),\n                    ("PAID", "Pagada"),\n                    ("REJECTED", "Rechazada"),\n                    ("CANCELLED", "Cancelada"),\n                ],\n                default="DRAFT",\n                max_length=20,\n                verbose_name="estado",\n            ),\n        ),\n    ]\n''')

write(exec_mig_dir/"0001_initial.py", '''# Generated by F1-P21 payment execution basic.\n\nimport django.db.models.deletion\nfrom django.conf import settings\nfrom django.db import migrations, models\n\n\nclass Migration(migrations.Migration):\n\n    initial = True\n\n    dependencies = [\n        migrations.swappable_dependency(settings.AUTH_USER_MODEL),\n        ("payment_requests", "0004_paymentrequest_paid_status"),\n    ]\n\n    operations = [\n        migrations.CreateModel(\n            name="PaymentExecution",\n            fields=[\n                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),\n                ("paid_at", models.DateField(verbose_name="fecha de pago")),\n                ("paid_amount", models.DecimalField(decimal_places=2, max_digits=18, verbose_name="monto pagado")),\n                ("bank_reference", models.CharField(max_length=120, verbose_name="referencia bancaria")),\n                ("note", models.TextField(blank=True, verbose_name="observacion")),\n                ("created_at", models.DateTimeField(auto_now_add=True, verbose_name="creado")),\n                ("updated_at", models.DateTimeField(auto_now=True, verbose_name="actualizado")),\n                ("executed_by", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="payment_executions", to=settings.AUTH_USER_MODEL, verbose_name="ejecutado por")),\n                ("payment_request", models.OneToOneField(on_delete=django.db.models.deletion.PROTECT, related_name="payment_execution", to="payment_requests.paymentrequest", verbose_name="solicitud de pago")),\n            ],\n            options={\n                "verbose_name": "ejecucion de pago",\n                "verbose_name_plural": "ejecuciones de pago",\n                "ordering": ["-paid_at", "-created_at", "-id"],\n                "indexes": [\n                    models.Index(fields=["paid_at"], name="payexec_paid_at_idx"),\n                    models.Index(fields=["bank_reference"], name="payexec_bank_ref_idx"),\n                ],\n            },\n        ),\n    ]\n''')

# ---------- urls and workbench ----------

urls = pr_urls.read_text()
if "from apps.payment_execution.views import PaymentExecutionCreateView" not in urls:
    urls = "from apps.payment_execution.views import PaymentExecutionCreateView\n" + urls
route = '    path("<int:pk>/execute-payment/", PaymentExecutionCreateView.as_view(), name="execute_payment"),\n'
if route not in urls:
    detail = '    path("<int:pk>/", PaymentRequestDetailView.as_view(), name="detail"),\n'
    urls = urls.replace(detail, route + detail, 1) if detail in urls else urls.replace("urlpatterns = [\n", "urlpatterns = [\n" + route, 1)
pr_urls.write_text(urls)

views = pr_views.read_text()
old = '''        return scoped_payment_request_queryset(self.request.user).filter(\n            status=PaymentRequestStatus.APPROVED,\n        ).order_by("due_date", "-updated_at", "-created_at")\n'''
new = '''        return scoped_payment_request_queryset(self.request.user).filter(\n            status=PaymentRequestStatus.APPROVED,\n            payment_execution__isnull=True,\n        ).order_by("due_date", "-updated_at", "-created_at")\n'''
if old in views:
    views = views.replace(old, new, 1)
pr_views.write_text(views)

acct = ap_template.read_text()
if "payment_requests:execute_payment" not in acct:
    acct = acct.replace(
        '<td><a href="{% url \'payment_requests:detail\' payment_request.pk %}">Ver solicitud</a></td>',
        '<td><a href="{% url \'payment_requests:detail\' payment_request.pk %}">Ver solicitud</a> | <a href="{% url \'payment_requests:execute_payment\' payment_request.pk %}">Registrar pago</a></td>',
        1,
    )
ap_template.write_text(acct)

# ---------- template ----------
extends_line = '{% extends "base.html" %}'
for candidate in [ap_template, Path("backend/templates/payment_requests/paymentrequest_detail.html")]:
    if candidate.exists():
        for line in candidate.read_text().splitlines():
            if line.strip().startswith("{% extends "):
                extends_line = line.strip()
                break
        break

write(exec_template_dir/"paymentexecution_form.html", f'''{extends_line}\n\n{{% block content %}}\n<h1>Registrar ejecucion de pago</h1>\n\n<section>\n  <h2>Solicitud #{{{{ payment_request.id }}}}</h2>\n  <p><strong>Empresa:</strong> {{{{ payment_request.company }}}}</p>\n  <p><strong>Beneficiario:</strong> {{{{ payment_request.beneficiary }}}}</p>\n  <p><strong>Concepto:</strong> {{{{ payment_request.concept }}}}</p>\n  <p><strong>Monto solicitado:</strong> {{{{ payment_request.amount }}}} {{{{ payment_request.currency }}}}</p>\n</section>\n\n<form method="post">\n  {{% csrf_token %}}\n  {{{{ form.as_p }}}}\n  <button type="submit">Registrar pago</button>\n</form>\n\n<p><a href="{{% url 'payment_requests:accounts_payable' %}}">Volver a Cuentas por Pagar</a></p>\n{{% endblock %}}\n''')

# ---------- tests ----------

write(exec_tests_dir/"test_views.py", '''from datetime import date\nfrom decimal import Decimal\n\nfrom django.apps import apps\nfrom django.contrib.auth import get_user_model\nfrom django.test import TestCase\nfrom django.urls import reverse\n\nfrom apps.accounts.models import UserRole\nfrom apps.payment_execution.models import PaymentExecution\nfrom apps.payment_requests.models import PaymentRequest, PaymentRequestStatus\n\n\n_counter = 0\n\n\ndef unique(prefix):\n    global _counter\n    _counter += 1\n    return f"{prefix}-{_counter}"\n\n\ndef required_data(model, **overrides):\n    data = dict(overrides)\n    for field in model._meta.concrete_fields:\n        if field.name in data or field.primary_key or field.auto_created:\n            continue\n        if getattr(field, "auto_now", False) or getattr(field, "auto_now_add", False):\n            continue\n        if field.has_default() or field.null or field.blank:\n            continue\n        kind = field.get_internal_type()\n        if kind in {"CharField", "TextField", "SlugField"}:\n            value = unique(field.name)\n            data[field.name] = value[: field.max_length] if getattr(field, "max_length", None) else value\n        elif kind == "EmailField":\n            data[field.name] = f"{unique('user')}@example.com"\n        elif kind == "DecimalField":\n            data[field.name] = Decimal("100.00")\n        elif kind in {"IntegerField", "PositiveIntegerField", "PositiveSmallIntegerField"}:\n            data[field.name] = 1\n        elif kind == "BooleanField":\n            data[field.name] = False\n        elif kind == "DateField":\n            data[field.name] = date.today()\n    return data\n\n\ndef create_model(label, **overrides):\n    app_label, model_name = label.split(".")\n    model = apps.get_model(app_label, model_name)\n    return model.objects.create(**required_data(model, **overrides))\n\n\nclass PaymentExecutionCreateViewTests(TestCase):\n    def setUp(self):\n        self.company = create_model("organization.Company")\n        self.other_company = create_model("organization.Company")\n        self.beneficiary = create_model("beneficiaries.Beneficiary", company=self.company)\n        self.other_beneficiary = create_model("beneficiaries.Beneficiary", company=self.other_company)\n        self.cxp_user = self.create_user("cxp@example.com", self.company, UserRole.CUENTAS_POR_PAGAR)\n        self.finance_user = self.create_user("finanzas@example.com", self.company, UserRole.FINANZAS)\n        self.other_cxp_user = self.create_user("otra-cxp@example.com", self.other_company, UserRole.CUENTAS_POR_PAGAR)\n        self.payment_request = self.create_request(self.company, self.beneficiary, self.finance_user, PaymentRequestStatus.APPROVED, "Pago listo para ejecutar")\n        self.url = reverse("payment_requests:execute_payment", kwargs={"pk": self.payment_request.pk})\n\n    def create_user(self, email, company, role):\n        user_model = get_user_model()\n        try:\n            return user_model.objects.create_user(email=email, password="test-pass-123", primary_company=company, role=role)\n        except TypeError:\n            user = user_model(email=email, primary_company=company, role=role)\n            user.set_password("test-pass-123")\n            user.save()\n            return user\n\n    def create_request(self, company, beneficiary, user, status, concept):\n        return PaymentRequest.objects.create(company=company, beneficiary=beneficiary, requested_by=user, amount=Decimal("150.00"), currency="VES", concept=concept, due_date=date.today(), status=status)\n\n    def post_data(self):\n        return {"paid_at": date.today().isoformat(), "paid_amount": "150.00", "bank_reference": "REF-12345", "note": "Pago ejecutado desde prueba."}\n\n    def test_requires_login(self):\n        response = self.client.get(self.url)\n        self.assertEqual(response.status_code, 302)\n\n    def test_accounts_payable_user_can_register_payment_execution(self):\n        self.client.force_login(self.cxp_user)\n        response = self.client.post(self.url, self.post_data())\n        self.assertEqual(response.status_code, 302)\n        execution = PaymentExecution.objects.get(payment_request=self.payment_request)\n        self.assertEqual(execution.executed_by, self.cxp_user)\n        self.payment_request.refresh_from_db()\n        self.assertEqual(self.payment_request.status, PaymentRequestStatus.PAID)\n\n    def test_non_accounts_payable_user_cannot_register_payment_execution(self):\n        self.client.force_login(self.finance_user)\n        response = self.client.post(self.url, self.post_data())\n        self.assertEqual(response.status_code, 403)\n        self.assertFalse(PaymentExecution.objects.filter(payment_request=self.payment_request).exists())\n\n    def test_cannot_execute_request_from_other_company(self):\n        other_request = self.create_request(self.other_company, self.other_beneficiary, self.other_cxp_user, PaymentRequestStatus.APPROVED, "Pago otra empresa")\n        url = reverse("payment_requests:execute_payment", kwargs={"pk": other_request.pk})\n        self.client.force_login(self.cxp_user)\n        response = self.client.post(url, self.post_data())\n        self.assertEqual(response.status_code, 404)\n\n    def test_cannot_execute_non_approved_request(self):\n        draft_request = self.create_request(self.company, self.beneficiary, self.finance_user, PaymentRequestStatus.DRAFT, "Borrador no ejecutable")\n        url = reverse("payment_requests:execute_payment", kwargs={"pk": draft_request.pk})\n        self.client.force_login(self.cxp_user)\n        response = self.client.post(url, self.post_data())\n        self.assertEqual(response.status_code, 404)\n\n    def test_accounts_payable_workbench_excludes_executed_requests(self):\n        PaymentExecution.objects.create(payment_request=self.payment_request, executed_by=self.cxp_user, paid_at=date.today(), paid_amount=Decimal("150.00"), bank_reference="REF-EXECUTED")\n        visible = self.create_request(self.company, self.beneficiary, self.finance_user, PaymentRequestStatus.APPROVED, "Pago todavia pendiente")\n        self.client.force_login(self.cxp_user)\n        response = self.client.get(reverse("payment_requests:accounts_payable"))\n        self.assertEqual(list(response.context["payment_requests"]), [visible])\n        self.assertContains(response, "Pago todavia pendiente")\n        self.assertNotContains(response, "Pago listo para ejecutar")\n''')

print("OK: F1-P21 registro basico de ejecucion de pago aplicado correctamente.")
PY

echo "== Validación sintáctica Python de archivos tocados =="
python3 -m py_compile \
  backend/apps/payment_requests/models.py \
  backend/apps/payment_requests/views.py \
  backend/apps/payment_requests/urls.py \
  backend/apps/payment_execution/apps.py \
  backend/apps/payment_execution/models.py \
  backend/apps/payment_execution/forms.py \
  backend/apps/payment_execution/views.py \
  backend/apps/payment_execution/admin.py \
  backend/apps/payment_execution/tests/test_views.py

echo "== Archivos modificados/creados =="
git status --short

cat <<'NEXT'

Siguiente paso obligatorio:

nordvpn disconnect
sleep 3

git status
git log --oneline --max-count=5

docker compose exec backend ruff check .
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests apps.payment_documents apps.payment_approvals apps.payment_execution

nordvpn connect United_States
nordvpn status

Si todo está correcto:

git add backend/apps/payment_requests/models.py \
  backend/apps/payment_requests/views.py \
  backend/apps/payment_requests/urls.py \
  backend/apps/payment_requests/migrations/0004_paymentrequest_paid_status.py \
  backend/templates/payment_requests/accounts_payable_pending.html \
  backend/apps/payment_execution \
  backend/templates/payment_execution \
  scripts/49_f1_p21_payment_execution_basic.sh

git commit -m "feat: add basic payment execution registration"
git push -u origin feature/payment-execution-basic

NEXT
