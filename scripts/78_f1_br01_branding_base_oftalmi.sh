#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== F1-BR01: Branding base institucional Oftalmi para MVP Emisiones =="

echo "== Validando estructura base =="
if [ ! -d backend ]; then
  echo "ERROR: no existe directorio backend. Ejecuta desde el proyecto Apps Emisiones." >&2
  exit 1
fi

mkdir -p backend/static/css

CSS_FILE="backend/static/css/oftalmi_branding.css"
cat > "$CSS_FILE" <<'CSS'
:root {
  --oftalmi-blue: #0d6efd;
  --oftalmi-blue-dark: #172033;
  --oftalmi-blue-soft: #eaf2ff;
  --oftalmi-green: #198754;
  --oftalmi-gray-bg: #f7f7f7;
  --oftalmi-gray-border: #dee2e6;
  --oftalmi-text: #212529;
  --oftalmi-muted: #6c757d;
  --oftalmi-radius: 0.75rem;
  --oftalmi-shadow: 0 0.5rem 1.25rem rgba(23, 32, 51, 0.08);
}

body {
  background: var(--oftalmi-gray-bg);
  color: var(--oftalmi-text);
}

.oftalmi-shell {
  min-height: 100vh;
  background:
    radial-gradient(circle at top left, rgba(13, 110, 253, 0.08), transparent 34rem),
    var(--oftalmi-gray-bg);
}

.oftalmi-navbar,
.navbar.oftalmi-navbar {
  background: linear-gradient(90deg, var(--oftalmi-blue-dark), #233354);
  box-shadow: 0 0.35rem 1rem rgba(23, 32, 51, 0.18);
}

.oftalmi-navbar .navbar-brand,
.oftalmi-navbar .nav-link,
.oftalmi-navbar .navbar-text {
  color: #ffffff !important;
}

.oftalmi-navbar .nav-link {
  opacity: 0.88;
  border-radius: 999px;
  padding-left: 0.85rem;
  padding-right: 0.85rem;
}

.oftalmi-navbar .nav-link:hover,
.oftalmi-navbar .nav-link:focus,
.oftalmi-navbar .nav-link.active {
  background: rgba(255, 255, 255, 0.14);
  opacity: 1;
}

.oftalmi-brand-mark {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2rem;
  height: 2rem;
  border-radius: 50%;
  background: var(--oftalmi-blue);
  color: #ffffff;
  font-weight: 700;
  letter-spacing: -0.02em;
  margin-right: 0.5rem;
}

.oftalmi-page-header {
  background: #ffffff;
  border: 1px solid var(--oftalmi-gray-border);
  border-left: 0.35rem solid var(--oftalmi-blue);
  border-radius: var(--oftalmi-radius);
  box-shadow: var(--oftalmi-shadow);
  padding: 1.25rem 1.5rem;
  margin-bottom: 1.5rem;
}

.oftalmi-page-header h1,
.oftalmi-page-header h2,
.oftalmi-page-header h3 {
  color: var(--oftalmi-blue-dark);
  margin-bottom: 0.35rem;
}

.oftalmi-page-header p {
  color: var(--oftalmi-muted);
  margin-bottom: 0;
}

.card,
.oftalmi-card {
  border: 1px solid var(--oftalmi-gray-border);
  border-radius: var(--oftalmi-radius);
  box-shadow: var(--oftalmi-shadow);
}

.card-header,
.oftalmi-card-header {
  background: #ffffff;
  border-bottom: 1px solid var(--oftalmi-gray-border);
  color: var(--oftalmi-blue-dark);
  font-weight: 700;
}

.table {
  --bs-table-bg: #ffffff;
  border-color: var(--oftalmi-gray-border);
}

.table thead th {
  background: var(--oftalmi-blue-soft);
  color: var(--oftalmi-blue-dark);
  border-bottom: 1px solid var(--oftalmi-gray-border);
  font-size: 0.86rem;
  text-transform: uppercase;
  letter-spacing: 0.035em;
}

.table tbody tr:hover {
  background: rgba(13, 110, 253, 0.045);
}

.btn-primary {
  background-color: var(--oftalmi-blue);
  border-color: var(--oftalmi-blue);
}

.btn-primary:hover,
.btn-primary:focus {
  background-color: #0b5ed7;
  border-color: #0a58ca;
}

.btn-success {
  background-color: var(--oftalmi-green);
  border-color: var(--oftalmi-green);
}

.badge.bg-primary,
.badge.text-bg-primary {
  background-color: var(--oftalmi-blue) !important;
}

.badge.bg-success,
.badge.text-bg-success {
  background-color: var(--oftalmi-green) !important;
}

.alert {
  border-radius: var(--oftalmi-radius);
  box-shadow: 0 0.35rem 0.9rem rgba(23, 32, 51, 0.05);
}

.form-control,
.form-select {
  border-radius: 0.6rem;
}

.form-control:focus,
.form-select:focus {
  border-color: rgba(13, 110, 253, 0.55);
  box-shadow: 0 0 0 0.2rem rgba(13, 110, 253, 0.15);
}

.oftalmi-kpi {
  border-left: 0.3rem solid var(--oftalmi-blue);
}

.oftalmi-kpi .kpi-value {
  color: var(--oftalmi-blue-dark);
  font-size: 1.75rem;
  font-weight: 800;
}

.oftalmi-kpi .kpi-label {
  color: var(--oftalmi-muted);
  font-size: 0.9rem;
  text-transform: uppercase;
  letter-spacing: 0.035em;
}

footer.oftalmi-footer {
  color: var(--oftalmi-muted);
  font-size: 0.85rem;
  padding: 1.5rem 0;
}
CSS

echo "OK: creado $CSS_FILE"

python3 - <<'PY'
from pathlib import Path

candidates = [
    Path("backend/templates/base.html"),
    Path("backend/templates/base_site.html"),
    Path("backend/templates/layout.html"),
]

base = next((p for p in candidates if p.exists()), None)
if not base:
    print("WARN: no se encontro template base conocido. CSS creado, pero no fue enlazado automaticamente.")
    raise SystemExit(0)

text = base.read_text(encoding="utf-8")
original = text

if "oftalmi_branding.css" not in text:
    static_loaders = ["{% load static %}", "{% load static i18n %}"]
    if "{% load static" not in text:
        text = "{% load static %}\n" + text

    link = '<link rel="stylesheet" href="{% static \'css/oftalmi_branding.css\' %}">'
    if "</head>" in text:
        text = text.replace("</head>", f"    {link}\n</head>", 1)
    else:
        print(f"WARN: {base} no tiene </head>. No se pudo insertar link CSS automaticamente.")

# Clase visual al body, sin romper clases existentes.
if "oftalmi-shell" not in text:
    text = text.replace("<body>", '<body class="oftalmi-shell">', 1)
    text = text.replace('<body class="', '<body class="oftalmi-shell ', 1) if '<body class="' in text and 'oftalmi-shell' not in text else text

# Navbar institucional si existe navbar Bootstrap sin clase institucional.
if "oftalmi-navbar" not in text and "navbar" in text:
    text = text.replace('class="navbar ', 'class="navbar oftalmi-navbar ', 1)
    text = text.replace("class='navbar ", "class='navbar oftalmi-navbar ", 1)

# Marca institucional conservadora.
if "Apps Emisiones" in text and "oftalmi-brand-mark" not in text:
    text = text.replace(
        "Apps Emisiones",
        '<span class="oftalmi-brand-mark">O</span>Apps Emisiones',
        1,
    )

if text != original:
    base.write_text(text, encoding="utf-8")
    print(f"OK: actualizado template base {base}")
else:
    print(f"OK: template base sin cambios necesarios {base}")
PY

DOC_FILE="docs/f1_br01_branding_base_oftalmi.md"
mkdir -p docs
cat > "$DOC_FILE" <<'MD'
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
MD

echo "OK: creado $DOC_FILE"

echo "== Git diff resumido =="
git status --short || true

echo "== F1-BR01 generado. Ejecuta validaciones antes de commit. =="
