# Continuidad posterior a F1-P17

**Proyecto:** Sistema de Rutas de Pago Oftalmi  
**Último punto funcional cerrado:** F1-P17 - Dashboard operativo de solicitudes  
**Siguiente punto ejecutado:** F1-P18 - Realineación documental y backlog vivo de Fase 1  
**Documento maestro vigente:** `docs/00-alcance/alcance_reglas_rutas_pago_oftalmi_v2.md`  

---

## 1. Estado funcional actual

Al cierre de F1-P17, el sistema cuenta con:

- Proyecto Django base.
- Configuración por ambiente.
- Docker Compose con backend y PostgreSQL.
- Usuario personalizado con email.
- Roles base.
- Estructura organizativa.
- Beneficiarios/proveedores.
- Solicitudes de pago.
- Documentos soporte.
- Ruta básica de aprobación.
- Vistas básicas de solicitudes.
- Envío/cancelación de solicitudes.
- Aprobación y rechazo desde UI.
- Dashboard operativo de solicitudes.

---

## 2. Última validación local conocida

```text
Ruff OK
Django check OK
Makemigrations check OK
Migrate OK
Tests: 61 OK
```

---

## 3. Decisión de realineación

Se detectó que la documentación de backlog previa no coincidía con la secuencia real ejecutada.

Por decisión de control del proyecto, antes de continuar con nuevas funcionalidades se ejecutó F1-P18 para:

- Actualizar el backlog vivo.
- Documentar F1-P16.
- Documentar F1-P17.
- Crear una continuidad clara para F1-P19 en adelante.
- Evitar pérdida de trazabilidad.

---

## 4. Próxima secuencia recomendada

```text
F1-P19 Bandeja de trabajo: pendientes por aprobar
F1-P20 Cuentas por Pagar: pagos aprobados pendientes por ejecutar
F1-P21 Registro básico de ejecución de pago
F1-P22 Auditoría básica transversal / trazabilidad de solicitud
F1-P23 Cierre técnico de Fase 1
```

---

## 5. F1-P19 - Criterios iniciales

La bandeja de pendientes por aprobar debe:

- Mostrar únicamente pasos pendientes.
- Filtrar por empresa del usuario.
- Filtrar por rol requerido del usuario.
- Requerir autenticación.
- Enlazar al detalle de solicitud.
- Tener pruebas de:
  - login requerido;
  - usuario autenticado;
  - scope por empresa;
  - scope por rol;
  - exclusión de pasos no pendientes.

Ruta sugerida:

```text
/payment-approvals/pending/
```

Rama sugerida:

```text
feature/approval-pending-workbench
```

Playbook sugerido:

```text
scripts/44_f1_p19_approval_pending_workbench.sh
```

---

## 6. Regla operativa de validación

Para cambios con Docker Compose se debe usar el bloque completo:

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

---

## 7. Restricción

No desarrollar directamente sobre `develop` ni sobre `main`.

Todo cambio debe salir de una rama `feature/*` creada desde `develop`.

