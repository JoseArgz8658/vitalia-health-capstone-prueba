# CAM-082 — Base de perfiles y ubicación, fase 7.1

Implementé 012_profiles_locations con regiones, provincias, comunas, personas, identificadores, perfiles paciente/profesional y medidas fechadas. Añadí el ejecutor específico y un comprobador que usa datos sintéticos dentro de una transacción con ROLLBACK. Conservé los UUID de cuentas, las once migraciones existentes, el registro público y el flujo actual de exámenes. No ejecuté cambios sobre la base del equipo ni el repositorio oficial. (José Aránguiz)

## Decisiones

Separé los perfiles de los permisos globales. Teléfono, segundo nombre y segundo apellido son opcionales. Una cuenta antigua puede no tener perfil y una persona puede tener ambos perfiles sin recibir privilegios por ello. No fabriqué datos desde PDF ni cargué catálogos territoriales sin verificar una fuente oficial. Los identificadores quedan sin verificar y los profesionales pendientes por defecto. La normalización y validación módulo 11 se implementarán antes de exponer el registro de identificadores por API. (José Aránguiz)

Dejé documentados para los siguientes bloques: autorización institucional externa antes de invitar al jefe clínico, gestión de profesionales dentro de su clínica, selección de profesional por examen y consulta de extracción/chat preliminar con advertencias. No implementé esas funciones ni cambié la asignación administrativa provisional en esta entrega. (José Aránguiz)

## Docker y compatibilidad

Conservé en esta rama de desarrollo la corrección del equipo COPY database ./database en la etapa test del Dockerfile. Ya existía en el oficial; su ausencia en la base del repositorio de prueba impediría leer migraciones durante las pruebas de imagen. El Dockerfile resultante coincide con el oficial revisado. No cambié dependencias, Compose, secretos o archivos de instrucciones para agentes. (José Aránguiz)

## Validación

- Compilé TypeScript y ejecuté Jest: 41 suites y 428 pruebas aprobadas, código 0.
- Ejecuté las once migraciones previas y la nueva en PGlite (motor PostgreSQL WASM aislado), con una cuenta ficticia anterior conservada.
- El comprobador completó 33 casos: opcionales nulos, perfiles dobles sin cambio de rol, identificadores duplicados, FK inválidas, fechas futuras/infinitas, medidas vacías, cero, negativas, NaN e infinitas y estados inválidos. Confirmé que no quedaron sus filas sintéticas.
- Comprobé repetición idempotente, rechazo de checksum cambiado, requisito 011 ausente y reversión de todas las tablas nuevas ante un fallo DDL inyectado.

No agregué PGlite como dependencia del proyecto. Las pruebas anteriores no equivalen a una ejecución en PostgreSQL 16 ni Docker. No se verificaron permisos de vitalia_app sobre las tablas nuevas. La guía incluye los comandos Windows para ejecutar la comprobación cuando se haya revisado y aplicado la migración en una base respaldada. No pedí pruebas Flutter porque este incremento no modifica la aplicación. (José Aránguiz)

## Documentación y estado

Actualicé [plan-migraciones](../fase-7/plan-migraciones.md), añadí [guía del bloque](../fase-7/bloque-1-perfiles-ubicacion.md) y [diccionario](../fase-7/diccionario-bloque-1.md). Son ocho tablas nuevas: el total será 25 después de aplicar 012 sobre las 17 anteriores. Este incremento prepara la estructura; todavía faltan rutas y pantallas para completar los perfiles. La carga de territorios, roles clínicos, clínicas, invitaciones y atención por examen continúa pendiente. (José Aránguiz)
