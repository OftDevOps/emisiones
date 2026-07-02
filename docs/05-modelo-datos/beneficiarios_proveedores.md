# Beneficiarios y proveedores - F1-P10

## Objetivo

Crear la base maestra de beneficiarios y proveedores que será usada por las futuras solicitudes de pago.

## Modelos

```text
Beneficiary
BeneficiaryBankAccount
```

## Beneficiary

Representa a cualquier persona natural o jurídica que pueda recibir un pago.

Tipos incluidos:

```text
SUPPLIER       Proveedor
EMPLOYEE       Empleado
THIRD_PARTY    Tercero
GOVERNMENT     Ente gubernamental
OTHER          Otro
```

Campos principales:

```text
company
beneficiary_type
document_type
document_number
legal_name
trade_name
email
phone
address
notes
is_active
```

## BeneficiaryBankAccount

Representa una cuenta bancaria asociada a un beneficiario.

Campos principales:

```text
beneficiary
bank_name
account_number
account_holder
account_type
currency
is_primary
swift_code
intermediary_bank
notes
is_active
```

## Reglas funcionales

```text
BEN-001 Todo beneficiario pertenece a una empresa.
BEN-002 Un mismo documento no puede repetirse dentro de la misma empresa.
BEN-003 El mismo documento puede existir en otra empresa del grupo.
BEN-004 Un beneficiario puede tener varias cuentas bancarias.
BEN-005 Una cuenta bancaria no puede duplicarse para el mismo beneficiario y moneda.
BEN-006 La eliminación física queda protegida con PROTECT para preservar trazabilidad futura.
BEN-007 El maestro de beneficiarios será usado por solicitudes de pago desde F1-P11.
```

## Alcance excluido en este bloque

```text
No se crean solicitudes de pago.
No se crean aprobaciones.
No se crean documentos soporte.
No se crean APIs.
No se crean pantallas CRUD fuera del Django Admin.
```
