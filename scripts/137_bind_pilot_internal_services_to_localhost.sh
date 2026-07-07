#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
COMPOSE_FILE="docker-compose.yml"
BACKUP_SUFFIX="$(date +%Y%m%d_%H%M%S)"

cd "$PROJECT_DIR"

echo "== 137 - Bind pilot internal services to localhost =="
echo "Project: $PROJECT_DIR"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S %z')"

echo
echo "== Git baseline =="
git status --short
git branch --show-current
git log --oneline --max-count=5 --decorate

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "FAIL: $COMPOSE_FILE not found"
  exit 1
fi

echo
echo "== Current exposed service ports =="
docker compose ps || true

echo
echo "== Creating compose backup =="
cp "$COMPOSE_FILE" "${COMPOSE_FILE}.bak.${BACKUP_SUFFIX}"
echo "BACKUP: ${COMPOSE_FILE}.bak.${BACKUP_SUFFIX}"

echo
echo "== Applying localhost bind for db and redis published ports =="
python3 - <<'PY'
from pathlib import Path

path = Path("docker-compose.yml")
text = path.read_text(encoding="utf-8")
original = text

replacements = {
    '"5434:5432"': '"127.0.0.1:5434:5432"',
    "'5434:5432'": "'127.0.0.1:5434:5432'",
    "- 5434:5432": "- 127.0.0.1:5434:5432",
    '"6381:6379"': '"127.0.0.1:6381:6379"',
    "'6381:6379'": "'127.0.0.1:6381:6379'",
    "- 6381:6379": "- 127.0.0.1:6381:6379",
}

for old, new in replacements.items():
    text = text.replace(old, new)

if text == original:
    raise SystemExit("FAIL: no expected db/redis port mappings were changed in docker-compose.yml")

path.write_text(text, encoding="utf-8")
PY

echo
echo "== Diff summary =="
git diff -- docker-compose.yml

echo
echo "== Docker compose config validation =="
docker compose config >/tmp/emisiones_compose_config_137.txt

grep -nE 'host_ip: 127.0.0.1|published: "5434"|published: "6381"|published: "8001"' /tmp/emisiones_compose_config_137.txt || true

if ! grep -A8 -n '^  db:' /tmp/emisiones_compose_config_137.txt | grep -q 'host_ip: 127.0.0.1'; then
  echo "FAIL: db published port is not bound to 127.0.0.1 in resolved compose config"
  exit 1
fi

if ! grep -A8 -n '^  redis:' /tmp/emisiones_compose_config_137.txt | grep -q 'host_ip: 127.0.0.1'; then
  echo "FAIL: redis published port is not bound to 127.0.0.1 in resolved compose config"
  exit 1
fi

echo
echo "== Result =="
echo "OK: docker-compose.yml updated so db and redis published ports bind to 127.0.0.1"
echo "NEXT: run docker compose up -d, then rerun scripts/136_inspect_pilot_env_ports.sh"
