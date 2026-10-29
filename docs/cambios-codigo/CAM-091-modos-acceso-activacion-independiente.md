# CAM-091 — Modos de acceso y activación independiente

## Decisiones y resultado

Implementé acceso inicial en modo Paciente y un botón para cambiar a Profesional. Uso el mismo correo y contraseña cuando ambos permisos pertenecen a una cuenta. La selección no concede un perfil: el servidor comprueba la concesión activa y crea una sesión vinculada al modo autorizado. Para entrar en otro modo se inicia otra sesión; no amplío una sesión ya abierta al aceptar una invitación. (José Aránguiz)

Separé la administración en `/#/administracion`, sin selector público de permisos administrativos. Esa dirección no es una protección por sí sola: exige credenciales de una cuenta con concesión administrativa activa. Conservé los administradores anteriores y no otorgué administración desde las nuevas invitaciones. Si el cuerpo de login omite `mode`, el modo es paciente; los clientes profesionales y administrativos deben enviarlo expresamente. (José Aránguiz)

Retiré el botón de activar invitación del inicio de sesión. La activación se abre directamente en `/#/activar-invitacion`, sin necesidad de reescritura de rutas del servidor estático porque utilizo la ruta fragmento de Flutter Web. Conocer la dirección no concede permisos. El código mantiene vencimiento de 48 horas, uso único, revocación y almacenamiento de su huella. No lo incluyo en parámetros o fragmentos de URL. (José Aránguiz)

Confirmé **dos formas de entrega complementarias**: manual y por correo. La entrega manual muestra dirección y código para compartir por privado. El envío por correo queda pendiente de configurar y probar el servicio correspondiente; la pantalla lo identifica como pendiente y no informa un envío que no ocurrió. Cuando configure ese servicio, conservaré la entrega manual. No envié correos ni añadí un proveedor o credenciales de correo en este incremento. (José Aránguiz)

## Cuenta existente y aceptación

Permití invitar a una cuenta existente de paciente o profesional. La creación de una cuenta nueva por código sigue rechazando un correo registrado: el destinatario debe elegir **Ya tengo una cuenta en Vitalia**, autenticarse en uno de sus modos existentes y aceptar expresamente la incorporación. Compruebo que el correo actual de la cuenta autenticada coincide con la invitación. No permito usar este flujo para convertir una cuenta administrativa. (José Aránguiz)

La aceptación vuelve a comprobar clínica activa, autorización institucional del jefe o jefatura activa del emisor, vencimiento, revocación, código no utilizado y selecciones. Conservo contraseña, identificador de cuenta y datos personales existentes. Si todavía no hay persona, creo los nombres aportados por el titular; si ya existe, no los sustituyo. Creo el perfil profesional pendiente solo si falta. Registro pertenencia, selecciones, concesión profesional cuando procede, consumo del código y auditoría en una transacción. Si algo falla, no conservo una concesión o perfil parciales. (José Aránguiz)

Una cuenta profesional existente puede incorporarse a otra clínica mediante aceptación, sin sustituir su pertenencia anterior. Si ya pertenece a esa misma institución, rechazo la incorporación duplicada; su gestión corresponde al jefe autorizado. Tampoco reactivo una concesión global profesional revocada por aceptar otra invitación. (José Aránguiz)

La pantalla independiente utiliza una sesión temporal propia para la aceptación, la cierra después y vuelve al inicio de sesión. El destinatario entra posteriormente en modo Profesional. Una sesión de paciente anterior sigue siendo de paciente. No añado automáticamente perfil de paciente a todas las cuentas profesionales: el acceso en cada modo requiere su concesión. La habilitación voluntaria de paciente para una cuenta inicialmente solo profesional conserva su estado pendiente. (José Aránguiz)

## Migración 017 y permisos

Añadí `017_account_modes`, que requiere 016. Creo `vitalia_account_roles`, copio únicamente los roles ya existentes y añado `active_role` a las sesiones. Las sesiones anteriores conservan el rol que tenían; una FK vincula cuenta y modo concedido, y cada consulta de sesión exige que esa concesión siga activa. No cambio `accounts.role_code`: queda como dato legado y no como el permiso de una sesión nueva. Desde 39 tablas se esperan 40 tablas y 17 migraciones. (José Aránguiz)

Un trigger registra la concesión inicial de cuentas nuevas según el rol de creación ya autorizado, sin hacer a todas las cuentas pacientes, profesionales y administradores a la vez. Las concesiones profesionales adicionales tienen referencia a la invitación aceptada. Preparé permisos de lectura/inserción para la aplicación; no concedí actualización de concesiones, cambio del modo de sesiones existentes ni modificación de roles o contraseñas de cuentas anteriores. El script de permisos requiere `vitalia_dev` y un `vitalia_app` limitado. (José Aránguiz)

Adapté las consultas de asignaciones, acceso profesional, revisión y operación manual de procesamiento para comprobar concesiones activas en lugar del rol legado. Esto permite que una cuenta con dos modos conserve sus exámenes propios y consulte únicamente pacientes asignados cuando actúa como profesional. No creé asignaciones por aceptar una invitación ni implementé todavía la atención por examen. (José Aránguiz)

## Archivos principales

| Área | Archivos |
|---|---|
| Esquema y permisos | `backend/database/migrations/017_account_modes.sql`, `backend/database/permissions/account-modes-app.sql` |
| Autenticación y sesión | `backend/src/auth/credentials.ts`, `sessions.ts`, `router.ts` y conexión en `server.ts` |
| Compatibilidad de elegibilidad | `assignments/service.ts`, `professional/service.ts`, `reviews/service.ts`, `processing/manual.ts` |
| Aceptación | `backend/src/onboarding/service.ts`, `router.ts` |
| Aplicación y verificación | `migrate-account-modes.ts`, `verify-account-modes.ts`, `account-modes-verification.ts` en `backend/src/database/` |
| Interfaz | `acceso_page.dart`, `activar_invitacion_page.dart`, `incorporacion_page.dart`, `vitalia_mvp_app.dart`, `core/auth_api.dart` |
| Pruebas | `backend/test/account-modes.test.cjs`, adaptación de contratos anteriores; `apps/vitalia/test/modos_acceso_test.dart` y ajustes de expectativas de login/rutas |

## Comprobaciones

Ejecuté la compilación y la suite completa: **617 pruebas backend aprobadas en 49 suites**, salida 0, en 30,008 segundos. Añadí 18 casos sobre modo autorizado, modo por defecto, denegación de permisos, sesión, aceptación autenticada y rechazo de otra cuenta o campos arbitrarios. Actualicé los contratos de pruebas afectados por el modo explícito y la nueva consulta de elegibilidad; la primera ejecución identificó cuatro fallos en un fixture de asignaciones que todavía reconocía solo la consulta anterior. Conservé las comprobaciones de propiedad y auditoría al actualizarlo. (José Aránguiz)

El verificador aislado aprobó **27 comprobaciones de modos/aceptación**, y conservé las 41 de invitaciones y 37 de equipo. Comprobé además migración, repetición, checksum, conservación de sesiones anteriores, uso con rol limitado, concesión inicial de nuevas cuentas y reversión de rol/persona/perfil si falla auditoría. El motor aislado adapta el transporte DDL y simula advisory locks; no lo presento como PostgreSQL 16, Docker o concurrencia real. No lo añadí a las dependencias del proyecto. (José Aránguiz)

Preparé siete pruebas Flutter nuevas y adapté las anteriores al nuevo modo y rutas. Revisé sintaxis Dart; Flutter no está instalado aquí. `flutter analyze`, `flutter test`, aplicación de 017/permisos y recorridos reales de ambos modos y aceptación siguen pendientes en Windows/PostgreSQL 16. La guía está en [modos-acceso.md](../fase-7/modos-acceso.md). No modifiqué el repositorio oficial. (José Aránguiz)

## Pendientes conservados

Conservo ambas entregas en el diseño; falta configurar el servicio de correo, una dirección pública accesible y sus pruebas de entrega. La dirección local no funcionará desde otro equipo sin publicación o configuración de red. Tampoco declaro resueltas acreditación profesional, gestión de jefaturas, transición a atención por examen, habilitación voluntaria del perfil paciente para profesionales existentes ni Docker/concurrencia entre instancias. La vista/chat preliminares siguen en su bloque posterior. (José Aránguiz)
