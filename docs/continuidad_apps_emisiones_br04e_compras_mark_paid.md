# Apps Emisiones - Continuidad nuevo chat: BR04E Compras / Marcar emisión como pagada

## 1. Motivo del corte

La conversación ya tiene tamaño alto y el bloque actual acumula varios cambios, validaciones, scripts exitosos y scripts fallidos. Conviene continuar en un nuevo chat para evitar pérdida de precisión operativa.

Este documento garantiza continuidad para el proyecto **Apps Emisiones / Rutas de Emisión Oftalmi**.

---

## 2. Contexto general del proyecto

```text
Proyecto: Apps Emisiones
Repositorio: OftDevOps/emisiones
Ruta local Fedora: /home/dchirinos/oftalmiIA/emisiones/emisiones
Rama activa: develop
Stack: Django + PostgreSQL + Docker Compose
Interfaz MVP: Django Templates + HTMX
Idioma UI: Español
Regla operativa: scripts .sh descargables deben colocarse en /home/dchirinos/oftalmiIA/emisiones/emisiones/scripts/
```

Regla crítica Fedora/NordVPN:

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

nordvpn disconnect
sleep 3

# validaciones Docker/Django/HTTP aquí

nordvpn connect United_States
nordvpn status
```

NordVPN debe desconectarse antes de correr Docker/Django/curl local porque bloquea o interfiere con puertos locales.

---

## 3. Estado publicado antes del bloque pendiente

Último estado limpio y publicado confirmado:

```text
develop limpio y sincronizado con origin/develop
Últimos commits publicados:
ba0e83d style: update product branding to rutas de emision
bf0c7c2 style: update visible terminology to emisiones
fe1ab66 style: show full name in dashboard user card
8c34c00 style: improve pilot branding contrast
4124a3f fix: correct pilot readiness commit check
219141b chore: add pilot readiness check
```

BR04-A/B/C publicados:

```text
BR04-A/B: Terminología visible Solicitudes -> Emisiones
BR04-C: Branding parametrizado Rutas de Pago -> Rutas de Emisión
```

Commit BR04-C publicado:

```text
ba0e83d style: update product branding to rutas de emision
```

---

## 4. Comentarios del usuario piloto incorporados

### Comentario 1

El sistema no debe llamarse **Ruta de Pago**, porque el pago real se ejecuta en el ERP. El sistema debe llamarse **Rutas de Emisión** y el objeto principal visible debe ser **Emisión / Emisiones**, no Solicitud / Solicitudes.

Decisión aplicada:

```text
Sistema visible: Sistema de Rutas de Emisión
Nombre corto visible: Rutas de Emisión
Solicitud visible: Emisión
Solicitudes visibles: Emisiones
Nueva solicitud: Nueva emisión
```

Sin tocar todavía:

```text
Modelos Django
Migraciones
URLs técnicas
Apps internas payment_requests/payment_execution/accounts_payable
Tablas de BD
```

### Comentario 2

La emisión debe cargarse por ítems de factura, no solo por monto total. Cada ítem debe tener descripción, cantidad, monto base, IVA aplicable y cálculo de IVA por ítem y total. El porcentaje de IVA debe ser parametrizable, no hardcodeado.

Clasificación:

```text
BR05 - Bloqueante funcional para MVP real
```

Pendiente para fase siguiente:

```text
Diseñar modelo de ítems de emisión/factura.
Diseñar IVA parametrizable.
Diseñar formsets o UI dinámica para carga de ítems.
Calcular subtotal, IVA y total.
Validar contra factura adjunta.
Crear migraciones y pruebas.
```

### Comentario 3

El botón de **Cuentas por Pagar** no debe exponerse como tal. El departamento de **Compras** solo debe marcar si la emisión fue pagada o no. Si se marca como pagada, más adelante debe notificar, pero notificaciones quedan para otra fase.

Decisión piloto:

```text
Opción C para piloto:
Internamente puede seguir existiendo CUENTAS_POR_PAGAR.
Visualmente se muestra como Compras.
Ese perfil representa al responsable de marcar la emisión como pagada.
No crear rol COMPRAS todavía.
No tocar migraciones.
No renombrar URLs internas todavía.
```

---

## 5. Estado actual del working tree al momento del corte

Después de BR04D/BR04E, el working tree tiene cambios sin commit.

Archivos modificados reportados:

```text
M backend/apps/accounts/tests/test_role_navigation_integrated_matrix.py
M backend/apps/accounts/tests/test_role_navigation_template.py
M backend/apps/payment_requests/tests/test_dashboard.py
M backend/templates/accounts/dashboard.html
M backend/templates/base.html
M backend/templates/payment_execution/paymentexecution_form.html
M backend/templates/payment_requests/accounts_payable_pending.html
M backend/templates/payment_requests/paymentrequest_dashboard.html
M backend/templates/payment_requests/paymentrequest_detail.html
M backend/templates/registration/login.html
```

Scripts útiles o parcialmente útiles sin seguimiento:

```text
?? scripts/159_f2_pilot_br04d_hide_cxp_and_mark_paid_text.sh
?? scripts/161_f2_pilot_br04e_visible_compras_role_for_mark_paid.sh
?? scripts/167_f2_pilot_br04e_fix_escaped_quotes_and_validate.sh
?? scripts/168_f2_pilot_br04e_inspect_compras_mark_paid_visibility.sh
?? scripts/169_f2_pilot_br04e_inspect_compras_visibility_fixed.sh
```

Scripts fallidos que NO deben versionarse si existen localmente:

```text
scripts/160_f2_pilot_br04d_fix_unused_accounts_payable_import.sh
scripts/162_f2_pilot_br04e_fix_unused_accounts_payable_import.sh
scripts/163_f2_pilot_br04e_fix_compras_test_expectations.sh
scripts/164_f2_pilot_br04e_fix_compras_role_asserts.sh
scripts/165_f2_pilot_br04e_fix_final_compras_asserts.sh
scripts/166_f2_pilot_br04e_fix_compras_asserts_precise.sh
```

Algunos de esos scripts ya fueron eliminados en una recomendación, pero debe confirmarse con `git status --short`.

---

## 6. Validaciones técnicas ya ejecutadas

BR04E quedó técnicamente estable en tests después del fix 167:

```text
ruff: OK
Django check: OK
31 tests focales: OK
```

Los mensajes `Forbidden` y `Not Found` en salida de tests fueron esperados porque forman parte de pruebas de permisos. El suite terminó en OK.

---

## 7. Problema abierto real al corte

La validación visual con `cxp.demo@oftalmi.com` mostró que en:

```text
http://127.0.0.1:8001/payment-requests/3/
```

NO aparece la acción:

```text
Marcar emisión como pagada
```

La captura mostró:

```text
Usuario autenticado: cxp.demo@oftalmi.com
Header: Rutas de Emisión
Menú visible: Emisiones, Listado, Reporte
Detalle: Emisión #3
Estado: Aprobada
No aparece Compras en menú
No aparece Marcar emisión como pagada en detalle
```

Diagnóstico preliminar:

```text
Puede ser que cxp.demo@oftalmi.com no tenga rol CUENTAS_POR_PAGAR en runtime.
Puede ser que role_nav.can_view_accounts_payable no esté llegando al template.
Puede ser que la emisión #3 ya tenga payment_execution.
Puede ser que el botón solo exista dentro de la ruta técnica /execute-payment/ y no en el detalle.
Puede ser que el template detail use una condición distinta al dashboard.
```

No se debe hacer commit hasta resolver o documentar esta visibilidad.

---

## 8. Último intento fallido y corrección pendiente

Se generó y ejecutó:

```text
scripts/168_f2_pilot_br04e_inspect_compras_mark_paid_visibility.sh
```

Falló porque intentó importar un permiso inexistente:

```text
ImportError: cannot import name 'PERM_EXECUTE_PAYMENT' from 'apps.accounts.role_permissions'
```

Luego se generó el script corregido:

```text
scripts/169_f2_pilot_br04e_inspect_compras_visibility_fixed.sh
```

Este script aún NO fue ejecutado al momento del corte.

---

## 9. Primer paso obligatorio en nuevo chat

Ejecutar el script corregido de inspección:

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

chmod +x scripts/169_f2_pilot_br04e_inspect_compras_visibility_fixed.sh

nordvpn disconnect
sleep 3

./scripts/169_f2_pilot_br04e_inspect_compras_visibility_fixed.sh

nordvpn connect United_States
nordvpn status
```

Con esa salida se debe decidir el fix real.

---

## 10. Qué debe inspeccionar el script 169

La inspección debe confirmar:

```text
Rol real de cxp.demo@oftalmi.com.
Si cxp.demo tiene permiso de ver accounts_payable.
Contexto role_nav para cxp.demo.
Estado real de la emisión #3.
Si la emisión #3 ya tiene payment_execution.
Condiciones del template paymentrequest_detail.html para mostrar el botón.
Si la URL /payment-requests/accounts-payable/ responde para cxp.demo.
Si la URL /payment-requests/3/execute-payment/ responde para cxp.demo.
Si test client renderiza Compras / Marcar emisión como pagada.
```

---

## 11. Criterio funcional final BR04E

Para piloto:

```text
Solicitante: NO ve Compras.
Auditor: NO ve Compras.
Finanzas: puede ver sus opciones, pero no necesariamente Compras.
CUENTAS_POR_PAGAR: visualmente se presenta como Compras.
CUENTAS_POR_PAGAR/Compras: debe ver acceso Compras.
CUENTAS_POR_PAGAR/Compras: debe poder marcar emisión aprobada como pagada.
```

Textos esperados:

```text
Compras
Marcar emisión como pagada
Emisiones aprobadas pendientes de confirmación de pago
Total pendiente por confirmar
No hay emisiones aprobadas pendientes de confirmación de pago
```

No deben aparecer en UI principal:

```text
Cuentas por Pagar
Registrar pago en ERP
Solicitud de pago
Rutas de Pago
```

Nota: internamente pueden seguir existiendo nombres técnicos y URLs como `accounts_payable`, `payment_requests`, `payment_execution`.

---

## 12. Posibles fixes después de inspección

### Caso A: cxp.demo no tiene rol correcto

Si `cxp.demo@oftalmi.com` no es `CUENTAS_POR_PAGAR`, corregir datos demo localmente mediante script limpio. No crear migración.

### Caso B: role_nav no incluye can_view_accounts_payable

Revisar:

```text
backend/apps/accounts/context_processors.py
backend/apps/accounts/role_permissions.py
```

No cambiar permisos globales a ciegas.

### Caso C: detail no muestra botón aunque la URL existe

Revisar:

```text
backend/templates/payment_requests/paymentrequest_detail.html
backend/apps/payment_execution/views.py
backend/apps/payment_requests/views.py
```

Puede requerirse ajustar condición visible del botón para el perfil Compras.

### Caso D: emisión #3 ya tiene ejecución registrada

El botón no debe aparecer. Probar con otra emisión aprobada sin payment_execution, o crear dato demo para piloto.

---

## 13. Limpieza recomendada antes del commit final

Eliminar scripts fallidos si siguen sin seguimiento:

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

rm -f \
  scripts/160_f2_pilot_br04d_fix_unused_accounts_payable_import.sh \
  scripts/162_f2_pilot_br04e_fix_unused_accounts_payable_import.sh \
  scripts/163_f2_pilot_br04e_fix_compras_test_expectations.sh \
  scripts/164_f2_pilot_br04e_fix_compras_role_asserts.sh \
  scripts/165_f2_pilot_br04e_fix_final_compras_asserts.sh \
  scripts/166_f2_pilot_br04e_fix_compras_asserts_precise.sh
```

No borrar todavía `168` ni `169` hasta inspeccionar si aportan trazabilidad o deben descartarse.

---

## 14. Scripts candidatos a versionar si se confirma BR04E

Versionar solo scripts útiles:

```text
scripts/159_f2_pilot_br04d_hide_cxp_and_mark_paid_text.sh
scripts/161_f2_pilot_br04e_visible_compras_role_for_mark_paid.sh
scripts/167_f2_pilot_br04e_fix_escaped_quotes_and_validate.sh
```

Posiblemente versionar también:

```text
scripts/169_f2_pilot_br04e_inspect_compras_visibility_fixed.sh
```

Solo si fue útil para diagnóstico y quedó limpio.

No versionar scripts fallidos.

---

## 15. Commit recomendado cuando se cierre BR04E

Solo después de:

```text
- script 169 ejecutado
- causa identificada
- visibilidad corregida
- ruff OK
- Django check OK
- tests focales OK
- validación visual OK con cxp.demo@oftalmi.com
```

Commit recomendado:

```bash
cd /home/dchirinos/oftalmiIA/emisiones/emisiones

git diff --check

git add \
  backend/templates/registration/login.html \
  backend/templates/base.html \
  backend/templates/accounts/dashboard.html \
  backend/templates/payment_requests/paymentrequest_dashboard.html \
  backend/templates/payment_requests/accounts_payable_pending.html \
  backend/templates/payment_requests/paymentrequest_detail.html \
  backend/templates/payment_execution/paymentexecution_form.html \
  backend/apps/accounts/tests/test_role_navigation_template.py \
  backend/apps/accounts/tests/test_role_navigation_integrated_matrix.py \
  backend/apps/payment_requests/tests/test_dashboard.py \
  scripts/159_f2_pilot_br04d_hide_cxp_and_mark_paid_text.sh \
  scripts/161_f2_pilot_br04e_visible_compras_role_for_mark_paid.sh \
  scripts/167_f2_pilot_br04e_fix_escaped_quotes_and_validate.sh

# Agregar scripts adicionales solo si son útiles y limpios.

git commit -m "style: show compras as mark paid owner in pilot UI"

git push origin develop

git status
```

---

## 16. Qué NO tocar en este bloque

No tocar todavía:

```text
Modelos Django
Migraciones
Renombrado de apps
Renombrado de URLs
Renombrado de tablas
Creación formal del rol COMPRAS
Sistema de notificaciones
Carga por ítems de factura
IVA parametrizable
Integración ERP
```

Esos temas quedan para BR05 o fases posteriores.

---

## 17. Próximo bloque después de BR04E

Después de cerrar y publicar BR04E, el siguiente bloque fuerte será:

```text
BR05 - Diseño e implementación de emisión por ítems de factura con IVA parametrizable
```

Antes de codificar BR05, se debe diseñar contrato funcional y modelo de datos.

Pendientes de BR05:

```text
Modelo EmissionItem / PaymentRequestItem o nombre técnico equivalente.
Campos: descripción, cantidad, base imponible, porcentaje IVA, monto IVA, total ítem.
Totalización: subtotal, IVA total, total factura.
Validaciones.
Formset / UI dinámica.
Pruebas unitarias y de integración.
Migración controlada.
```

---

## 18. Mensaje inicial sugerido para el nuevo chat

Copiar y pegar:

```text
Estoy continuando Apps Emisiones / Rutas de Emisión Oftalmi.
Usa este documento de continuidad.

Estado publicado:
- develop limpio hasta ba0e83d.
- BR04-A/B/C publicados: terminología visible Emisiones y branding Rutas de Emisión.

Estado actual no commiteado:
- BR04D/BR04E aplicados parcialmente en working tree.
- Se busca mostrar internamente CUENTAS_POR_PAGAR como Compras para piloto.
- Compras debe poder ver la acción Marcar emisión como pagada.
- Tests focales pasaron después de script 167.
- Validación visual con cxp.demo mostró que no aparece Compras ni Marcar emisión como pagada en /payment-requests/3/.
- El script 168 falló por importar PERM_EXECUTE_PAYMENT inexistente.
- El script 169 corregido está pendiente de ejecución.

Primer paso:
cd /home/dchirinos/oftalmiIA/emisiones/emisiones
chmod +x scripts/169_f2_pilot_br04e_inspect_compras_visibility_fixed.sh
nordvpn disconnect
sleep 3
./scripts/169_f2_pilot_br04e_inspect_compras_visibility_fixed.sh
nordvpn connect United_States
nordvpn status

Objetivo inmediato:
Diagnosticar por qué cxp.demo no ve Compras / Marcar emisión como pagada, corregir sin tocar modelos/migraciones, validar visualmente, limpiar scripts fallidos y commitear BR04E.
```
