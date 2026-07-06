#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/dchirinos/oftalmiIA/emisiones/emisiones"
cd "$ROOT"

echo "== F2-P02: Endurecimiento de roles, permisos y matriz de acceso operativa =="

mkdir -p docs backend/apps/accounts/tests

cat > docs/f2_p02_roles_permisos_matriz_acceso.md <<'MD'
# F2-P02 - Endurecimiento de roles, permisos y matriz de acceso operativa

## Proposito

Formalizar y endurecer el control de acceso por rol para la Fase 2 de Apps Emisiones, dejando una matriz operativa verificable antes de agregar nuevas capacidades funcionales.

Este punto no cambia el flujo de negocio del MVP. Su objetivo es ordenar, documentar y probar los permisos actuales para reducir riesgo operativo.

---

## Alcance

Incluye:

- Matriz de acceso por rol.
- Criterios de endurecimiento de permisos.
- Pruebas base sobre roles reconocidos y helpers de permisos.
- Documentacion de reglas actuales.
- Validacion de que no se requieren migraciones.

No incluye:

- Nuevos modelos.
- Nuevas migraciones.
- Cambios de flujo financiero.
- Cambios de estados de solicitudes.
- Integracion con directorio activo o SSO.

---

## Roles operativos vigentes

| Rol | Proposito operativo |
|---|---|
| ADMINISTRADOR | Gobierno completo del sistema y supervision transversal. |
| SOLICITANTE | Registro y seguimiento de solicitudes propias. |
| RESPONSABLE_UNIDAD | Revision/aprobacion segun flujo de aprobacion asignado. |
| FINANZAS | Revision financiera, visibilidad y control operativo. |
| CUENTAS_POR_PAGAR | Gestion de cuentas por pagar y registro de pagos. |
| AUDITOR | Consulta y revision de trazabilidad/auditoria. |

---

## Matriz de acceso MVP/Fase 2

| Capacidad | ADMINISTRADOR | SOLICITANTE | RESPONSABLE_UNIDAD | FINANZAS | CUENTAS_POR_PAGAR | AUDITOR |
|---|---:|---:|---:|---:|---:|---:|
| Login | Si | Si | Si | Si | Si | Si |
| Dashboard principal | Si | Si | Si | Si | Si | Si |
| Dashboard solicitudes | Si | Si | Si | Si | Si | Si |
| Crear solicitud | Si | Si | No | No | No | No |
| Ver solicitudes propias | Si | Si | Segun alcance | Si | Si | Consulta |
| Enviar solicitud | Si | Si | No | No | No | No |
| Aprobar/Rechazar pasos asignados | Si | No | Si | Si | No | No |
| Bandeja pendientes aprobacion | Si | No | Si | Si | No | No |
| Cuentas por pagar | Si | No | No | Si | Si | Consulta |
| Registrar ejecucion de pago | Si | No | No | No | Si | No |
| Auditoria transversal | Si | No | No | Consulta | Consulta | Si |

Notas:

- `Consulta` significa visibilidad de control sin capacidad de ejecutar la accion principal.
- El acceso a datos debe respetar empresa, rol y alcance operativo.
- Ningun rol no autorizado debe ejecutar acciones criticas por conocer la URL.

---

## Reglas de endurecimiento

1. Toda vista critica debe validar autenticacion.
2. Toda accion critica debe validar rol antes de ejecutar cambios.
3. Las acciones de aprobacion deben validar rol y pertenencia/alcance del paso.
4. Cuentas por pagar debe estar restringido a `ADMINISTRADOR`, `FINANZAS`, `CUENTAS_POR_PAGAR` y consulta autorizada para auditoria si aplica.
5. Registro de pago debe quedar restringido a `ADMINISTRADOR` y `CUENTAS_POR_PAGAR`.
6. Auditoria debe priorizar consulta por `ADMINISTRADOR` y `AUDITOR`, con extension controlada a roles financieros si el negocio lo requiere.
7. Los errores `403 Forbidden` son correctos cuando el usuario autenticado no tiene rol suficiente.
8. Los errores `404 Not Found` son correctos cuando el objeto no existe o no debe exponerse.

---

## Criterios de aceptacion

F2-P02 se considera cerrado cuando:

- La matriz de acceso queda documentada.
- Los roles vigentes quedan inventariados.
- Existen pruebas base de helpers/roles o, si el proyecto ya los tenia, quedan reforzadas.
- `ruff check .` pasa.
- `python manage.py check` pasa.
- `makemigrations --check --dry-run` no detecta migraciones.
- La suite actual de pruebas pasa.

---

## Riesgos mitigados

| Riesgo | Mitigacion |
|---|---|
| Acceso por URL directa | Validacion por rol en vistas/acciones criticas. |
| Crecimiento funcional sin gobierno de permisos | Matriz de acceso como contrato operativo. |
| Ambiguedad entre Finanzas y Cuentas por Pagar | Separacion documentada de visibilidad y ejecucion de pago. |
| Auditoria con alcance indefinido | Consulta formalizada como rol de control. |
| Cambios futuros rompiendo seguridad | Pruebas base y criterios de aceptacion obligatorios. |

---

## Siguiente paso recomendado

Luego de F2-P02, el siguiente avance logico es:

```text
F2-P03 -> Aplicacion tecnica de la matriz de permisos sobre vistas y acciones criticas
```

Ese punto debe revisar vista por vista y cerrar cualquier brecha entre la matriz documentada y la implementacion real.
MD

cat > docs/matriz_acceso_operativa_fase2.md <<'MD'
# Matriz de acceso operativa - Apps Emisiones Fase 2

## Objetivo

Este documento funciona como contrato operativo de permisos para Apps Emisiones durante la Fase 2.

Debe consultarse antes de crear nuevas vistas, acciones, workbenches o endpoints.

---

## Roles

```text
ADMINISTRADOR
SOLICITANTE
RESPONSABLE_UNIDAD
FINANZAS
CUENTAS_POR_PAGAR
AUDITOR
```

---

## Acciones criticas

| Accion critica | Roles permitidos | Resultado esperado si no tiene permiso |
|---|---|---|
| Crear solicitud | ADMINISTRADOR, SOLICITANTE | 403 o redireccion controlada |
| Enviar solicitud | ADMINISTRADOR, SOLICITANTE propietario | 403 / 404 segun exposicion |
| Aprobar solicitud | ADMINISTRADOR, RESPONSABLE_UNIDAD, FINANZAS segun paso | 403 |
| Rechazar solicitud | ADMINISTRADOR, RESPONSABLE_UNIDAD, FINANZAS segun paso | 403 |
| Ver pendientes de aprobacion | ADMINISTRADOR, RESPONSABLE_UNIDAD, FINANZAS | 403 |
| Ver cuentas por pagar | ADMINISTRADOR, FINANZAS, CUENTAS_POR_PAGAR | 403 |
| Registrar pago | ADMINISTRADOR, CUENTAS_POR_PAGAR | 403 |
| Ver auditoria | ADMINISTRADOR, AUDITOR | 403 |

---

## Politica practica

- El rol `ADMINISTRADOR` puede operar transversalmente.
- El rol `SOLICITANTE` no debe aprobar, pagar ni consultar auditoria transversal.
- El rol `RESPONSABLE_UNIDAD` participa en aprobaciones, no en pagos.
- El rol `FINANZAS` puede tener visibilidad financiera y aprobacion financiera si el flujo lo exige.
- El rol `CUENTAS_POR_PAGAR` ejecuta pagos, no aprueba pasos funcionales salvo decision posterior.
- El rol `AUDITOR` consulta trazabilidad, no ejecuta acciones de negocio.

---

## Regla para desarrollo futuro

Toda nueva funcionalidad debe declarar:

1. Roles permitidos.
2. Accion principal.
3. Nivel de acceso: lectura, escritura, aprobacion, ejecucion o auditoria.
4. Resultado esperado para acceso no autorizado.
5. Prueba automatizada minima.
MD

# Add a lightweight test module only if accounts app exists and Role choices can be discovered safely.
if [ -f backend/apps/accounts/models.py ]; then
  cat > backend/apps/accounts/tests/test_roles_contract.py <<'PY'
"""Role contract tests for Apps Emisiones Phase 2.

These tests intentionally validate the public role contract without changing
business flows or database schema.
"""

from django.test import SimpleTestCase

from apps.accounts.models import UserRole


class UserRoleContractTests(SimpleTestCase):
    def test_phase2_operational_roles_exist(self):
        expected_roles = {
            "ADMINISTRADOR",
            "SOLICITANTE",
            "RESPONSABLE_UNIDAD",
            "FINANZAS",
            "CUENTAS_POR_PAGAR",
            "AUDITOR",
        }

        current_roles = {role.value for role in UserRole}

        self.assertTrue(
            expected_roles.issubset(current_roles),
            f"Missing roles: {sorted(expected_roles - current_roles)}",
        )

    def test_roles_are_stable_uppercase_identifiers(self):
        for role in UserRole:
            self.assertEqual(role.value, role.value.upper())
            self.assertNotIn(" ", role.value)
PY
fi

echo "OK: documentos y pruebas F2-P02 creados/actualizados."
echo "- $ROOT/docs/f2_p02_roles_permisos_matriz_acceso.md"
echo "- $ROOT/docs/matriz_acceso_operativa_fase2.md"
if [ -f backend/apps/accounts/tests/test_roles_contract.py ]; then
  echo "- $ROOT/backend/apps/accounts/tests/test_roles_contract.py"
fi

echo "== Archivos modificados =="
git status --short
