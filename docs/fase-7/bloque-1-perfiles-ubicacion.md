# Fase 7.1 — Base de perfiles y ubicación

Preparé la migración 012_profiles_locations y su comprobación para PostgreSQL. Este incremento implementa la estructura de datos; todavía no añade formularios, rutas HTTP ni permisos de edición de perfiles. Conservé la autenticación y los datos de cuentas y exámenes existentes. (José Aránguiz)

## Tablas nuevas

| Tabla | Finalidad | Relación principal |
|---|---|---|
| vitalia_regions | Catálogo de regiones | PK code |
| vitalia_provinces | Provincias de una región | region_code → regions.code |
| vitalia_communes | Comunas de una provincia | province_code → provinces.code |
| vitalia_people | Datos personales sin repetir credenciales | account_id único → accounts.id; comuna preferida opcional |
| vitalia_person_identifiers | Identificadores por persona, país y tipo | person_id → people.id; dos restricciones UNIQUE |
| vitalia_patient_profiles | Perfil paciente de una persona | person_id como PK y FK |
| vitalia_professional_profiles | Perfil profesional separado de sus permisos | person_id como PK y FK |
| vitalia_patient_measurements | Peso y altura con fecha y procedencia | patient_person_id → patient_profiles; recorded_by → accounts |

Son ocho tablas y nueve claves foráneas nuevas. Sobre el esquema anterior de 17 tablas, la migración completa deja 25. El diagrama ampliado anterior sigue siendo una propuesta para el resto de entidades, no prueba de que todas estén implementadas. (José Aránguiz)

## Reglas de este incremento

- Una cuenta puede seguir sin persona/perfil; una persona puede tener perfil paciente y profesional sin cambiar role_code ni obtener permisos nuevos.
- Primer nombre y primer apellido obligatorios al crear persona. Segundo nombre, segundo apellido, teléfono, nacimiento y comuna son opcionales en esta estructura. La fecha de nacimiento será exigida por el futuro flujo de perfil completo del paciente.
- No guardo edad fija. Rechazo fechas de nacimiento futuras o infinitas. Las medidas requieren fecha no futura, al menos un dato positivo y finito, fuente y autor.
- El RUT no sustituye el UUID. La combinación país/tipo/valor es única, y una persona tiene un identificador por país/tipo. Este bloque aún no valida módulo 11 ni normaliza formatos de entrada: se implementará antes de habilitar la captura por API. No hay pantalla o ruta que acepte identificadores en esta entrega.
- Los identificadores nacen como not_verified y los profesionales como pending. La creación de una fila no verifica identidad o habilitación profesional. Los futuros servicios controlarán quién puede cambiar esos estados.
- Los catálogos territoriales quedan vacíos. No invento regiones/comunas ni cargo nombres sin una fuente oficial revisada.
- Las fechas updated_at deberán actualizarse desde el futuro servicio; no hay trigger automático. Las FK conservan el borrado restringido por defecto.
- Estas FK no implementan aislamiento multiclínica, autorización de edición ni acceso profesional. Tampoco envío perfiles o medidas al asistente.

Conservo para los bloques siguientes las clínicas y sucursales, invitaciones institucionales de jefes clínicos, gestión de médicos, atención por examen y extracción/chat preliminar. El registro público actual continúa funcionando. (José Aránguiz)

## Probar en Windows sin aplicar cambios todavía

Abre PowerShell de VS Code en la raíz del repositorio de prueba. Conserva cambios locales antes de cambiar de rama:

```powershell
git fetch origin
git switch fase-7/01-perfiles-ubicacion
cd backend
npm ci
npm test
$LASTEXITCODE
```

La compilación y Jest no aplican migraciones a tu servidor. La rama incluye la carpeta database en la etapa de pruebas Docker, conservando la corrección ya validada por el equipo. No pide instalar PGlite ni nuevas dependencias del proyecto.

## Aplicar después de revisar y respaldar

Estos pasos modifican la base indicada en backend/.env. Antes, comprueba su nombre, realiza un respaldo y confirma que las once migraciones anteriores están aplicadas. Usa una cuenta de migraciones con permisos DDL; no amplíes vitalia_app a superusuario. Si no identificas qué base utiliza el archivo, detente antes de ejecutar el comando de migración.

Desde backend, con PostgreSQL 16 activo:

```powershell
node --env-file=.env dist/database/check.js
$LASTEXITCODE
```

Solo si la comprobación anterior termina con 0 y ya decidiste aplicar el cambio en esa base:

```powershell
node --env-file=.env dist/database/migrate-profiles-locations.js
$LASTEXITCODE
```

Esperado: Migración de perfiles y ubicación aplicada. Repetir conserva las tablas y responde que ya estaba aplicada. Si falla, no borres ni edites migraciones anteriores ni elimines tablas para forzarla.

La comprobación posterior inserta únicamente datos sintéticos en una transacción y siempre intenta revertirlos:

```powershell
node --env-file=.env dist/database/verify-profiles-locations.js
$LASTEXITCODE
```

Esperado: Perfiles y ubicación: 33 comprobaciones correctas. Datos sintéticos revertidos. Código 0. Necesita permisos para crear y revertir esas filas; no usa S3 ni Ollama. No convierte al paciente en profesional por tener ambos perfiles.

## Docker

No arranques esta rama contra los volúmenes habituales sin revisar y respaldar: migrate-all descubre automáticamente el archivo 012 y Compose puede ejecutarlo al iniciar servicios. La prueba de imagen por sí sola no migra una base externa:

```powershell
docker build --target test -t vitalia-backend-test ./backend
$LASTEXITCODE
```

## Validación

Comprobé SQL, idempotencia, huella modificada rechazada, requisito 011 y reversión ante un fallo DDL en PGlite (motor PostgreSQL WASM aislado). Verifiqué las 33 reglas con el mismo comprobador y que la cuenta antigua permaneciera intacta. PGlite se instaló fuera del proyecto solo para esta comprobación; no se incorpora a package.json. No equivale a PostgreSQL 16, Docker o prueba de permisos de vitalia_app. La comprobación en Windows queda pendiente. (José Aránguiz)
