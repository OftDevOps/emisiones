# F1-P17 - Dashboard operativo de solicitudes

**Proyecto:** Sistema de Rutas de Pago Oftalmi  
**Fase:** Fase 1 - Núcleo operativo del MVP  
**Estado:** Completado  
**Rama de trabajo:** `feature/payment-request-dashboard`  
**Integrado a:** `develop`  

---

## 1. Objetivo

Agregar un dashboard operativo para visualizar el estado general de las solicitudes de pago y facilitar el seguimiento diario de trabajo.

---

## 2. Alcance implementado

Se agregó una vista de dashboard para solicitudes de pago.

La vista muestra:

- Total de solicitudes visibles para el usuario.
- Conteo por estado.
- Últimas solicitudes.
- Pasos pendientes de aprobación asociados al rol del usuario.
- Enlaces hacia el detalle de solicitudes.

---

## 3. Ruta funcional

Ruta agregada:

```text
/payment-requests/dashboard/
```

Nombre de URL:

```text
payment_requests:dashboard
```

---

## 4. Archivos principales modificados

```text
backend/apps/payment_requests/views.py
backend/apps/payment_requests/urls.py
backend/templates/payment_requests/paymentrequest_list.html
backend/templates/payment_requests/paymentrequest_dashboard.html
backend/apps/payment_requests/tests/test_dashboard.py
scripts/42_f1_p17_payment_request_dashboard.sh
```

---

## 5. Reglas de seguridad aplicadas

El dashboard respeta el scope de solicitudes mediante `scoped_payment_request_queryset(user)`.

Reglas aplicadas:

- El superusuario puede ver todas las solicitudes.
- Un usuario no superusuario con `primary_company_id` solo ve solicitudes de su empresa.
- Un usuario no superusuario sin empresa asociada no ve solicitudes.
- Los pendientes de aprobación se filtran por:
  - empresa visible para el usuario;
  - rol requerido del paso;
  - estado pendiente del paso.

---

## 6. Validaciones ejecutadas

Validación local ejecutada:

```bash
nordvpn disconnect
sleep 3

git status
git log --oneline --max-count=5

docker compose exec backend ruff check .
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests apps.payment_documents apps.payment_approvals

nordvpn connect United_States
nordvpn status
```

Resultado registrado:

```text
Rama: feature/payment-request-dashboard
Ruff: OK
Django check: OK
Makemigrations check: OK
Migrate: OK
Tests: 61 OK
NordVPN: reconectado y activo
```

---

## 7. Observaciones

Los mensajes `Not Found` y `Forbidden` vistos durante pruebas corresponden a validaciones esperadas de rutas inexistentes y restricciones de permisos.

La señal válida de cierre fue:

```text
Ran 61 tests
OK
```

---

## 8. Relación con el documento maestro

F1-P17 apoya las reglas de Fase 1 relacionadas con:

- Bandejas de trabajo.
- Mis solicitudes.
- Pendientes por aprobar.
- Control por empresa.
- Control por rol.
- Seguimiento operativo básico.
- Validaciones mínimas de seguridad en backend.

