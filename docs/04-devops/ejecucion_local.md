# Ejecucion local - Emisiones

## Levantar servicios

```bash
cp .env.example .env
./scripts/check_env.sh
docker compose up --build
```

## Migraciones

En otra terminal:

```bash
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py check
```

## Validar healthcheck

```bash
curl http://localhost:8001/health/
```

Respuesta esperada:

```json
{"status": "ok", "service": "emisiones"}
```

## Admin Django

```bash
docker compose exec backend python manage.py createsuperuser
```

Acceso:

```text
http://localhost:8001/admin/
```
