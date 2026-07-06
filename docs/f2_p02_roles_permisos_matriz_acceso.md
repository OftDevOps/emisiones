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
