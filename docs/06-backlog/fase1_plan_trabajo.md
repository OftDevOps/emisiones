# Fase 1 - Plan de trabajo controlado

## Objetivo

Construir el nucleo operativo del MVP del Sistema de Rutas de Pago Oftalmi, evitando deuda tecnica temprana y manteniendo trazabilidad por ramas Git.

## Secuencia aprobada

| Punto | Rama sugerida | Alcance |
|---|---|---|
| F1-P01 | feature/django-base-project | Proyecto Django base funcional. |
| F1-P02 | feature/django-base-project | Settings por ambiente. |
| F1-P03 | feature/django-base-project | Docker Compose con backend y PostgreSQL. |
| F1-P04 | feature/accounts-email-user | CustomUser con email como username. |
| F1-P05 | feature/accounts-roles | Roles base del MVP. |
| F1-P06 | feature/organization-base | Empresa, unidades, departamentos, areas y gerencias. |
| F1-P07 | feature/user-organization-scope | Relacion usuario, empresa y unidad. |
| F1-P08 | feature/login-basic | Login basico por email. |
| F1-P09 | feature/phase1-base-tests | Pruebas minimas de usuarios, roles y organizacion. |
| F1-P10 | feature/beneficiaries-base | Beneficiarios/proveedores. |
| F1-P11 | feature/payment-requests-base | Solicitudes de pago. |
| F1-P12 | feature/payment-documents-base | Documentos soporte. |
| F1-P13 | feature/basic-approval-route | Ruta basica de aprobacion. |
| F1-P14 | feature/approval-actions | Aprobar, devolver y rechazar. |
| F1-P15 | feature/accounts-payable | Bandeja Cuentas por Pagar. |
| F1-P16 | feature/payment-execution | Registro de pago. |
| F1-P17 | feature/basic-audit | Auditoria basica transversal. |

## Regla de avance

No se inicia un punto nuevo hasta que el punto anterior tenga:

1. Codigo aplicado.
2. Validacion local.
3. Commit en rama feature.
4. Integracion a develop.
5. Estado Git limpio.
