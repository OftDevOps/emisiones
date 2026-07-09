#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
DOC_PATH="docs/br05_p03a_contrato_tecnico_items_iva.md"

cd "$PROJECT_DIR"

echo "== BR05-P03A: contrato tecnico implementacion items + IVA parametrizable =="
echo "== Ruta =="
pwd

echo "== Estado inicial =="
git status --short

mkdir -p docs

cat > "$DOC_PATH" <<'MD'
# BR05-P03A - Contrato técnico de implementación: ítems de factura + IVA parametrizable

## 1. Objetivo

Implementar la carga de emisiones por ítems de factura, con IVA parametrizable, preservando compatibilidad con el flujo actual de Apps Emisiones.

Este contrato baja a nombres exactos de modelos, campos, defaults, reglas de cálculo, migración y estrategia para emisiones existentes antes de tocar base de datos.

---

## 2. Principios técnicos

1. `PaymentRequest.amount` no se elimina.
2. `PaymentRequest.amount` se mantiene como total final de la emisión.
3. El backend será la fuente de verdad del cálculo monetario.
4. El frontend puede mostrar cálculos preliminares, pero no decide totales persistidos.
5. Cada ítem guarda snapshot del porcentaje de IVA usado al momento de calcular.
6. Cambiar una tasa de IVA futura no debe alterar emisiones históricas.
7. Emisiones existentes deben seguir funcionando sin ítems.
8. No se cambia todavía el nombre técnico `PaymentRequest`.
9. No se renombran apps, rutas internas ni tablas existentes.

---

## 3. Modelo existente que debe preservarse

Modelo base actual:

```text
PaymentRequest
- company
- beneficiary
- requested_by
- amount
- currency
- concept
- description
- due_date
- status
- created_at
- updated_at
```

Uso crítico de `amount`:

```text
- listados
- detalle
- dashboard
- reportes
- export CSV
- approval flow
- payment execution
- paid_amount
- tests existentes
```

Decisión:

```text
PaymentRequest.amount = total_amount calculado de todos los ítems.
```

---

## 4. Nuevos campos en PaymentRequest

Agregar campos calculados y persistidos:

```python
subtotal_amount = models.DecimalField(
    "subtotal",
    max_digits=14,
    decimal_places=2,
    default=Decimal("0.00"),
)

tax_amount = models.DecimalField(
    "IVA total",
    max_digits=14,
    decimal_places=2,
    default=Decimal("0.00"),
)
```

Campo existente:

```python
amount = models.DecimalField(
    "monto total",
    max_digits=14,
    decimal_places=2,
)
```

Regla:

```text
amount = subtotal_amount + tax_amount
```

Compatibilidad:

```text
Para emisiones históricas sin ítems:
- subtotal_amount = amount
- tax_amount = 0.00
- amount queda intacto
```

---

## 5. Nuevo modelo TaxRate

Nombre técnico:

```python
TaxRate
```

App recomendada:

```text
apps.payment_requests
```

Motivo: BR05 afecta directamente emisión y evita crear una app tributaria prematura.

Campos:

```python
class TaxRate(models.Model):
    name = models.CharField("nombre", max_length=80)
    percentage = models.DecimalField("porcentaje", max_digits=5, decimal_places=2)
    is_active = models.BooleanField("activo", default=True)
    valid_from = models.DateField("vigente desde", null=True, blank=True)
    valid_to = models.DateField("vigente hasta", null=True, blank=True)
    created_at = models.DateTimeField("creado", auto_now_add=True)
    updated_at = models.DateTimeField("actualizado", auto_now=True)
```

Defaults iniciales por migración de datos:

```text
IVA 16%: percentage=16.00, is_active=True
Exento 0%: percentage=0.00, is_active=True
```

Validaciones:

```text
percentage >= 0
percentage <= 100
name obligatorio
No bloquear varias tasas activas; puede haber 16%, 0%, futuras tasas o casos especiales.
```

Representación:

```python
def __str__(self):
    return f"{self.name} ({self.percentage}%)"
```

---

## 6. Nuevo modelo PaymentRequestItem

Nombre técnico:

```python
PaymentRequestItem
```

Relación:

```python
payment_request = models.ForeignKey(
    PaymentRequest,
    related_name="items",
    on_delete=models.CASCADE,
)
```

Campos:

```python
description = models.CharField("descripción", max_length=255)
quantity = models.DecimalField("cantidad", max_digits=12, decimal_places=2)
unit_price = models.DecimalField("precio unitario", max_digits=14, decimal_places=2)
tax_rate = models.ForeignKey(
    TaxRate,
    verbose_name="IVA",
    on_delete=models.PROTECT,
)
tax_percentage_snapshot = models.DecimalField(
    "porcentaje IVA aplicado",
    max_digits=5,
    decimal_places=2,
)
subtotal_amount = models.DecimalField("subtotal", max_digits=14, decimal_places=2, default=Decimal("0.00"))
tax_amount = models.DecimalField("IVA", max_digits=14, decimal_places=2, default=Decimal("0.00"))
total_amount = models.DecimalField("total", max_digits=14, decimal_places=2, default=Decimal("0.00"))
position = models.PositiveIntegerField("posición", default=1)
created_at = models.DateTimeField("creado", auto_now_add=True)
updated_at = models.DateTimeField("actualizado", auto_now=True)
```

Ordenamiento:

```python
class Meta:
    ordering = ["position", "id"]
```

Validaciones:

```text
description obligatorio
quantity > 0
unit_price >= 0
tax_rate obligatorio
tax_percentage_snapshot >= 0
tax_percentage_snapshot <= 100
subtotal_amount >= 0
tax_amount >= 0
total_amount >= 0
```

Reglas:

```text
subtotal_amount = quantity * unit_price
tax_amount = subtotal_amount * tax_percentage_snapshot / 100
total_amount = subtotal_amount + tax_amount
```

---

## 7. Redondeo monetario

Regla estándar:

```python
Decimal("0.01") con ROUND_HALF_UP
```

Aplicación:

```text
1. Calcular subtotal del ítem.
2. Redondear subtotal del ítem a 2 decimales.
3. Calcular IVA del ítem sobre subtotal redondeado.
4. Redondear IVA del ítem a 2 decimales.
5. Calcular total del ítem = subtotal_amount + tax_amount.
6. Totalizar PaymentRequest por suma de ítems ya redondeados.
```

Motivo:

```text
Evita diferencias entre pantalla, reportes y ejecución de pago.
```

---

## 8. Servicio de cálculo recomendado

Crear módulo:

```text
backend/apps/payment_requests/services.py
```

Funciones mínimas:

```python
def quantize_money(value: Decimal) -> Decimal:
    ...

@dataclass(frozen=True)
class ItemTotals:
    subtotal_amount: Decimal
    tax_amount: Decimal
    total_amount: Decimal

@dataclass(frozen=True)
class RequestTotals:
    subtotal_amount: Decimal
    tax_amount: Decimal
    total_amount: Decimal


def calculate_item_totals(quantity: Decimal, unit_price: Decimal, tax_percentage: Decimal) -> ItemTotals:
    ...


def calculate_request_totals(items: Iterable[PaymentRequestItem]) -> RequestTotals:
    ...


def recalculate_payment_request_totals(payment_request: PaymentRequest, save: bool = True) -> RequestTotals:
    ...
```

Política:

```text
Los modelos pueden llamar al servicio, pero la lógica de cálculo no debe quedar duplicada en forms, views y templates.
```

---

## 9. Comportamiento en creación de emisión

Flujo objetivo:

```text
1. Usuario crea cabecera de emisión.
2. Usuario carga uno o más ítems.
3. Backend calcula subtotal, IVA y total.
4. PaymentRequest.amount queda como total final.
5. La emisión queda en DRAFT.
```

Regla de submit:

```text
No se puede enviar a aprobación una emisión sin ítems, salvo emisiones legacy creadas antes de BR05.
```

Primera implementación recomendada:

```text
BR05-P03/P04/P05 puede permitir temporalmente cabecera + ítems en un solo flujo de formulario.
```

---

## 10. Compatibilidad con emisiones existentes

Migración de esquema:

```text
Agregar subtotal_amount y tax_amount con default 0.00.
Crear TaxRate.
Crear PaymentRequestItem.
```

Migración de datos:

```text
Para cada PaymentRequest existente:
- subtotal_amount = amount
- tax_amount = 0.00
- No crear ítem automático en primera migración, salvo que negocio lo pida.
```

Justificación de no crear ítem automático:

```text
Una emisión histórica con monto total no tiene detalle real de factura. Crear un ítem ficticio puede contaminar auditoría.
```

Mensaje visible recomendado en detalle legacy:

```text
Esta emisión fue creada antes de la carga por ítems. No tiene desglose de factura registrado.
```

---

## 11. PaymentExecution

Modelo actual:

```text
PaymentExecution.paid_amount
```

Regla después de BR05:

```text
paid_amount debe compararse contra PaymentRequest.amount.
```

En formulario de confirmación de pago:

```text
Monto sugerido = payment_request.amount
```

Validación recomendada:

```text
paid_amount debe ser mayor a 0.
paid_amount puede ser distinto del total solo si se permite pago parcial en fase futura.
Para MVP: paid_amount debe ser igual a payment_request.amount.
```

Decisión MVP recomendada:

```text
No implementar pagos parciales en BR05.
```

---

## 12. Formularios

Formulario de cabecera `PaymentRequestForm`:

```text
Debe dejar de exponer amount como entrada principal cuando el flujo de ítems esté activo.
```

Campos de cabecera:

```text
company
beneficiary
currency
concept
description
due_date
```

Formset de ítems:

```text
description
quantity
unit_price
tax_rate
```

Campos no editables por usuario:

```text
tax_percentage_snapshot
subtotal_amount
tax_amount
total_amount
PaymentRequest.subtotal_amount
PaymentRequest.tax_amount
PaymentRequest.amount
```

---

## 13. Templates impactados

Crear/actualizar:

```text
backend/templates/payment_requests/paymentrequest_form.html
backend/templates/payment_requests/paymentrequest_detail.html
backend/templates/payment_requests/paymentrequest_list.html
backend/templates/payment_requests/paymentrequest_dashboard.html
backend/templates/payment_requests/paymentrequest_report.html
backend/templates/payment_requests/accounts_payable_pending.html
backend/templates/payment_execution/paymentexecution_form.html
```

Detalle debe mostrar:

```text
Subtotal
IVA
Total
Tabla de ítems
```

Tabla de ítems:

```text
Descripción | Cantidad | Precio unitario | IVA % | Base | IVA | Total
```

---

## 14. Reportes y exportación

Reportes deben mantener compatibilidad:

```text
Monto actual = amount = total final
```

Agregar columnas en CSV cuando corresponda:

```text
Subtotal
IVA
Total
```

No exportar todavía detalle de ítems en el CSV operativo principal, salvo que se defina un export específico.

---

## 15. Pruebas mínimas requeridas

Modelos:

```text
TaxRate valida porcentaje.
PaymentRequestItem calcula subtotal/IVA/total.
PaymentRequest recalcula subtotal/IVA/amount.
Emisión legacy sin ítems sigue siendo válida.
```

Forms/views:

```text
Crear emisión con ítems.
Rechazar emisión sin ítems en flujo nuevo.
Rechazar cantidad <= 0.
Rechazar precio unitario negativo.
IVA 0% calcula impuesto 0.
IVA 16% calcula correctamente.
```

PaymentExecution:

```text
Formulario sugiere total final.
Confirmación de pago usa amount calculado.
No permite pago de emisión no aprobada.
No permite pago parcial en MVP si paid_amount != amount.
```

Reportes:

```text
Listados y reportes siguen mostrando total final.
Export CSV no se rompe.
```

Regresión:

```text
approval flow completo DRAFT -> PAID sigue verde.
```

---

## 16. Riesgos

Riesgo principal:

```text
Romper compatibilidad con amount.
```

Mitigación:

```text
No eliminar amount.
No cambiar semántica de PaymentExecution.
Agregar campos calculados sin alterar flujo de aprobación.
```

Riesgo fiscal:

```text
Diferencias de redondeo entre factura real y sistema.
```

Mitigación:

```text
ROUND_HALF_UP a 2 decimales por ítem.
Documentar regla.
Permitir ajuste futuro si la factura del proveedor trae redondeos distintos.
```

Riesgo de auditoría:

```text
Crear ítems ficticios para emisiones históricas.
```

Mitigación:

```text
No crear ítems históricos automáticos en primera migración.
```

---

## 17. Secuencia de implementación recomendada

```text
BR05-P03B: modelos TaxRate/PaymentRequestItem + campos subtotal/tax en PaymentRequest.
BR05-P03C: migraciones schema + data migration para subtotal/tax legacy.
BR05-P04: servicios de cálculo y pruebas unitarias.
BR05-P05: forms/formset de creación con ítems.
BR05-P06: detalle/listados/reportes/payment execution adaptados.
BR05-P07: validaciones de submit y no pago parcial MVP.
BR05-P08: pruebas integradas completas.
```

---

## 18. Decisiones pendientes de negocio

1. ¿IVA base será 16% por defecto?
2. ¿Debe existir ítem exento 0% desde el MVP?
3. ¿Se permitirá pago parcial? Recomendación: no en MVP.
4. ¿La factura puede traer varios porcentajes de IVA? Recomendación: sí, por ítem.
5. ¿Se debe validar total contra documento adjunto? Recomendación: no automático en MVP; dejarlo como control operativo.

---

## 19. Criterio de aprobación del contrato

Este contrato queda aprobado para iniciar migraciones si se aceptan estas premisas:

```text
- amount se mantiene como total final.
- subtotal_amount y tax_amount se agregan a PaymentRequest.
- TaxRate vive en payment_requests.
- PaymentRequestItem guarda snapshot de IVA.
- No se crean ítems históricos ficticios.
- No hay pagos parciales en BR05 MVP.
- ROUND_HALF_UP a 2 decimales por ítem.
```
MD

if grep -R "class TaxRate\|class PaymentRequestItem\|subtotal_amount\|tax_amount" backend/apps/payment_requests -n >/tmp/br05_p03a_backend_hits.txt 2>/dev/null; then
  echo "WARN: ya existen referencias potenciales en codigo:"
  cat /tmp/br05_p03a_backend_hits.txt
else
  echo "OK: no se detectan implementaciones previas de TaxRate/PaymentRequestItem/subtotal_amount/tax_amount"
fi

echo "== Documento creado =="
ls -l "$DOC_PATH"

echo "== Validando que no haya migraciones ni cambios de codigo =="
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run

echo "== Estado final =="
git status --short

echo "== FIN BR05-P03A contrato tecnico =="
