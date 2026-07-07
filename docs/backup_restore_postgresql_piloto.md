# Apps Emisiones - Backup y restore PostgreSQL para piloto interno

## Proposito

Definir el procedimiento minimo de respaldo y restauracion de PostgreSQL antes y durante el piloto interno.

## Backup previo al piloto

Ejemplo con Docker Compose:

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

mkdir -p backups

docker compose exec -T db pg_dump \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  --format=custom \
  --file=/tmp/emisiones_pre_piloto.dump

docker compose cp db:/tmp/emisiones_pre_piloto.dump backups/emisiones_pre_piloto_$(date +%Y%m%d_%H%M%S).dump

ls -lh backups/
```

Si las variables no estan disponibles dentro del contenedor, reemplazar por los valores reales definidos en `.env`.

## Backup SQL plano alternativo

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

mkdir -p backups

docker compose exec -T db pg_dump \
  -U emisiones_user \
  -d emisiones \
  > backups/emisiones_pre_piloto_$(date +%Y%m%d_%H%M%S).sql

ls -lh backups/
```

## Verificacion minima del backup

- Confirmar que el archivo existe.
- Confirmar que el archivo pesa mas que cero bytes.
- Registrar fecha y hora.
- Registrar commit desplegado.
- Registrar responsable.

## Restore desde formato custom

Procedimiento destructivo. Debe ejecutarse solo con autorizacion.

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

BACKUP_FILE="backups/emisiones_pre_piloto_YYYYMMDD_HHMMSS.dump"

docker compose cp "$BACKUP_FILE" db:/tmp/restore.dump

docker compose exec -T db dropdb -U emisiones_user emisiones --if-exists
docker compose exec -T db createdb -U emisiones_user emisiones
docker compose exec -T db pg_restore -U emisiones_user -d emisiones --clean --if-exists /tmp/restore.dump
```

## Restore desde SQL plano

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

BACKUP_FILE="backups/emisiones_pre_piloto_YYYYMMDD_HHMMSS.sql"

docker compose exec -T db dropdb -U emisiones_user emisiones --if-exists
docker compose exec -T db createdb -U emisiones_user emisiones
cat "$BACKUP_FILE" | docker compose exec -T db psql -U emisiones_user -d emisiones
```

## Politica minima durante piloto

- Backup antes de iniciar piloto.
- Backup al cierre de cada jornada UAT.
- Backup antes de cualquier ajuste correctivo.
- No borrar backups hasta cierre formal del piloto.
- Copiar backup critico fuera del host si el piloto dura mas de una jornada.
