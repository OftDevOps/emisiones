# Sistema de Rutas de Pago Oftalmi

**Documento:** Alcance funcional, reglas de negocio, ciberseguridad, ingeniería de software y DevOps  
**Proyecto:** Sistema de Rutas de Pago Oftalmi  
**Nombre técnico sugerido:** `oftalmi-payment-routes`  
**Empresa inicial:** Laboratorios Oftalmi  
**Preparado para expansión futura:** Empresas del grupo  
**Idioma principal:** Español  
**Idioma secundario:** Inglés  
**Fecha:** 2026-07-01  

---

## 1. Resumen ejecutivo

El **Sistema de Rutas de Pago Oftalmi** será una aplicación web empresarial para gestionar solicitudes de pago, facturas, adelantos, pagos programados y otros compromisos económicos mediante rutas aprobatorias dinámicas, auditables y controladas.

El sistema permitirá que un usuario autorizado cargue una solicitud de pago correspondiente a su unidad, departamento, área o gerencia. La solicitud avanzará por una ruta de aprobación configurable, con nodos como Finanzas, Gerencia General, Junta Directiva y Cuentas por Pagar, hasta llegar a la ejecución final del pago.

La aplicación tendrá como principios centrales:

- Control por unidad organizativa.
- Aprobación por nodos.
- Reglas dinámicas según monto, empresa, tipo de pago, moneda y otros criterios.
- Documentos soporte digitales visibles para los aprobadores.
- Notificaciones por app interna, correo corporativo y Microsoft Teams.
- Bandejas de trabajo por responsabilidad.
- Auditoría completa.
- Versionamiento histórico de rutas.
- Preparación para futura operación multiempresa.
- Ciberseguridad aplicada desde el diseño.
- Ingeniería de software para calidad, mantenibilidad y trazabilidad del desarrollo.
- Ingeniería DevOps para despliegue, operación, respaldo, monitoreo y continuidad.

---

## 2. Definición del sistema

### 2.1 Nombre funcional

**Sistema de Rutas de Pago Oftalmi**

### 2.2 Nombre técnico sugerido

`oftalmi-payment-routes`

### 2.3 Concepto principal

El sistema gestionará solicitudes de pago mediante rutas aprobatorias configurables, donde cada solicitud tendrá una ruta asignada, nodos responsables, tareas pendientes, documentos soporte, acciones de aprobación, devolución o rechazo, notificaciones y trazabilidad hasta la ejecución final del pago.

### 2.4 Enfoque correcto del sistema

El sistema no debe entenderse como una simple aplicación de emisión de pagos.

El flujo correcto es:

```text
Solicitud
  -> Evaluación de reglas
  -> Asignación de ruta versionada
  -> Snapshot histórico de ruta
  -> Nodos aprobatorios
  -> Tareas de flujo
  -> Notificaciones
  -> Aprobación / devolución / rechazo
  -> Cuentas por Pagar
  -> Ejecución del pago
  -> Auditoría y cierre
```

---

## 3. Alcance organizacional

### 3.1 Alcance inicial

El MVP se implementará inicialmente para **Laboratorios Oftalmi**.

### 3.2 Visión futura

La arquitectura deberá quedar preparada para soportar otras empresas del grupo.

### 3.3 Regla multiempresa

Aunque el MVP opere inicialmente con una sola empresa, las entidades principales deberán contemplar el campo `empresa` desde el inicio.

Ejemplos de entidades que deben tener relación con empresa:

- Solicitudes de pago.
- Proveedores o beneficiarios.
- Cuentas bancarias.
- Rutas de pago.
- Reglas de ruta.
- Pagos programados.
- Reportes.
- Auditoría.

---

## 4. Branding e identidad visual

### 4.1 Identidad visual inicial

La app utilizará la identidad visual de Laboratorios Oftalmi en el MVP.

### 4.2 Colores corporativos definidos

| Color | Código |
|---|---|
| Azul principal | `#1226AA` |
| Morado | `#8A1A9B` |
| Amarillo | `#FFE800` |
| Celeste | `#6FCFEB` |

### 4.3 Elemento gráfico institucional

El área de diseño gráfico utiliza el **contorno de una cápsula** como elemento visual. Este recurso podrá incorporarse en:

- Login.
- Header.
- Sidebar.
- Dashboard.
- Cards.
- Separadores gráficos.
- Reportes.
- Pantallas de estado.

### 4.4 Logo

El usuario deberá suministrar el logo oficial de Oftalmi para incorporarlo en la interfaz.

### 4.5 Reglas de branding

| Código | Regla |
|---|---|
| BRAND-001 | La app utilizará la identidad visual de Oftalmi en el MVP. |
| BRAND-002 | Se utilizarán los colores `#1226AA`, `#8A1A9B`, `#FFE800` y `#6FCFEB`. |
| BRAND-003 | Se podrá incorporar el contorno de una cápsula como recurso visual institucional. |
| BRAND-004 | El logo oficial deberá ser suministrado por el usuario o el área de diseño. |
| BRAND-005 | La identidad visual deberá quedar preparada para futura parametrización por empresa. |

---

## 5. Idiomas y convención técnica

### 5.1 Idiomas del sistema

- Idioma por defecto: **Español**.
- Idioma secundario: **Inglés**.

### 5.2 Convención recomendada

| Elemento | Idioma recomendado |
|---|---|
| Código fuente | Inglés |
| Modelos Django | Inglés |
| Campos técnicos | Inglés |
| APIs | Inglés |
| Base de datos | Inglés |
| Interfaz de usuario | Español por defecto |
| Mensajes del sistema | Español por defecto, traducibles |
| Reportes | Español por defecto |
| Documentación funcional | Español |
| Documentación técnica | Español con términos técnicos en inglés cuando aplique |

### 5.3 Regla principal de idioma

Todo texto visible al usuario debe ser traducible.

---

## 6. Stack tecnológico definido

### 6.1 Stack recomendado

| Capa | Tecnología |
|---|---|
| Backend | Python + Django |
| API | Django REST Framework |
| Frontend MVP | Django Templates + HTMX |
| Frontend futuro | React + react-i18next |
| Base de datos | PostgreSQL |
| Infraestructura | Docker + Docker Compose |
| Servidor | Ubuntu Server o Debian |
| Web server | Nginx |
| App server | Gunicorn |
| Tareas asíncronas | Celery + Redis |
| Notificaciones | App interna, correo corporativo, Microsoft Teams |
| Auditoría | Modelo propio |
| Autenticación | Email como username; preparado para Microsoft Entra ID |

### 6.2 Decisión técnica clave

Para el MVP se recomienda iniciar con **Django Templates + HTMX** para acelerar el desarrollo y reducir complejidad. React podrá incorporarse posteriormente donde realmente aporte valor.

---
### 6.3 Enfoque obligatorio de ingeniería

El proyecto deberá abordarse con tres ejes técnicos obligatorios:

```text
Ingeniería de software
Ingeniería DevOps
Ciberseguridad desde el diseño
```

Esto significa que la aplicación no se desarrollará solo como un conjunto de pantallas, sino como una plataforma empresarial con reglas, control de cambios, pruebas, documentación, despliegue reproducible, trazabilidad, seguridad y operación sostenible.

---

## 7. Ingeniería de software

### 7.1 Principio

El desarrollo debe seguir prácticas formales de ingeniería de software para evitar deuda técnica temprana, facilitar mantenimiento y permitir evolución funcional del sistema.

### 7.2 Prácticas mínimas

```text
Arquitectura modular por dominios funcionales.
Separación clara entre modelos, servicios, vistas, formularios, permisos y tareas asíncronas.
Reglas de negocio centralizadas en servicios o capas de dominio, no dispersas en templates.
Uso de migraciones controladas de base de datos.
Convenciones de nombres en inglés técnico.
Documentación viva en Markdown.
Control de versiones con Git.
Backlog por fases.
Criterios de aceptación por historia de usuario.
Pruebas unitarias para reglas críticas.
Pruebas de integración para rutas, aprobaciones, rechazos y pagos.
Revisión de código antes de fusionar cambios.
```

### 7.3 Estructura documental del proyecto

El repositorio debe incluir una carpeta `docs/` con documentación mínima:

```text
docs/
├── alcance.md
├── reglas_negocio.md
├── arquitectura.md
├── modelo_datos.md
├── roles_permisos.md
├── flujos_aprobacion.md
├── seguridad.md
├── devops.md
├── auditoria.md
├── decisiones_arquitectonicas.md
└── backlog_mvp.md
```

### 7.4 Reglas de ingeniería de software

```text
SE-001
El proyecto deberá mantener documentación funcional y técnica versionada en el repositorio.

SE-002
Las reglas críticas de negocio no deberán implementarse directamente en templates ni vistas sin capa de servicio.

SE-003
Toda historia funcional crítica deberá tener criterios de aceptación.

SE-004
Las rutas de pago, aprobaciones, rechazos, devoluciones, auditoría y ejecución de pago deberán tener pruebas automatizadas mínimas.

SE-005
El código deberá pasar revisión antes de integrarse a la rama principal.

SE-006
Los cambios de modelo deberán realizarse mediante migraciones controladas.

SE-007
Las decisiones técnicas relevantes deberán documentarse como decisiones arquitectónicas.
```

---

## 8. Ingeniería DevOps

### 8.1 Principio

El sistema debe diseñarse para ser desplegable, respaldable, monitoreable y recuperable desde el inicio. No basta con que funcione en desarrollo.

### 8.2 Ambientes recomendados

```text
local      Desarrollo local del programador.
dev        Ambiente de desarrollo integrado.
staging    Ambiente de pruebas funcionales/UAT.
prod       Ambiente productivo.
```

Para el MVP puede iniciarse con `local` y `dev`, pero la configuración debe permitir escalar a `staging` y `prod`.

### 8.3 Componentes operativos

```text
Docker Compose para desarrollo y despliegue inicial.
Variables de entorno mediante .env.
Nginx como reverse proxy.
Gunicorn como servidor de aplicación.
PostgreSQL como base de datos.
Redis para tareas asíncronas.
Celery para notificaciones, recordatorios y tareas programadas.
Scripts de backup y restore.
Logs estructurados.
Monitoreo básico de salud del servicio.
```

### 8.4 CI/CD recomendado

El pipeline deberá ejecutar como mínimo:

```text
Instalación de dependencias.
Validación de formato/linting.
Ejecución de pruebas.
Validación de migraciones.
Construcción de imagen Docker.
Despliegue controlado al ambiente correspondiente.
```

### 8.5 Respaldo y recuperación

El sistema debe contemplar respaldo de:

```text
Base de datos PostgreSQL.
Documentos soporte cargados.
Archivos de configuración no sensibles.
Logs relevantes.
```

Los respaldos deben tener prueba de restauración. Un backup que no ha sido probado no debe considerarse confiable.

### 8.6 Reglas DevOps

```text
DEVOPS-001
El proyecto deberá ejecutarse mediante Docker y Docker Compose desde el inicio.

DEVOPS-002
Las configuraciones sensibles deberán manejarse mediante variables de entorno y no dentro del código fuente.

DEVOPS-003
El repositorio deberá incluir archivo .env.example sin secretos reales.

DEVOPS-004
El sistema deberá tener scripts documentados de backup y restore.

DEVOPS-005
Toda salida a producción deberá ser reproducible y documentada.

DEVOPS-006
El sistema deberá registrar logs útiles para diagnóstico operativo sin exponer datos sensibles.

DEVOPS-007
El sistema deberá tener healthchecks básicos para backend, base de datos y servicios críticos.

DEVOPS-008
Se deberá aplicar una estrategia de ramas Git para desarrollo, pruebas y producción, basada en `main`, `develop`, `feature/*`, `fix/*`, `hotfix/*` y `release/*`.
```


### 8.7 Estrategia de ramas Git

El repositorio deberá operar con un flujo de ramas controlado. La rama `main` queda reservada para versiones estables, validadas y listas para producción. El desarrollo diario deberá integrarse en `develop`, y todo cambio funcional o correctivo deberá realizarse mediante ramas específicas.

```text
main        Versión estable / producción.
develop     Integración de desarrollo.
feature/*   Nuevas funcionalidades.
fix/*       Correcciones no urgentes.
hotfix/*    Correcciones urgentes sobre producción.
release/*   Preparación de versión estable.
```

#### 8.7.1 Rama `main`

```text
La rama main solo contendrá versiones estables.
No se deberá desarrollar directamente sobre main.
No se deberá hacer push directo a main.
Todo cambio hacia main debe venir desde release/* o hotfix/*, con validación previa.
```

#### 8.7.2 Rama `develop`

```text
La rama develop será la rama principal de integración técnica y funcional.
Todas las funcionalidades aprobadas se integrarán primero en develop.
Las pruebas funcionales iniciales y validaciones técnicas deberán ejecutarse sobre develop o ramas derivadas.
```

#### 8.7.3 Ramas `feature/*`

Se usarán para nuevas funcionalidades.

Ejemplos:

```text
feature/django-base-project
feature/auth-email-login
feature/payment-request-documents
feature/workflow-routes
feature/approval-actions
feature/payment-execution
```

Flujo recomendado:

```bash
git checkout develop
git pull origin develop
git checkout -b feature/nombre-funcionalidad
```

Al finalizar:

```bash
git add .
git commit -m "feat: descripcion clara de la funcionalidad"
git push -u origin feature/nombre-funcionalidad
```

Luego se deberá integrar mediante Pull Request hacia `develop`.

#### 8.7.4 Ramas `fix/*`

Se usarán para correcciones no urgentes detectadas durante desarrollo o pruebas.

Ejemplos:

```text
fix/docker-compose-env
fix/payment-status-validation
fix/document-upload-permissions
```

Las ramas `fix/*` deben salir de `develop` y volver a `develop`.

#### 8.7.5 Ramas `hotfix/*`

Se usarán solo para corregir errores críticos sobre una versión estable en `main`.

Regla:

```text
Todo hotfix debe integrarse primero a main y luego también a develop para evitar divergencia.
```

#### 8.7.6 Ramas `release/*`

Se usarán para preparar una versión estable antes de llevarla a `main`.

Ejemplo:

```text
release/v0.1.0
release/v1.0.0
```

Uso recomendado:

```bash
git checkout develop
git pull origin develop
git checkout -b release/v0.1.0
```

Luego de validar:

```bash
git checkout main
git merge release/v0.1.0
git push origin main
```

Después se deberá sincronizar `develop`:

```bash
git checkout develop
git merge main
git push origin develop
```

#### 8.7.7 Convención de commits

Los mensajes de commit deberán ser claros y seguir una convención mínima:

```text
chore: cambios operativos, estructura o configuración
feat: nueva funcionalidad
fix: corrección de error
docs: documentación
refactor: refactorización sin cambio funcional
test: pruebas
ci: integración continua / pipelines
security: cambios de seguridad
```

Ejemplos:

```text
chore: initialize emisiones project structure
docs: add git flow policy
feat: add email based authentication
fix: adjust docker compose environment variables
security: enforce document access permissions
```

#### 8.7.8 Reglas de control de ramas

```text
BRANCH-001
La rama main contendrá únicamente versiones estables, validadas y listas para producción.

BRANCH-002
La rama develop será la rama principal de integración de desarrollo.

BRANCH-003
Toda nueva funcionalidad deberá desarrollarse en ramas feature/* creadas desde develop.

BRANCH-004
Toda corrección no urgente deberá desarrollarse en ramas fix/* creadas desde develop.

BRANCH-005
Toda corrección urgente de producción deberá desarrollarse en ramas hotfix/* creadas desde main.

BRANCH-006
Todo hotfix integrado a main deberá integrarse también a develop.

BRANCH-007
Las ramas release/* se utilizarán para preparar versiones estables antes de fusionar a main.

BRANCH-008
No se deberá hacer push directo a main.

BRANCH-009
Todo cambio hacia main debe pasar por validación técnica y funcional previa.

BRANCH-010
Los cambios relevantes deberán quedar documentados mediante commits claros, Pull Requests y documentación asociada cuando aplique.
```

---

## 9. Ciberseguridad

### 9.1 Principio

La ciberseguridad debe estar integrada al diseño funcional y técnico. El sistema gestionará información financiera, soportes documentales y decisiones aprobatorias, por lo tanto requiere controles mínimos de confidencialidad, integridad, disponibilidad, trazabilidad y segregación de funciones.

### 9.2 Controles mínimos de seguridad

```text
Autenticación por correo institucional.
Preparación para Microsoft Entra ID.
Control de acceso basado en roles y nodos.
Restricción por unidad organizativa.
Principio de mínimo privilegio.
Segregación de funciones.
Validación estricta de permisos en backend.
Protección de documentos soporte.
Auditoría de acciones críticas.
Protección CSRF y sesiones seguras.
Validación de archivos cargados.
Restricción de tipos y tamaños de archivo.
Hash de documentos para integridad.
Logs sin exposición de información sensible.
Backups protegidos.
Uso de HTTPS en producción.
```

### 9.3 Seguridad documental

Los documentos soporte no deberán enviarse como adjuntos en correos o Teams. Las notificaciones deberán incluir enlaces seguros hacia la solicitud dentro de la app.

El acceso a documentos debe depender de:

```text
Rol del usuario.
Unidad organizativa.
Nodo actual.
Participación histórica en la ruta.
Permisos explícitos.
```

### 9.4 Amenazas a considerar

```text
Acceso no autorizado a solicitudes de otras unidades.
Aprobación por usuario no perteneciente al nodo.
Modificación no autorizada de monto, proveedor o documentos.
Carga de archivos maliciosos.
Pérdida o alteración de documentos soporte.
Reinterpretación histórica de rutas por cambios posteriores.
Ejecución de pagos sin aprobación completa.
Exposición de información sensible por notificaciones externas.
Pérdida de trazabilidad por auditoría incompleta.
```

### 9.5 Reglas de ciberseguridad

```text
SEC-001
El sistema deberá aplicar principio de mínimo privilegio.

SEC-002
Toda acción crítica deberá validarse en backend, aunque la interfaz oculte botones al usuario.

SEC-003
El sistema no permitirá aprobar, rechazar, devolver o pagar si el usuario no tiene permiso explícito para el nodo y acción correspondiente.

SEC-004
Los documentos soporte deberán almacenarse de forma controlada y no exponerse mediante rutas públicas.

SEC-005
Todo documento cargado deberá validar extensión, tipo MIME, tamaño y, cuando aplique, hash de integridad.

SEC-006
Las notificaciones externas no deberán incluir documentos adjuntos ni datos financieros excesivos.

SEC-007
El sistema deberá registrar auditoría de autenticación, creación, modificación, aprobación, rechazo, devolución, visualización documental y ejecución de pago.

SEC-008
Los secretos, tokens, contraseñas y credenciales no deberán almacenarse en el repositorio.

SEC-009
Producción deberá operar bajo HTTPS.

SEC-010
Los respaldos deberán protegerse contra acceso no autorizado.

SEC-011
El sistema deberá estar preparado para MFA mediante Microsoft Entra ID en una fase posterior.

SEC-012
Toda excepción de seguridad o corrección manual de ruta deberá exigir motivo obligatorio y auditoría completa.
```

---

## 10. Estructura Django recomendada

```text
backend/apps/
│
├── accounts/
├── organization/
├── beneficiaries/
├── finance/
├── payment_requests/
├── payment_documents/
├── scheduled_payments/
├── payment_routes/
├── workflow_tasks/
├── approvals/
├── notifications/
├── accounts_payable/
├── payment_execution/
├── reports/
├── audit/
└── integrations/
```

Dentro de `integrations/`:

```text
integrations/
└── microsoft365/
    ├── email/
    ├── teams/
    └── entra_id/
```

---

## 11. Autenticación y usuarios

### 11.1 Regla principal

El ingreso al sistema será mediante **correo electrónico**.

El correo será el identificador único del usuario.

### 11.2 Preparación futura

El sistema debe quedar preparado para integrarse con Microsoft 365 / Microsoft Entra ID.

### 11.3 Reglas de autenticación

| Código | Regla |
|---|---|
| AUTH-001 | El ingreso al sistema será mediante correo electrónico. |
| AUTH-002 | El correo será único y obligatorio. |
| AUTH-003 | El correo institucional será usado para notificaciones. |
| AUTH-004 | El sistema deberá quedar preparado para integración futura con Microsoft 365 / Entra ID. |
| AUTH-005 | El usuario podrá pertenecer a una unidad, departamento, área, gerencia o nodo aprobatorio. |

---

## 12. Roles definidos

### 12.1 Roles mínimos para el MVP

| Rol | Descripción |
|---|---|
| ADMINISTRADOR | Configura usuarios, roles, rutas, reglas y parámetros del sistema. |
| SOLICITANTE | Carga solicitudes de pago correspondientes a su unidad autorizada. |
| RESPONSABLE_UNIDAD | Aprueba, devuelve o rechaza solicitudes de su unidad. |
| FINANZAS | Revisa y aprueba solicitudes desde el punto de vista financiero/documental. |
| GERENCIA_GENERAL | Aprueba solicitudes según reglas de monto o política. |
| JUNTA_DIRECTIVA | Aprueba solicitudes de mayor jerarquía, usualmente por monto alto o regla especial. |
| CUENTAS_POR_PAGAR | Gestiona pagos aprobados pendientes por ejecutar. |
| AUDITOR | Consulta trazabilidad, rutas históricas, documentos y acciones. |

### 12.2 Roles ampliados para fases posteriores

| Rol | Uso esperado |
|---|---|
| ANALISTA_FINANZAS | Revisión documental o financiera sin aprobación final. |
| APROBADOR_FINANZAS | Aprobación formal dentro del nodo Finanzas. |
| TESORERIA | Registro o confirmación bancaria del pago. |
| CONSULTA | Consulta limitada según permisos. |
| SUPERVISOR | Seguimiento operativo y escalamiento. |
| ADMINISTRADOR_FUNCIONAL | Configuración funcional sin control técnico total. |
| ADMINISTRADOR_TECNICO | Administración técnica del sistema. |

### 12.3 Regla de roles vs nodos

Un rol define permisos.  
Un nodo define dónde está la solicitud dentro de la ruta.

Ejemplo:

```text
Rol: FINANZAS
Nodo: Finanzas
Acción permitida: Revisar / aprobar / devolver / rechazar según permiso
```

---

## 13. Segregación de funciones

| Código | Regla |
|---|---|
| SEG-001 | Quien crea una solicitud no debería ejecutarla como pago. |
| SEG-002 | Quien aprueba financieramente no debería registrar la ejecución bancaria final, salvo excepción autorizada. |
| SEG-003 | Quien administra el sistema no debe modificar rutas o pagos sin motivo obligatorio y auditoría. |
| SEG-004 | Un usuario puede tener varios roles, pero cada acción debe validarse contra el nodo actual. |
| SEG-005 | No se puede aprobar una solicitud si el usuario no pertenece al nodo actual. |
| SEG-006 | No se puede ejecutar un pago si la ruta aprobatoria no está completa. |

---

## 14. Solicitudes de pago

### 14.1 Definición

La solicitud de pago será el expediente principal del sistema.

### 14.2 Campos mínimos

- Empresa.
- Unidad solicitante.
- Solicitante.
- Proveedor o beneficiario.
- Tipo de pago.
- Monto.
- Moneda.
- Concepto.
- Fecha de solicitud.
- Fecha requerida de pago.
- Documentos adjuntos.
- Observaciones.
- Estado actual.
- Ruta asignada.
- Historial.

### 14.3 Tipos de solicitud contemplados

- Factura.
- Adelanto.
- Reembolso.
- Pago de servicio.
- Pago recurrente.
- Pago sin documento fiscal.
- Pago extraordinario.
- Reposición de caja chica.
- Otro.

### 14.4 Reglas de solicitudes

| Código | Regla |
|---|---|
| PAYREQ-001 | Toda solicitud debe tener empresa, unidad solicitante, solicitante, tipo de pago, monto, moneda y concepto. |
| PAYREQ-002 | Toda solicitud debe tener documentos obligatorios, salvo pagos definidos como adelantos o pagos sin documento. |
| PAYREQ-003 | Una solicitud debe iniciar como borrador antes de enviarse a ruta. |
| PAYREQ-004 | Una solicitud enviada a ruta no debe permitir cambios críticos sin control. |
| PAYREQ-005 | Cambios en monto, proveedor, empresa, unidad o documentos críticos deben generar auditoría y podrían reiniciar la ruta. |

---

## 15. Gestión documental de soportes de pago

### 15.1 Principio central

Todo pago debe tener un documento soporte digital visible para los aprobadores, excepto adelantos de pago u otros casos formalmente permitidos.

### 15.2 Documentos soportados en el MVP

- PDF.
- JPG.
- PNG.
- XLSX.
- DOCX.

### 15.3 Documentos soportados en fases posteriores

- EML.
- MSG.
- Otros formatos autorizados.

### 15.4 Tipos de documentos

- Factura.
- Nota de entrega.
- Orden de compra.
- Presupuesto.
- Recibo.
- Comprobante.
- Correo soporte.
- Documento fiscal.
- Documento no fiscal.
- Otro soporte.

### 15.5 Reglas documentales

| Código | Regla |
|---|---|
| DOC-001 | Todo pago debe tener documento soporte digital, salvo adelantos de pago u otras excepciones definidas por política. |
| DOC-002 | Los documentos físicos deberán digitalizarse y cargarse antes de iniciar la ruta aprobatoria. |
| DOC-003 | Los adelantos de pago podrán iniciar sin documento fiscal, pero deberán tener justificación obligatoria. |
| DOC-004 | Los aprobadores deberán poder visualizar los documentos soporte desde la solicitud antes de aprobar, devolver o rechazar. |
| DOC-005 | El sistema deberá registrar auditoría de carga, visualización, reemplazo, eliminación lógica y descarga de documentos, cuando aplique. |
| DOC-006 | Las notificaciones por correo o Teams no deberán adjuntar documentos; deberán incluir enlace seguro a la solicitud. |
| DOC-007 | El acceso a documentos estará controlado por rol, nodo actual, unidad organizativa y permisos asignados. |
| DOC-008 | El reemplazo de documentos críticos deberá exigir motivo obligatorio y mantener trazabilidad. |
| DOC-009 | El sistema deberá permitir identificar documentos obligatorios, opcionales, fiscales y no fiscales. |
| DOC-010 | No se podrá aprobar una solicitud que tenga documentos obligatorios pendientes, rechazados o no cargados. |

### 15.6 Metadatos mínimos de documentos

- Solicitud asociada.
- Tipo de documento.
- Nombre original del archivo.
- Archivo almacenado.
- Formato.
- Tamaño.
- Hash del archivo.
- Versión.
- Usuario que cargó.
- Fecha de carga.
- Estado.
- Comentario.
- Es obligatorio.
- Es documento fiscal.
- Está vigente.

---

## 16. Rutas de pago

### 16.1 Definición

Una ruta de pago es el flujo que debe seguir una solicitud hasta su aprobación y pago.

### 16.2 Ejemplos de rutas

#### Ruta simple

```text
Solicitante -> Finanzas -> Cuentas por Pagar -> Pago
```

#### Ruta con Gerencia General

```text
Solicitante -> Finanzas -> Gerencia General -> Cuentas por Pagar -> Pago
```

#### Ruta con Junta Directiva

```text
Solicitante -> Finanzas -> Gerencia General -> Junta Directiva -> Cuentas por Pagar -> Pago
```

### 16.3 Reglas de rutas

| Código | Regla |
|---|---|
| ROUTE-001 | Toda solicitud debe tener una ruta asignada antes de iniciar aprobación. |
| ROUTE-002 | La ruta debe seleccionarse mediante reglas configurables. |
| ROUTE-003 | La ruta puede depender de monto, moneda, empresa, unidad, tipo de pago, proveedor o regla especial. |
| ROUTE-004 | El nodo inicial siempre corresponde al solicitante o responsable de la unidad. |
| ROUTE-005 | El nodo final corresponde al área que realiza, registra o confirma el pago. |
| ROUTE-006 | Una ruta puede tener nodos obligatorios y condicionales. |
| ROUTE-007 | Dependiendo del monto, la solicitud puede requerir Gerencia General o Junta Directiva. |
| ROUTE-008 | La solicitud debe avanzar automáticamente al siguiente nodo aplicable cuando un nodo aprueba. |

---

## 17. Reglas de ruta por monto

### 17.1 Principio

Dependiendo del monto, la solicitud puede requerir aprobación de Gerencia General o Junta Directiva.

### 17.2 Ejemplo conceptual

```text
Monto bajo:
Solicitante -> Finanzas -> Cuentas por Pagar -> Pago

Monto medio:
Solicitante -> Finanzas -> Gerencia General -> Cuentas por Pagar -> Pago

Monto alto:
Solicitante -> Finanzas -> Gerencia General -> Junta Directiva -> Cuentas por Pagar -> Pago
```

### 17.3 Nota pendiente

Los montos exactos deben ser definidos posteriormente con Finanzas, Gerencia General o Junta Directiva.

---

## 18. Nodos aprobatorios

### 18.1 Definición

Cada nodo representa un punto de revisión, aprobación, rechazo, devolución o ejecución.

### 18.2 Datos mínimos de un nodo

- Nombre.
- Tipo.
- Orden dentro de la ruta.
- Responsables.
- Rol asociado.
- Modo de aprobación.
- Estado.
- Fecha de entrada.
- Fecha de notificación.
- Fecha de decisión.
- Usuario que decidió.
- Comentario.
- SLA esperado.

### 18.3 Acciones posibles del nodo

- Aprobar.
- Rechazar.
- Devolver.
- Solicitar corrección.
- Agregar observación.
- Delegar, si se permite.

### 18.4 Reglas de nodos

| Código | Regla |
|---|---|
| NODE-001 | Cada nodo debe tener responsables definidos. |
| NODE-002 | Cada nodo debe tener un modo de aprobación. |
| NODE-003 | Un nodo puede aprobarse por usuario específico, por cualquiera de varios usuarios, por rol o por aprobación múltiple. |
| NODE-004 | Un usuario no puede aprobar una solicitud si no pertenece al nodo actual. |
| NODE-005 | Cada acción del nodo debe quedar auditada. |

---

## 19. Bandejas de trabajo

### 19.1 Principio

La bandeja interna de la app será la fuente oficial de tareas pendientes.

### 19.2 Bandejas mínimas

- Mis solicitudes.
- Pendientes por aprobar.
- Pendientes por revisar.
- Pendientes por corregir.
- Pendientes de Finanzas.
- Pendientes de Gerencia General.
- Pendientes de Junta Directiva.
- Pendientes de Cuentas por Pagar.
- Pagos aprobados pendientes por ejecutar.
- Pagos en proceso.
- Pagos realizados.
- Solicitudes rechazadas.
- Solicitudes devueltas.
- Historial.

---

## 20. Tareas de flujo

### 20.1 Concepto técnico

`WorkflowTask`

### 20.2 Función

Cada pendiente real debe existir como una tarea de flujo.

### 20.3 Datos mínimos

- Solicitud asociada.
- Nodo actual.
- Responsable.
- Tipo de tarea.
- Estado.
- Fecha de creación.
- Fecha de notificación.
- Fecha de vencimiento.
- Fecha de cierre.
- Usuario que completó.
- Acción realizada.
- Comentario.

### 20.4 Tipos de tarea

- Aprobar solicitud.
- Revisar solicitud.
- Corregir solicitud.
- Ejecutar pago.
- Confirmar pago.

### 20.5 Reglas de tareas

| Código | Regla |
|---|---|
| TASK-001 | Cada solicitud pendiente en un nodo debe generar una tarea de flujo. |
| TASK-002 | Cada usuario debe tener una bandeja de pendientes según su rol y nodo. |
| TASK-003 | Cuentas por Pagar debe tener una bandeja de pagos aprobados pendientes por ejecutar. |
| TASK-004 | La bandeja interna será la fuente oficial de trabajo pendiente. |
| TASK-005 | Una tarea debe registrar responsable, estado, fecha de creación, vencimiento y cierre. |

---

## 21. Notificaciones

### 21.1 Decisión de canales

```text
App interna = control oficial.
Correo corporativo = notificación formal.
Microsoft Teams = alerta operativa y recordatorio.
```

### 21.2 Canales del MVP

- Bandeja interna de la app.
- Correo corporativo.
- Microsoft Teams como alerta simple.

### 21.3 Uso de Teams

Teams se utilizará para alertas operativas y recordatorios, no para aprobación directa en el MVP.

Ejemplo:

```text
Tiene 3 solicitudes pendientes por aprobar en Rutas de Pago Oftalmi.
Ingrese al sistema para revisar.
```

### 21.4 Uso del correo corporativo

El correo corporativo será el canal formal de notificación.

Ejemplo:

```text
Tiene una solicitud de pago pendiente por aprobar.

Solicitud: RP-2026-000145
Unidad: Mercadeo
Tipo: Factura
Monto: 1.250,00 USD
Nodo actual: Finanzas

Ingrese al sistema para revisar y tomar acción.
```

### 21.5 Reglas de notificaciones

| Código | Regla |
|---|---|
| NOTIF-001 | El sistema debe notificar cuando una solicitud llegue a un nodo. |
| NOTIF-002 | Los canales del MVP serán app interna, correo corporativo y Microsoft Teams. |
| NOTIF-003 | El correo corporativo será el canal formal de notificación. |
| NOTIF-004 | Microsoft Teams será canal operativo de alerta y recordatorio. |
| NOTIF-005 | Teams no será canal oficial de aprobación en el MVP. |
| NOTIF-006 | Las aprobaciones, rechazos, devoluciones y pagos deben ejecutarse dentro de la app. |
| NOTIF-007 | Toda notificación enviada debe quedar auditada. |
| NOTIF-008 | El fallo del correo o Teams no debe detener la ruta. |
| NOTIF-009 | Si falla una notificación externa, la tarea debe permanecer activa en la bandeja interna. |
| NOTIF-010 | El sistema podrá enviar resúmenes diarios por Teams con pendientes por nodo. |

---

## 22. Aprobaciones

### 22.1 Principio

Cuando un nodo aprueba, la solicitud avanza al siguiente nodo aplicable.

### 22.2 Reglas

| Código | Regla |
|---|---|
| APPROVAL-001 | Cuando un nodo aprueba, la solicitud avanza al siguiente nodo aplicable. |
| APPROVAL-002 | Una aprobación debe registrar usuario, fecha, nodo, comentario y estado. |
| APPROVAL-003 | Una solicitud solo puede considerarse aprobada cuando todos los nodos requeridos hayan aprobado. |
| APPROVAL-004 | No se puede pagar una solicitud si la ruta aprobatoria no está completa. |

---

## 23. Devoluciones

### 23.1 Definición

Una devolución significa que la solicitud tiene errores corregibles.

Ejemplos:

- Falta soporte.
- Documento incorrecto.
- Monto mal cargado.
- Proveedor incorrecto.
- Observación administrativa.

### 23.2 Reglas

| Código | Regla |
|---|---|
| RETURN-001 | Una devolución significa que la solicitud tiene errores corregibles. |
| RETURN-002 | Una solicitud devuelta puede corregirse y continuar. |
| RETURN-003 | La devolución debe exigir comentario obligatorio. |
| RETURN-004 | La devolución debe notificar al solicitante o nodo responsable de corregir. |
| RETURN-005 | La devolución debe quedar auditada. |

---

## 24. Rechazos

### 24.1 Definición

Un rechazo significa que el pago no procede. La ruta se detiene.

Ejemplos:

- Pago no autorizado.
- Gasto no aprobado.
- Proveedor no procede.
- Monto no justificado.
- Decisión gerencial negativa.

### 24.2 Comportamiento esperado

Cuando un nodo rechaza:

- Se exige motivo obligatorio.
- La solicitud cambia a rechazada.
- La ruta se detiene.
- Las tareas pendientes se cierran o cancelan.
- Los nodos futuros quedan cancelados por rechazo.
- Se notifica al solicitante.
- Se notifica a los nodos involucrados.
- La solicitud no puede pagarse.
- Todo queda auditado.

### 24.3 Reglas

| Código | Regla |
|---|---|
| REJECT-001 | Cualquier nodo autorizado puede rechazar una solicitud si no procede. |
| REJECT-002 | Todo rechazo debe exigir motivo obligatorio. |
| REJECT-003 | Cuando una solicitud es rechazada, la ruta se detiene. |
| REJECT-004 | Una solicitud rechazada no puede pagarse. |
| REJECT-005 | Las tareas pendientes y futuras deben cerrarse o cancelarse por rechazo. |
| REJECT-006 | El rechazo debe notificar al solicitante y a todos los nodos involucrados. |
| REJECT-007 | El rechazo debe quedar auditado con usuario, nodo, fecha, motivo y estado previo. |

---

## 25. Cuentas por Pagar y ejecución de pago

### 25.1 Cuentas por Pagar

Cuando la ruta queda completamente aprobada, la solicitud pasa a Cuentas por Pagar o al departamento responsable de ejecutar el pago.

### 25.2 Bandeja requerida

**Pagos aprobados pendientes por ejecutar**

Campos mínimos:

- Código de solicitud.
- Proveedor o beneficiario.
- Empresa.
- Unidad solicitante.
- Monto.
- Moneda.
- Fecha de aprobación final.
- Fecha estimada de pago.
- Prioridad.
- Estado documental.
- Días pendientes.

### 25.3 Ejecución de pago

Debe permitir registrar:

- Banco origen.
- Cuenta origen.
- Fecha de pago.
- Monto pagado.
- Referencia bancaria.
- Comprobante.
- Observación.
- Usuario que registró.
- Estado del pago.

### 25.4 Reglas

| Código | Regla |
|---|---|
| PAYEXEC-001 | Solo solicitudes completamente aprobadas pueden pasar a Cuentas por Pagar. |
| PAYEXEC-002 | Cuentas por Pagar debe visualizar pagos aprobados pendientes por ejecutar. |
| PAYEXEC-003 | El pago debe registrar banco, cuenta, fecha, referencia, monto, comprobante y usuario responsable. |
| PAYEXEC-004 | Un pago puede quedar pendiente, programado, en proceso, ejecutado, confirmado, fallido o anulado. |
| PAYEXEC-005 | Todo pago ejecutado debe tener trazabilidad completa. |

---

## 26. Consultas y búsquedas

### 26.1 Principio

Todos los usuarios podrán consultar sus solicitudes cargadas usando filtros de búsqueda. El alcance dependerá del rol y permisos.

### 26.2 Filtros recomendados

- Código de solicitud.
- Proveedor / beneficiario.
- Empresa.
- Unidad solicitante.
- Departamento / área / gerencia.
- Tipo de pago.
- Monto desde / hasta.
- Moneda.
- Estado de solicitud.
- Estado de pago.
- Fecha de creación.
- Fecha requerida de pago.
- Fecha de aprobación.
- Fecha de pago.
- Nodo actual.
- Usuario solicitante.
- Usuario aprobador.
- Tipo de documento.
- Número de factura.
- Referencia bancaria.
- Pago programado: sí / no.
- Pago recurrente: sí / no.

### 26.3 Reglas

| Código | Regla |
|---|---|
| SEARCH-001 | Todo usuario podrá consultar sus solicitudes de pago cargadas mediante filtros de búsqueda. |
| SEARCH-002 | Los filtros disponibles deberán respetar el rol y alcance organizativo del usuario. |
| SEARCH-003 | Los usuarios con rol financiero, auditor o gerencial podrán consultar solicitudes de mayor alcance según permisos asignados. |
| SEARCH-004 | Las consultas no deben permitir modificar información, salvo que el estado y rol lo autoricen. |

---

## 27. Pagos programados y recurrentes

### 27.1 Definición

El sistema permitirá registrar pagos programados o recurrentes como viáticos, servicios públicos, alquileres, mantenimientos, suscripciones, licencias o compromisos periódicos.

### 27.2 Pago programado único

Ejemplo:

- Viático planificado.
- Anticipo.
- Servicio puntual con fecha futura.
- Pago acordado para una fecha determinada.

Campos mínimos:

- Fecha programada.
- Motivo.
- Monto estimado.
- Moneda.
- Beneficiario.
- Unidad solicitante.
- Tipo de pago.
- Soporte, si aplica.
- Observación.

### 27.3 Pago recurrente

Ejemplos:

- Servicio eléctrico.
- Agua.
- Internet.
- Telefonía.
- Alquiler.
- Condominio.
- Licencias.
- Mantenimiento.
- Suscripciones corporativas.

Frecuencias posibles:

- Semanal.
- Quincenal.
- Mensual.
- Bimestral.
- Trimestral.
- Semestral.
- Anual.
- Personalizada.

### 27.4 Regla clave

Un pago programado o recurrente no equivale a una solicitud aprobada.

Debe generar una solicitud que seguirá la ruta normal de aprobación.

### 27.5 Reglas

| Código | Regla |
|---|---|
| SCHED-001 | El sistema permitirá registrar pagos programados de ejecución futura. |
| SCHED-002 | El sistema permitirá registrar pagos recurrentes con frecuencia definida. |
| SCHED-003 | Un pago programado o recurrente no equivale a una solicitud aprobada. |
| SCHED-004 | Todo pago programado deberá generar una solicitud de pago antes de pasar a aprobación. |
| SCHED-005 | Los pagos programados deberán generar alertas antes de su fecha prevista. |
| SCHED-006 | Los pagos recurrentes podrán requerir documentos obligatorios antes de generar la solicitud. |
| SCHED-007 | Un pago recurrente podrá estar activo, pausado, finalizado o cancelado. |
| SCHED-008 | La creación, modificación, pausa o cancelación de pagos programados debe quedar auditada. |
| SCHED-009 | Los pagos programados deberán respetar las mismas reglas de ruta, aprobación y auditoría que cualquier otra solicitud. |
| SCHED-010 | El sistema deberá permitir consultar pagos programados por proveedor, unidad, fecha, frecuencia, estado y responsable. |

---

## 28. Auditoría

### 28.1 Principio

Toda acción crítica del sistema debe quedar auditada.

### 28.2 Eventos auditables

- Creación de solicitud.
- Carga de documentos.
- Visualización de documentos.
- Descarga de documentos, si aplica.
- Cambios de monto.
- Cambios de proveedor.
- Cambios de empresa.
- Cambios de unidad.
- Asignación de ruta.
- Entrada a cada nodo.
- Notificación enviada.
- Aprobación.
- Rechazo.
- Devolución.
- Corrección.
- Cambio de estado.
- Programación de pago.
- Ejecución de pago.
- Confirmación de pago.
- Cierre.
- Cambios de rutas maestras.
- Cambios de reglas.
- Cambios de responsables.

### 28.3 Datos mínimos de auditoría

- Usuario.
- Fecha.
- Hora.
- Acción.
- Estado anterior.
- Estado nuevo.
- Nodo.
- Comentario.
- Dirección IP, si aplica.
- Objeto afectado.

### 28.4 Reglas

| Código | Regla |
|---|---|
| AUDIT-001 | Toda acción crítica debe quedar auditada. |
| AUDIT-002 | La auditoría no debe poder ser eliminada por usuarios comunes. |
| AUDIT-003 | Los cambios de estado deben registrar estado anterior y estado nuevo. |
| AUDIT-004 | Los cambios de rutas, reglas, nodos o responsables deben exigir motivo obligatorio. |
| AUDIT-005 | El sistema debe permitir consultar la ruta completa recorrida por una solicitud. |

---

## 29. Versionamiento histórico de rutas

### 32.1 Principio

Las rutas pueden cambiar, pero las solicitudes históricas deben conservar la ruta exacta con la que fueron procesadas.

### 32.2 Regla de oro

```text
Las rutas se versionan.
Las solicitudes usan snapshots.
La auditoría nunca se borra.
```

### 32.3 Conceptos técnicos

- `PaymentRouteTemplate`
- `PaymentRouteTemplateVersion`
- `PaymentRouteTemplateNode`
- `PaymentRequestRouteSnapshot`
- `PaymentRequestRouteNodeSnapshot`

### 32.4 Comportamiento esperado

Una ruta maestra puede cambiar para solicitudes futuras.  
Una solicitud ya iniciada conserva la ruta exacta con la que nació.  
Una solicitud histórica no debe reinterpretarse con una ruta nueva.

### 32.5 Reglas

| Código | Regla |
|---|---|
| VERSION-001 | Las rutas maestras deben versionarse. |
| VERSION-002 | Una ruta usada por solicitudes no debe modificarse directamente. |
| VERSION-003 | Todo cambio de ruta debe crear una nueva versión. |
| VERSION-004 | Cada solicitud debe guardar un snapshot histórico de la ruta aplicada. |
| VERSION-005 | Las solicitudes en curso conservan la ruta con la que iniciaron. |
| VERSION-006 | Las rutas anteriores deben quedar disponibles para consulta histórica. |
| VERSION-007 | Solo rutas activas pueden aplicarse a nuevas solicitudes. |
| VERSION-008 | La corrección excepcional de una ruta asignada debe requerir usuario autorizado, motivo obligatorio, auditoría y notificación a involucrados. |

---

## 30. Estados del sistema

### 30.1 Estados de solicitud

| Estado técnico | Estado visible |
|---|---|
| `draft` | Borrador |
| `submitted` | Enviada |
| `in_approval_route` | En ruta de aprobación |
| `approved` | Aprobada |
| `sent_to_accounts_payable` | Enviada a cuentas por pagar |
| `pending_payment` | Pendiente por pago |
| `payment_in_process` | Pago en proceso |
| `paid` | Pagada |
| `closed` | Cerrada |
| `returned` | Devuelta |
| `rejected` | Rechazada |
| `cancelled` | Anulada |

### 30.2 Estados de nodo

| Estado técnico | Estado visible |
|---|---|
| `pending` | Pendiente |
| `notified` | Notificado |
| `in_review` | En revisión |
| `approved` | Aprobado |
| `returned` | Devuelto |
| `rejected` | Rechazado |
| `skipped` | Omitido |
| `expired` | Vencido |
| `cancelled_by_rejection` | Cancelado por rechazo |

### 30.3 Estados de tarea

| Estado técnico | Estado visible |
|---|---|
| `pending` | Pendiente |
| `notified` | Notificada |
| `in_progress` | En progreso |
| `completed` | Completada |
| `rejected` | Rechazada |
| `returned` | Devuelta |
| `cancelled` | Cancelada |
| `cancelled_by_rejection` | Cancelada por rechazo |
| `expired` | Vencida |
| `reassigned` | Reasignada |

### 30.4 Estados de pago

| Estado técnico | Estado visible |
|---|---|
| `pending_execution` | Pendiente por ejecutar |
| `scheduled` | Programado |
| `in_process` | En proceso |
| `executed` | Ejecutado |
| `confirmed` | Confirmado |
| `failed` | Fallido |
| `cancelled` | Anulado |

### 30.5 Estados de pago programado

| Estado técnico | Estado visible |
|---|---|
| `draft` | Borrador |
| `active` | Activo |
| `paused` | Pausado |
| `generated` | Generado |
| `expired` | Vencido |
| `cancelled` | Cancelado |
| `finished` | Finalizado |

---

## 31. Integración Microsoft 365

### 31.1 Decisión

Microsoft 365 se usará como plataforma corporativa de comunicación y, en fases posteriores, como posible proveedor de identidad.

### 31.2 Uso en el MVP

- Correo corporativo como canal formal de notificación.
- Microsoft Teams como canal operativo de alerta y recordatorio.

### 31.3 Uso futuro

- Autenticación con Microsoft Entra ID.
- Integración más formal con Microsoft Graph.
- Bot de Teams.
- Resúmenes diarios por Teams.
- Alertas gerenciales por SLA.

### 31.4 Reglas

| Código | Regla |
|---|---|
| M365-001 | El sistema deberá utilizar el correo institucional como identificador principal del usuario. |
| M365-002 | El sistema deberá estar preparado para autenticación corporativa mediante Microsoft Entra ID. |
| M365-003 | Las notificaciones por correo deberán enviarse desde una cuenta corporativa autorizada de Microsoft 365. |
| M365-004 | Microsoft Teams podrá utilizarse como canal auxiliar de alerta, recordatorio y seguimiento operativo. |
| M365-005 | Las aprobaciones, rechazos, devoluciones y ejecuciones de pago deberán realizarse dentro de la aplicación. |
| M365-006 | Microsoft 365 no reemplaza la auditoría interna del sistema. |
| M365-007 | El fallo de correo o Teams no debe detener la ruta de pago. |

---

## 32. Fases del MVP

## 32.1 Fase 0 - Definición y base del proyecto

### Objetivo

Alinear reglas, estructura y base técnica.

### Incluye

- Definición del alcance funcional.
- Definición de roles.
- Definición de reglas de negocio.
- Definición de estados.
- Definición de rutas y nodos.
- Definición de branding.
- Definición del stack.
- Definición de arquitectura multiempresa futura.
- Definición de lineamientos de ciberseguridad.
- Definición de estructura DevOps inicial.
- Definición de estrategia de pruebas.
- Estructura base del repositorio.
- Docker base.
- Proyecto Django base.
- Base de autenticación por correo.
- Archivo `.env.example` sin secretos reales.
- Estructura inicial de logs y configuración por ambiente.

### Entregables

- Documento de alcance MVP.
- Documento de reglas de negocio.
- Documento de arquitectura.
- Documento de seguridad.
- Documento DevOps.
- Estructura inicial del proyecto.
- Ambiente de desarrollo operativo.

---

## 32.2 Fase 1 - Núcleo operativo del MVP

### Objetivo

Permitir crear solicitudes y moverlas por una ruta básica funcional.

### Incluye

#### Seguridad y usuarios

- Login por correo.
- Gestión de usuarios.
- Roles básicos.
- Asociación a unidad, área o gerencia.
- Permisos iniciales.

#### Estructura organizativa

- Empresa.
- Unidades.
- Departamentos.
- Áreas.
- Gerencias.

#### Solicitudes de pago

- Crear solicitud.
- Editar borrador.
- Enviar solicitud.
- Tipos de pago.
- Monto.
- Moneda.
- Proveedor o beneficiario.
- Observaciones.

#### Documentos soporte

- Carga de soportes digitales.
- Visualización de soportes.
- Documentos obligatorios.
- Excepción de adelantos.

#### Ruta de aprobación básica

```text
Solicitante / unidad
  -> Finanzas
  -> Gerencia General o Junta Directiva según monto
  -> Cuentas por Pagar
  -> Ejecución de pago
```

#### Acciones de nodo

- Aprobar.
- Devolver.
- Rechazar.
- Comentario obligatorio cuando aplique.

#### Bandejas de trabajo

- Mis solicitudes.
- Pendientes por aprobar.
- Pendientes por corregir.
- Pendientes por pagar.
- Pagos ejecutados.
- Rechazadas.
- Devueltas.

#### Auditoría básica

- Creación de solicitud.
- Cambio de estado.
- Aprobaciones.
- Rechazos.
- Devoluciones.
- Carga de documentos.
- Ejecución de pago.
- Validaciones de seguridad en backend.
- Pruebas mínimas para flujo crítico.

### Resultado esperado

Al finalizar Fase 1, la app ya debe permitir:

- Cargar pagos.
- Adjuntar documentos.
- Ver documentos por aprobadores.
- Enviar a ruta.
- Aprobar.
- Devolver.
- Rechazar.
- Enviar a Cuentas por Pagar.
- Registrar pago.
- Consultar trazabilidad básica.
- Operar con controles mínimos de seguridad.
- Desplegarse de forma reproducible con Docker.

---

## 32.3 Fase 2 - Operación controlada y notificaciones

### Objetivo

Hacer el sistema más operativo y menos manual.

### Incluye

- Bandeja interna consolidada.
- Correo corporativo.
- Alertas por Microsoft Teams.
- Recordatorios de pendientes.
- Alertas de pago no ejecutado.
- Avisos de rechazo.
- Avisos de devolución.
- WorkflowTask completo.
- Estados de tarea.
- Vencimientos.
- Fechas de asignación y cierre.
- Búsqueda y consulta avanzada.
- Registro de pagos programados únicos.
- Registro básico de pagos recurrentes.
- Generación manual asistida de solicitudes.
- Historial de notificaciones.
- Historial por nodo.
- Consulta del flujo completo.
- Mejoras de monitoreo y logs operativos.
- Backups documentados y prueba básica de restauración.

### Resultado esperado

La app pasa de ser funcional a ser cómoda para operación diaria.

---

## 32.4 Fase 3 - Robustez funcional y control avanzado

### Objetivo

Agregar capacidad de administración más madura.

### Incluye

- Plantillas de ruta.
- Versiones de ruta.
- Snapshots por solicitud.
- Reglas avanzadas por monto, tipo de pago, empresa, unidad, moneda y prioridad.
- Versionado de documentos.
- Metadatos documentales.
- Trazabilidad de visualización.
- Reemplazo documental controlado.
- Pagos recurrentes avanzados.
- Frecuencias.
- Calendario.
- Generación automática controlada.
- Endurecimiento de seguridad.
- Pipeline CI/CD formal.
- Reportes operativos y gerenciales.

### Reportes sugeridos

- Solicitudes por estado.
- Pagos por proveedor.
- Pagos por unidad.
- Pendientes por nodo.
- Pagos ejecutados.
- Rechazos.
- Tiempos de aprobación.
- Tiempos hasta pago.

---

## 32.5 Fase 4 - Escalamiento y expansión

### Objetivo

Dejar el sistema listo para operación corporativa ampliada.

### Incluye

- Multiempresa real.
- Branding configurable por empresa.
- Integración con Microsoft Entra ID.
- Integración formal con Microsoft 365.
- Bot de Teams más avanzado.
- Digest diario por gerencia.
- Alertas por SLA.
- Integración futura con ERP.
- Integraciones bancarias futuras.
- Rendición de viáticos.
- KPIs y dashboards gerenciales.

---

## 33. Alcance MVP estricto recomendado

El MVP estricto debería incluir Fase 0 + Fase 1.

### Incluye

- Login por correo.
- Roles básicos.
- Usuarios por unidad.
- Solicitud de pago.
- Carga de documentos.
- Visualización de documentos.
- Adelantos.
- Ruta básica.
- Aprobación.
- Devolución.
- Rechazo.
- Bandejas básicas.
- Cuentas por pagar.
- Registro de pago.
- Auditoría básica.
- Validaciones mínimas de seguridad en backend.
- Docker Compose base.
- Configuración por ambiente mediante `.env`.
- Pruebas mínimas de flujos críticos.
- Branding Oftalmi.

### Se deja para fases posteriores

- Notificaciones avanzadas por Teams.
- Pagos programados robustos.
- Búsquedas avanzadas.
- Versionamiento completo de rutas.
- Pagos recurrentes automáticos.
- Reportes avanzados.
- Multiempresa real.

---

## 34. Riesgos y decisiones de control

### 34.1 Riesgos identificados

| Riesgo | Mitigación |
|---|---|
| Aprobar pagos sin soporte visible | Documento digital obligatorio y visor interno. |
| Que una ruta histórica cambie al modificar la ruta maestra | Versionamiento y snapshots por solicitud. |
| Dependencia excesiva del correo | Bandeja interna como fuente oficial. |
| Uso informal de Teams para decisiones críticas | Teams solo como alerta; decisión dentro de la app. |
| Rechazos sin trazabilidad | Motivo obligatorio y auditoría. |
| Solicitudes pagadas sin aprobación completa | Validación obligatoria antes de ejecución. |
| Futura expansión multiempresa costosa | Campo empresa desde el inicio. |
| Documentos enviados por canales externos | Notificaciones con enlace seguro, no adjuntos. |
| Acceso indebido a información financiera | RBAC, control por unidad, validaciones backend y auditoría. |
| Archivos maliciosos cargados como soporte | Validación de tipo, tamaño, extensión, almacenamiento controlado y análisis posterior si aplica. |
| Pérdida de información por falla operativa | Backups, restore documentado, logs y healthchecks. |
| Despliegues manuales no reproducibles | Docker, variables de entorno, scripts y pipeline CI/CD. |

---

## 35. Decisiones arquitectónicas consolidadas

| Área | Decisión |
|---|---|
| Sistema | Rutas de pago, no solo emisión de pagos. |
| Empresa inicial | Laboratorios Oftalmi. |
| Futuro | Preparado para multiempresa. |
| Backend | Django. |
| Base de datos | PostgreSQL. |
| Frontend MVP | Django Templates + HTMX. |
| Frontend futuro | React. |
| Login | Correo electrónico. |
| Idioma | Español por defecto, inglés secundario. |
| Notificación formal | Correo corporativo. |
| Alerta operativa | Microsoft Teams. |
| Control oficial | Bandeja interna de la app. |
| Documentos | Digitales, visibles desde la solicitud. |
| Rutas | Configurables, versionadas y con snapshot histórico. |
| Auditoría | Propia, obligatoria y transversal. |
| Ciberseguridad | Mínimo privilegio, validación backend, protección documental y auditoría. |
| Ingeniería de software | Modularidad, pruebas, revisión de código y documentación versionada. |
| DevOps | Docker, ambientes, backups, logs, healthchecks y despliegue reproducible. |
| Pagos programados | Permitidos, pero no equivalen a aprobación. |
| Rechazos | Detienen la ruta y notifican a involucrados. |

---

## 36. Definición final consolidada

El **Sistema de Rutas de Pago Oftalmi** gestionará solicitudes de pago, facturas, adelantos, viáticos, pagos programados y otros compromisos mediante rutas aprobatorias dinámicas, configurables y versionadas.

Cada solicitud será creada por un usuario autenticado con correo electrónico y autorizado según su unidad organizativa. La solicitud podrá incluir documentos soporte digitalizados que deberán ser visibles para los aprobadores. Los adelantos podrán iniciar sin documento fiscal, pero deberán incluir justificación obligatoria.

El sistema evaluará reglas de negocio como monto, empresa, unidad, moneda y tipo de pago para asignar una ruta de aprobación. Cada nodo generará tareas pendientes, bandejas de trabajo y notificaciones por app interna, correo corporativo y Microsoft Teams. Los nodos podrán aprobar, devolver o rechazar. Si se aprueba, la solicitud avanza. Si se devuelve, regresa para corrección. Si se rechaza, la ruta se detiene y se notifica a los involucrados.

Una vez aprobada completamente, la solicitud pasará a Cuentas por Pagar para su ejecución. El pago solo podrá registrarse si la ruta fue aprobada en su totalidad. Toda acción, cambio de estado, notificación, aprobación, devolución, rechazo, visualización documental, cambio de ruta y ejecución de pago quedará auditada.

Las rutas maestras podrán cambiar en el tiempo, pero cada solicitud conservará un snapshot histórico e inmutable de la ruta aplicada al momento de iniciar su flujo.

El proyecto deberá ejecutarse con enfoque de ingeniería de software, ingeniería DevOps y ciberseguridad desde el diseño. Esto implica documentación versionada, arquitectura modular, pruebas para flujos críticos, despliegue reproducible, backups, logs, control de secretos, validaciones de permisos en backend, protección de documentos soporte y auditoría transversal.

---

## 37. Próximos pasos recomendados

1. Validar formalmente el alcance Fase 1.
2. Definir los roles reales de Oftalmi y usuarios piloto.
3. Definir unidades, departamentos, áreas y gerencias iniciales.
4. Definir montos límite para Gerencia General y Junta Directiva.
5. Definir tipos de pago y documentos obligatorios por tipo.
6. Definir cuenta de correo corporativo para notificaciones.
7. Definir si Teams se integrará desde Fase 2 o queda para una fase posterior.
8. Solicitar logo oficial y lineamientos visuales al área de diseño gráfico.
9. Crear backlog funcional del MVP.
10. Diseñar modelo de datos inicial.
11. Crear repositorio y estructura base Django/Docker.
12. Definir matriz inicial de riesgos de ciberseguridad.
13. Configurar en GitHub la protección de `main`, Pull Requests obligatorios y flujo de revisión de código.
14. Definir scripts mínimos de backup/restore y healthchecks.
15. Definir pruebas mínimas para ruta, aprobación, rechazo, devolución, documentos y ejecución de pago.

