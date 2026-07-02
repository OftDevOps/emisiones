#!/usr/bin/env bash
set -euo pipefail

required_files=(
  ".env"
  "docker-compose.yml"
  "backend/manage.py"
  "backend/config/settings/base.py"
)

for file in "${required_files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "ERROR: falta $file" >&2
    exit 1
  fi
  echo "OK: $file"
done

echo "Validacion basica completada."
