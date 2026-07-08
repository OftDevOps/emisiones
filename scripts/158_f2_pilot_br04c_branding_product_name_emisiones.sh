#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$PROJECT_DIR"

echo "== F2-PILOT-BR04C: branding product name a Rutas de Emision =="
echo "== Ruta =="
pwd

echo "== Estado inicial =="
git status --short

python3 - <<'PY'
from pathlib import Path
from datetime import datetime

project = Path('/home/dchirinos/oftalmiIA/emisiones/emisiones')

files = {
    project / 'backend/config/settings/base.py': {
        'APP_PRODUCT_NAME = config("APP_PRODUCT_NAME", default="Sistema de Rutas de Pago")':
        'APP_PRODUCT_NAME = config("APP_PRODUCT_NAME", default="Sistema de Rutas de Emisión")',
        'APP_PRODUCT_SHORT_NAME = config("APP_PRODUCT_SHORT_NAME", default="Rutas de Pago")':
        'APP_PRODUCT_SHORT_NAME = config("APP_PRODUCT_SHORT_NAME", default="Rutas de Emisión")',
    },
    project / '.env.example': {
        'APP_PRODUCT_NAME=Sistema de Rutas de Pago': 'APP_PRODUCT_NAME=Sistema de Rutas de Emisión',
        'APP_PRODUCT_SHORT_NAME=Rutas de Pago': 'APP_PRODUCT_SHORT_NAME=Rutas de Emisión',
    },
}

for path, replacements in files.items():
    if not path.exists():
        print(f'WARN: no existe {path.relative_to(project)}')
        continue
    text = path.read_text(encoding='utf-8')
    original = text
    for old, new in replacements.items():
        text = text.replace(old, new)
    if text != original:
        path.write_text(text, encoding='utf-8')
        print(f'OK: actualizado {path.relative_to(project)}')
    else:
        print(f'INFO: sin cambios {path.relative_to(project)}')

# Actualizacion local de .env para que el piloto muestre el cambio sin depender del default.
# No se imprime el contenido completo para no exponer secretos.
env_path = project / '.env'
if env_path.exists():
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup = project / f'.env.br04c_backup_{timestamp}'
    backup.write_text(env_path.read_text(encoding='utf-8'), encoding='utf-8')

    lines = env_path.read_text(encoding='utf-8').splitlines()
    desired = {
        'APP_PRODUCT_NAME': 'Sistema de Rutas de Emisión',
        'APP_PRODUCT_SHORT_NAME': 'Rutas de Emisión',
    }
    seen = set()
    new_lines = []
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith('#') or '=' not in line:
            new_lines.append(line)
            continue
        key = line.split('=', 1)[0].strip()
        if key in desired:
            new_lines.append(f'{key}={desired[key]}')
            seen.add(key)
        else:
            new_lines.append(line)

    for key, value in desired.items():
        if key not in seen:
            new_lines.append(f'{key}={value}')

    env_path.write_text('\n'.join(new_lines) + '\n', encoding='utf-8')
    print(f'OK: .env local actualizado; backup creado: {backup.name}')
else:
    print('WARN: no existe .env local; solo se actualizaron defaults y .env.example')
PY

echo "== Valores branding versionables =="
grep -RniI "APP_PRODUCT_NAME\|APP_PRODUCT_SHORT_NAME" backend/config/settings/base.py .env.example

echo "== Valores branding locales seguros =="
if [ -f .env ]; then
  grep -n "^APP_PRODUCT_NAME=\|^APP_PRODUCT_SHORT_NAME=" .env || true
else
  echo "WARN: .env no existe"
fi

echo "== Busqueda backend pendiente de Rutas de Pago en fuentes de branding =="
grep -RniI \
  "Sistema de Rutas de Pago\|Rutas de Pago\|Rutas de Pagos" \
  backend/templates backend/apps/accounts backend/config .env.example \
  || true

echo "== Validacion diff whitespace =="
git diff --check

echo "== Ruff =="
docker compose exec backend ruff check .

echo "== Django check antes de recrear backend =="
docker compose exec backend python manage.py check

echo "== Recreate backend para recargar .env/settings =="
docker compose up -d --force-recreate backend
sleep 5

echo "== Django settings branding dentro del contenedor =="
docker compose exec backend python manage.py shell -c "
from django.conf import settings
print('APP_PRODUCT_NAME=', settings.APP_PRODUCT_NAME)
print('APP_PRODUCT_SHORT_NAME=', settings.APP_PRODUCT_SHORT_NAME)
"

echo "== HTTP smoke =="
for url in \
  http://127.0.0.1:8001/login/ \
  http://127.0.0.1:8001/static/css/oftalmi_branding.css; do
  code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 5 "$url" || true)
  echo "$url -> HTTP $code"
  if [ "$code" != "200" ]; then
    echo "ERROR: $url no respondio 200"
    exit 1
  fi
done

echo "== Estado final =="
git status --short

echo "== FIN F2-PILOT-BR04C branding product name =="
