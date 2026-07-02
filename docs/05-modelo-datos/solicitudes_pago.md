# Modelo de datos - Solicitudes de pago

## Propósito

El modelo `PaymentRequest` representa la solicitud base que inicia una ruta de pago.

## Relaciones

```text
PaymentRequest.company        -> organization.Company
PaymentRequest.beneficiary    -> beneficiaries.Beneficiary
PaymentRequest.requested_by   -> accounts.CustomUser
```

## Decisiones de diseño

```text
1. La empresa es obligatoria para soportar operación multiempresa.
2. El beneficiario es obligatorio porque toda solicitud debe tener destino de pago.
3. El solicitante es obligatorio para trazabilidad y futura segregación por rol.
4. El monto se valida a nivel de modelo con full_clean() antes de guardar.
5. Los estados se mantienen mínimos para no adelantar el workflow de aprobación.
6. Se protege la eliminación física de empresa, beneficiario y usuario si existen solicitudes asociadas.
```

## Estados

```text
DRAFT      Solicitud creada pero no enviada.
SUBMITTED  Solicitud enviada para su procesamiento futuro.
CANCELLED  Solicitud cancelada.
```

## Próximos puntos relacionados

```text
F1-P12 Documentos soporte
F1-P13 Ruta básica de aprobación
F1-P14 Bandejas por rol
F1-P15 Auditoría de cambios de solicitud
```
