# Accounts

App responsable de la identidad interna del Sistema de Rutas de Emisión Oftalmi.

## Decisiones

- El correo electronico es el identificador principal del usuario.
- `username` se mantiene sincronizado con `email` solo por compatibilidad interna con Django.
- Los roles base del MVP se definen en `UserRole`.
- La autenticacion queda preparada para futura integracion con Microsoft Entra ID.

## Roles base MVP

- ADMINISTRADOR
- SOLICITANTE
- RESPONSABLE_UNIDAD
- FINANZAS
- GERENCIA_GENERAL
- JUNTA_DIRECTIVA
- CUENTAS_POR_PAGAR
- AUDITOR
