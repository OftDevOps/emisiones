# F1-BR01 - Branding base institucional Oftalmi para MVP Emisiones

## Objetivo

Aplicar una capa visual institucional base al MVP de Apps Emisiones sin modificar reglas de negocio, modelos, migraciones ni flujos funcionales.

## Alcance aplicado

- CSS institucional reutilizable.
- Paleta base Oftalmi.
- Mejora visual de navegación, cards, tablas, botones, formularios, alertas y KPIs.
- Integración conservadora con el template base si existe `backend/templates/base.html`, `base_site.html` o `layout.html`.

## Fuera de alcance

- No se crean modelos.
- No se crean migraciones.
- No se cambian permisos.
- No se cambian reglas de negocio.
- No se modifica el flujo de solicitudes, aprobaciones, CxP, pagos ni auditoría.

## Archivos esperados

```text
backend/static/css/oftalmi_branding.css
docs/f1_br01_branding_base_oftalmi.md
```

Opcionalmente actualizado, si existe:

```text
backend/templates/base.html
backend/templates/base_site.html
backend/templates/layout.html
```

## Paleta base

```text
Azul institucional principal: #0d6efd
Verde acción positiva: #198754
Gris de fondo: #f7f7f7
Azul oscuro institucional: #172033
Azul claro de apoyo visual: #eaf2ff
```

## Validación funcional requerida

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

nordvpn disconnect
sleep 3

git status
git diff --check
docker compose exec backend ruff check .
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py test apps.organization apps.accounts apps.beneficiaries apps.payment_requests apps.payment_documents apps.payment_approvals apps.payment_execution

nordvpn connect United_States
nordvpn status
```

## Validación visual sugerida

Revisar manualmente:

```text
http://localhost:8001/login/
http://localhost:8001/dashboard/
http://localhost:8001/payment-requests/dashboard/
http://localhost:8001/payment-requests/
http://localhost:8001/payment-approvals/pending/
http://localhost:8001/payment-approvals/audit/
http://localhost:8001/payment-requests/accounts-payable/
```

## Criterio de aceptación

- La app conserva su comportamiento funcional.
- La identidad visual mejora sin romper navegación.
- Las tablas y cards son más legibles.
- El sistema mantiene CI verde.
- No existen migraciones pendientes.
