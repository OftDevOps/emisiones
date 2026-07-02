# Reglas de Negocio - Sistema de Rutas de Pago Oftalmi

## Reglas principales

1. El usuario ingresa con correo electrónico.
2. El usuario solo carga pagos de su unidad autorizada.
3. Todo pago debe tener soporte digital, excepto adelantos justificados.
4. Todo aprobador debe poder ver el soporte digital.
5. Toda solicitud debe tener ruta asignada.
6. La ruta puede depender del monto.
7. Dependiendo del monto puede ir a Gerencia General o Junta Directiva.
8. Cada nodo puede aprobar, devolver o rechazar.
9. Si se aprueba, avanza.
10. Si se devuelve, regresa para corrección.
11. Si se rechaza, se detiene la ruta.
12. El rechazo notifica a los nodos involucrados.
13. No se puede pagar sin aprobación completa.
14. Cuentas por Pagar ve los pagos aprobados pendientes por ejecutar.
15. Toda acción crítica queda auditada.
16. Las rutas se versionan.
17. Las solicitudes usan snapshot histórico de ruta.
18. La bandeja interna es la fuente oficial de tareas.
19. El correo corporativo es notificación formal.
20. Teams es alerta operativa, no canal de aprobación en el MVP.
