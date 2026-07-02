# F1-P10 - Beneficiarios / proveedores

## Estado

```text
F1-P10 Beneficiarios / proveedores — IMPLEMENTADO POR SCRIPT
```

## Archivos creados

```text
backend/apps/beneficiaries/apps.py
backend/apps/beneficiaries/models.py
backend/apps/beneficiaries/admin.py
backend/apps/beneficiaries/migrations/0001_initial.py
backend/apps/beneficiaries/tests/test_models.py
docs/05-modelo-datos/beneficiarios_proveedores.md
```

## Archivos modificados

```text
backend/config/settings/base.py
```

## Validaciones requeridas

```bash
python manage.py check
python manage.py makemigrations --check --dry-run
python manage.py migrate
python manage.py test apps.organization apps.accounts apps.beneficiaries
```

## Commit sugerido

```bash
git add .
git commit -m "feat: add beneficiaries and bank accounts"
git push -u origin feature/beneficiaries
```
