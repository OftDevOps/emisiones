#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="/home/dchirinos/oftalmiIA/emisiones/emisiones"
DOC_PATH="docs/br05_diseno_emision_items_iva_parametrizable.md"

cd "$PROJECT_DIR"

echo "== BR05-P01: diseño emisión por ítems de factura con IVA parametrizable =="
echo "== Ruta =="
pwd

echo "== Estado inicial =="
git status --short

mkdir -p docs

cat > "$DOC_PATH" <<'MD'
# BR05-P01 - Diseño funcional y técnico: emisión por ítems de factura con IVA parametrizable

## 1. Objetivo

Implementar la carga de una emisión a partir de ítems de factura, con cálculo controlado de subtotal, IVA y total, evitando que el usuario registre únicamente un monto global sin desglose.

Este bloque convierte la emisión en una estructura verificable por línea de factura y prepara la base para controles posteriores de auditoría, validación contra documento adjunto y parametrización fiscal.

---

## 2. Decisión de producto

La emisión seguirá siendo el objeto principal del sistema.

La emisión tendrá uno o más ítems asociados. Cada ítem representa una línea conceptual o fiscal de la factura.

El monto total de la emisión debe derivarse de los ítems, no ser digitado libremente como monto principal cuando el flujo sea por factura.

---

## 3. Alcance BR05

Incluye:

- Modelo de ítems de emisión/factura.
- Parámetro de IVA reutilizable.
- Cálculo por ítem: base imponible, porcentaje IVA, monto IVA y total de línea.
- Cálculo agregado: subtotal, IVA total y total general.
- Validaciones de consistencia.
- Formulario/UI para cargar varios ítems.
- Pruebas unitarias y de integración.
- Migraciones controladas.

No incluye todavía:

- Lectura OCR de facturas.
- Integración con ERP.
- Validación automática contra XML/PDF fiscal.
- Notificaciones.
- Aprobación por ítem.
- Multi-impuesto distinto de IVA.
- Retenciones fiscales.

---

## 4. Reglas funcionales

### 4.1 Ítems obligatorios

Toda emisión de tipo factura debe tener al menos un ítem.

Cada ítem debe incluir:

- Descripción.
- Cantidad.
- Monto base unitario o monto base total de línea, según decisión final de formulario.
- Porcentaje de IVA aplicable.
- Monto IVA calculado.
- Total de línea calculado.

### 4.2 IVA parametrizable

El porcentaje de IVA no debe estar hardcodeado en formularios, vistas ni templates.

Debe existir una fuente parametrizable para obtener tasas de IVA activas.

Para MVP se recomienda una tabla simple de tasas fiscales.

### 4.3 Cálculos

Por ítem:

```text
base_linea = cantidad * precio_unitario
iva_linea = base_linea * porcentaje_iva / 100
total_linea = base_linea + iva_linea
```

Totales de emisión:

```text
subtotal = suma(base_linea)
iva_total = suma(iva_linea)
total = suma(total_linea)
```

### 4.4 Redondeo

Usar `Decimal` en backend.

Redondear montos monetarios a 2 decimales.

El cálculo fuente debe vivir en backend, no en JavaScript. JavaScript puede ayudar visualmente, pero no debe ser la fuente de verdad.

### 4.5 Validaciones

La emisión no puede enviarse a aprobación si:

- No tiene ítems.
- Algún ítem tiene cantidad menor o igual a cero.
- Algún ítem tiene base menor o igual a cero.
- Algún ítem usa una tasa de IVA inactiva.
- El total calculado no coincide con el total persistido.

---

## 5. Modelo técnico propuesto

### 5.1 TaxRate

App recomendada: `payment_requests` para mantener alcance simple de MVP.

Nombre sugerido:

```python
TaxRate
```

Campos:

```text
name: CharField
rate: DecimalField(max_digits=5, decimal_places=2)
is_active: BooleanField(default=True)
is_default: BooleanField(default=False)
created_at: DateTimeField(auto_now_add=True)
updated_at: DateTimeField(auto_now=True)
```

Reglas:

- Puede haber varias tasas activas.
- Solo una tasa debería ser default.
- Para MVP se puede validar default a nivel aplicación.

### 5.2 PaymentRequestItem

Nombre sugerido:

```python
PaymentRequestItem
```

Campos:

```text
payment_request: ForeignKey(PaymentRequest, related_name="items")
description: CharField/TextField
quantity: DecimalField(max_digits=12, decimal_places=2)
unit_price: DecimalField(max_digits=14, decimal_places=2)
tax_rate: ForeignKey(TaxRate, PROTECT)
tax_percentage_snapshot: DecimalField(max_digits=5, decimal_places=2)
base_amount: DecimalField(max_digits=14, decimal_places=2)
tax_amount: DecimalField(max_digits=14, decimal_places=2)
total_amount: DecimalField(max_digits=14, decimal_places=2)
created_at: DateTimeField(auto_now_add=True)
updated_at: DateTimeField(auto_now=True)
```

Justificación del snapshot:

La tasa puede cambiar en el futuro. La emisión debe conservar el porcentaje aplicado al momento de la carga.

---

## 6. Impacto sobre PaymentRequest

El campo actual `amount` puede mantenerse como total general de la emisión para compatibilidad operativa.

Regla recomendada:

```text
PaymentRequest.amount = suma(PaymentRequestItem.total_amount)
```

Para BR05 no se recomienda eliminar `amount`, porque ya existe en vistas, reportes, aprobaciones y ejecución de pago.

Se recomienda agregar campos agregados si aportan claridad:

```text
subtotal_amount
tax_amount
total_amount
```

Pero para reducir riesgo en MVP, también es aceptable mantener solo `amount` como total y calcular subtotal/IVA desde items cuando se necesite mostrar.

Decisión recomendada para BR05:

```text
Agregar subtotal_amount y tax_amount a PaymentRequest.
Mantener amount como total general por compatibilidad.
```

---

## 7. UI / Formulario

### 7.1 Crear/editar emisión

El formulario debe permitir cargar múltiples ítems.

En MVP se recomienda Django formset, no HTMX complejo al inicio.

Campos visibles por línea:

```text
Descripción
Cantidad
Precio unitario / Base unitario
IVA
Subtotal línea
IVA línea
Total línea
Eliminar línea
```

Totales visibles:

```text
Subtotal
IVA total
Total emisión
```

### 7.2 Frontend

JavaScript puede recalcular visualmente para UX, pero el backend recalcula y valida en `form_valid` o servicio de dominio.

---

## 8. Servicios de dominio recomendados

Crear módulo:

```text
backend/apps/payment_requests/services.py
```

Funciones sugeridas:

```python
calculate_item_amounts(quantity, unit_price, tax_percentage)
calculate_request_totals(items)
recalculate_payment_request_totals(payment_request)
```

Ventaja:

- Evita duplicar cálculo en modelos, forms y vistas.
- Facilita pruebas unitarias.
- Deja trazabilidad de reglas fiscales.

---

## 9. Migraciones esperadas

BR05 sí requiere migración.

Cambios esperados:

```text
Crear TaxRate.
Crear PaymentRequestItem.
Agregar subtotal_amount y tax_amount a PaymentRequest, si se adopta la decisión recomendada.
Crear seed inicial de IVA default, preferiblemente mediante data migration o comando controlado.
```

IVA default inicial sugerido para contexto Venezuela:

```text
IVA General 16.00%
```

Debe confirmarse con negocio antes de dejarlo como dato inicial definitivo.

---

## 10. Pruebas mínimas

Unitarias:

- Calcula ítem con IVA 16%.
- Calcula ítem con IVA 0%.
- Redondeo a 2 decimales.
- Suma totales de varios ítems.
- Snapshot conserva tasa aunque TaxRate cambie.

Integración:

- Crear emisión con un ítem.
- Crear emisión con varios ítems.
- No permitir enviar emisión sin ítems.
- No permitir cantidad/base <= 0.
- Total de PaymentRequest queda igual a suma de ítems.
- Vista detalle muestra subtotal, IVA y total.
- Reporte conserva total de emisión.

Regresión:

- Aprobaciones siguen funcionando.
- Ejecución de pago sigue funcionando.
- Dashboard sigue mostrando total correcto.
- Compras sigue viendo marcar emisión como pagada.

---

## 11. Riesgos

### Riesgo 1: tocar `amount`

`amount` ya está conectado con aprobaciones, reportes y ejecución. Cambiar su semántica sin control rompe flujos.

Mitigación:

Mantener `amount` como total final calculado.

### Riesgo 2: cálculo duplicado frontend/backend

Mitigación:

Backend es fuente de verdad. Frontend solo ayuda visualmente.

### Riesgo 3: IVA cambiante

Mitigación:

Guardar snapshot del porcentaje en cada ítem.

### Riesgo 4: migración con datos existentes

Mitigación:

Para emisiones existentes, crear estrategia de compatibilidad: pueden quedar sin ítems o crear un ítem legado automático.

Decisión pendiente:

```text
¿Las emisiones existentes deben migrarse a un ítem legado único?
```

Recomendación:

Sí, crear un ítem legado único para cada emisión existente con:

```text
description = concept o "Monto legado"
quantity = 1
unit_price = amount
IVA = 0%
total = amount
```

Solo si el ambiente ya tiene datos que deben preservarse para piloto.

---

## 12. Decisiones pendientes antes de codificar BR05-P02

1. ¿IVA default inicial será 16%?
2. ¿Se permitirá IVA 0%?
3. ¿El usuario cargará precio unitario o base total por línea?
4. ¿Las emisiones existentes se migran con ítem legado?
5. ¿El documento adjunto seguirá siendo obligatorio para facturas?
6. ¿Se permite mezclar ítems con distintas tasas de IVA en una misma emisión?

---

## 13. Recomendación de implementación por pasos

### BR05-P02

Crear modelos `TaxRate` y `PaymentRequestItem`, migraciones y pruebas unitarias de cálculo.

### BR05-P03

Agregar servicios de cálculo y recalculo de totales.

### BR05-P04

Actualizar creación/edición de emisión con formset de ítems.

### BR05-P05

Actualizar detalle, dashboard y reporte para mostrar subtotal/IVA/total.

### BR05-P06

Pruebas integradas y saneamiento de compatibilidad con aprobaciones y Compras.

---

## 14. Criterio de aceptación BR05

BR05 se considera cerrado cuando:

- Una emisión puede cargarse con uno o varios ítems.
- El IVA se toma de una tasa parametrizable.
- El total se calcula desde los ítems.
- No se puede enviar a aprobación una emisión inconsistente.
- Las vistas clave muestran subtotal, IVA y total.
- El flujo de aprobación no se rompe.
- Compras puede seguir marcando como pagada una emisión aprobada.
- `ruff`, `check`, `makemigrations --check`, `migrate` y tests pasan.
MD

echo "== Documento creado =="
ls -l "$DOC_PATH"

echo "== Validando que no haya migraciones ni cambios de codigo =="
git diff --check

echo "== Estado final =="
git status --short

echo "== FIN BR05-P01 diseño =="
