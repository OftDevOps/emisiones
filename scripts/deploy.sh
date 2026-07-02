#!/usr/bin/env bash
set -euo pipefail

docker compose pull || true
docker compose build
docker compose up -d
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py collectstatic --noinput
