# Estructura organizativa - Fase 1

## Objetivo

Definir la base organizativa necesaria para que el Sistema de Rutas de Pago Oftalmi pueda controlar solicitudes por empresa, unidad, departamento, área y gerencia.

## Modelos

```text
Company
Management
Area
Department
OrganizationalUnit
```

## Relación con usuarios

El usuario queda relacionado con:

```text
primary_company
primary_organizational_unit
department
area
management
```

## Reglas

```text
ORG-001 Toda solicitud futura deberá estar asociada a una empresa.
ORG-002 Todo usuario solicitante deberá tener alcance organizativo definido.
ORG-003 La unidad organizativa será usada para filtrar solicitudes visibles por rol y responsabilidad.
ORG-004 Las relaciones organizativas deberán protegerse contra eliminación física si existen usuarios o solicitudes asociadas.
```

## Puntos completados

```text
F1-P06 App organization — COMPLETADO
F1-P07 Relación usuario / empresa / unidad — COMPLETADO
```
