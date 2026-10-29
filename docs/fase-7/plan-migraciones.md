# Fase 7 — Perfiles, clínicas y atención por examen
Rama de este incremento: fase-7/01-perfiles-ubicacion. La migración 012 está aplicada y comprobada en PostgreSQL 16 local. El perfil y el guardado/recuperación de medidas se comprobaron en Windows; el catálogo territorial y los bloques posteriores siguen pendientes. Las migraciones 013+ continúan propuestas.

## Decisiones confirmadas
Teléfono opcional, un médico responsable por examen a la vez, segunda opinión posterior sin sobrescribir revisión, derivaciones dentro de la misma clínica. Propuesta ampliada: 18 tablas nuevas, importadas como modelo visual separado. Las restricciones del diagrama Oracle no son migraciones PostgreSQL.

## Condiciones observadas en el código
applyAdditionalMigration abre transacción, usa bloqueo advisory, exige versión previa y verifica checksum. migrate-all descubre SQL numerados automáticamente. Por eso los borradores se conservan fuera de backend/database/migrations hasta estar listos para ejecución.
009_professional_reviews conserva UNIQUE processing_id y trigger que rechaza UPDATE/DELETE de revisiones. No editar 001..011 ni eliminar ese trigger para adaptar opiniones posteriores.

## Orden de implementación propuesto
| Bloque | Migración reservada, aún no creada | Entidades | Dependencia y compatibilidad |
|---|---|---|---|
| 1 | 012_profiles_locations | regions, provinces, communes, people, identifiers, patient_profiles, professional_profiles, patient_measurements | Crear primero territorios vacíos para FK de people. No cargar nombres/RUT a partir de exámenes. Perfil ausente sigue permitiendo login actual. |
| 2 | 013_clinics_memberships | clinics, branches, specialties, professional_specialties, clinic_memberships, branch_memberships | FK compuestas para coherencia de clínica y sucursal. No asignar una clínica ficticia a todos los documentos antiguos. |
| 3 | 014_account_roles | account_roles | Copiar pares account_id/role_code existentes con control de duplicidad. Conservar role_code durante transición. No activar privilegios múltiples antes de actualizar validación de actor y sesiones. |
| 4 | 015_exam_care_reviews | exam_care, exam_referrals, care_reviews | Crear tablas y PK/UNIQUE antes de FK por el ciclo care.prior_review ↔ review.care. Índice parcial de una atención requested/active por documento. Trigger de inmutabilidad para nuevas revisiones. |
| 5 | transición explícita, versión por definir | Puente legado/revisión nueva si es necesario | Definir lectura dual del API, explicación y chat. No aplicar INSERT SELECT que invente sede/profesional responsable. No duplicar una aprobación cambiando su autor. |

Las migraciones concretas dependerán de permisos y consistencia del estado real. Separar DDL listo de borrador; no reservar números mediante SQL incompleto en el directorio autodescubierto.

## Contratos para no romper lo existente
- Login, carga, worker, revisión y chat actuales continúan funcionando mientras no se cambia su contrato.
- accounts.id sigue siendo UUID y credenciales se mantienen solo en accounts.
- El primer bloque no convierte role_code en múltiples roles activos ni cambia /me.
- Perfil incompleto debe mostrarse explícitamente; no bloquear de inmediato cuentas antiguas.
- No tomar nombres/RUT de documentos como identidad verificada de la cuenta.
- La clínica del informe transcrito no es automáticamente el tenant de atención.
- La revisión nueva pertenece a una atención y se guarda en care_reviews. professional_reviews sigue como legado inmutable. El UNIQUE actual se conserva.
- El asistente debe utilizar una revisión seleccionada/autorizada, no mezclar opiniones ni datos de otros documentos.
- Obtener cita de segunda opinión no permite al médico leer todos los exámenes del paciente.
- Derivación transaccional cambia responsabilidad autorizada y registra trazabilidad. Acceso a revisión ya aprobada sigue una política explícita.
- El jefe clínico opera solo en su clínica. Administrador técnico no recibe acceso clínico por gestionar infraestructura.

## Verificación antes de aplicar
Ejecutar preflight-fase-7.sql en Query Tool sobre vitalia_dev. Es solo lectura y devuelve versiones, resumen de registros y coincidencias de nombres nuevos. No envía datos a IA. Revisar el estado antes de escribir la primera migración.
Un respaldo debe incluir PostgreSQL y referencia a originales en S3. No usar DROP TABLE como estrategia para revertir una migración con perfiles nuevos.

## Pruebas por bloque
1. Migración: versión previa, ejecución repetida sin cambios, checksum cambiado rechazado, fallo con rollback, migración sobre esquema previo y esquema nuevo.
2. Perfiles: cuenta sin perfil, persona única por cuenta, teléfono nulo, segundo apellido opcional, identificador duplicado, medición positiva/unidad/fecha, permisos de edición propios.
3. Clínicas: pertenencia activa y revocada, sede de otra clínica, roles de jefe clínico y administrador técnico.
4. Roles: sesión vieja y nueva, usuario con ambos perfiles, elección de rol activo sin confiar en solicitud manipulada.
5. Atención: dos solicitudes concurrentes no crean dos responsables; segunda opinión conserva previa; profesional ajeno no lee documento; derivación entre tenants rechazada.
6. Revisiones: autoría, copia original conservada, inmutabilidad, compatibilidad de chat/explicaciones y selección de revisión.
Después de cambios reales en Flutter: analyze y tests pertinentes. No pedir pruebas Flutter por archivos de planificación.

## Antes de completar registro
Queda por definir política de personas sin RUT, verificación profesional/identidad y creación inicial de jefes clínicos. En el primer bloque se puede crear estructura sin marcar identidades verificadas ni imponer requisitos que aún no se han acordado.

## Pendientes conservados
Fase 6: ordenar modelo propuesto, vistas por área cuando haya tiempo, iconos Android y accesibilidad. IA: cobertura/rendimiento en docs/pendientes. Seguridad PostgreSQL: usuario limitado/coordinación con compañero; debe resolverse antes de despliegue. Estos trabajos no se declaran cerrados por iniciar fase 7.

## Avance 7.1 — 15 de octubre de 2026

Preparé ocho tablas nuevas mediante 012_profiles_locations, sin modificar 001..011 ni los roles actuales. Añadí el ejecutor específico, 33 comprobaciones con datos sintéticos revertidos, pruebas de manejo de fallos y la guía [bloque-1-perfiles-ubicacion.md](bloque-1-perfiles-ubicacion.md). Este incremento es la base de datos: las rutas y pantallas para completar perfil siguen pendientes. Antes de habilitar captura de RUT faltan normalización y módulo 11. (José Aránguiz)

Acordé para los siguientes bloques: el administrador invita al primer jefe clínico solo con autorización institucional previa verificada; el jefe invita profesionales únicamente de su clínica. El paciente elige al profesional por examen y puede consultar extracción/chat preliminar con advertencia y fuente diferenciada. Estos cambios todavía no están implementados. No añado un rol de director dentro de la aplicación. (José Aránguiz)

## Continuación funcional 7.1 — CAM-083

Añadí la API de perfil propio y la pantalla Mi perfil, con RUT opcional normalizado y validado por módulo 11. Separé los permisos de edición por columnas de la migración; su concesión en vitalia_dev requiere ejecución administrativa deliberada. Incorporé la validación de 33 comprobaciones en PostgreSQL 16 y 428 pruebas Windows en CAM-082. La continuación aprobó 456 pruebas backend; Flutter y flujo real del perfil quedan pendientes en Windows. Medidas, catálogo de comunas e invitaciones clínicas siguen pendientes. (José Aránguiz)

## Medidas y estado posterior — CAM-084 / CAM-085

Comprobé el perfil propio en Windows y el ajuste de consulta/edición por secciones con 80 pruebas Flutter y análisis sin incidencias. Añadí el módulo opcional de peso/altura con historial propio y fuente patient_reported. El backend del nuevo módulo aprobó 482 pruebas; Flutter y flujo real de medidas siguen pendientes en Windows. No cambié 012 ni cargué catálogo territorial. Las clínicas e invitaciones siguen en los siguientes bloques. (José Aránguiz)

## Comprobación Windows de medidas — 29 de octubre de 2026

Comprobé 82 pruebas Flutter, análisis sin incidencias y 482 pruebas backend en 43 suites, con salida 0. Apliqué los permisos de perfiles/medidas en vitalia_dev y confirmé guardado y recuperación de las medidas al reabrir Mi perfil. La evidencia está en [CAM-085](../cambios-codigo/CAM-085-medidas-personales.md). No declaro comprobados manualmente los recorridos no informados. (José Aránguiz)

El siguiente trabajo pendiente de ubicación es revisar una fuente oficial del catálogo territorial y habilitar la selección de comuna con validación de la relación región/provincia/comuna. También quedan por definir la auditoría específica y la rectificación de medidas. Las clínicas, pertenencias, invitaciones y atención por examen conservan su estado de propuesta; no se integran al repositorio oficial por esta comprobación. (José Aránguiz)
