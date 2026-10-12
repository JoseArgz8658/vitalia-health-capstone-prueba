# Vitalia Health: instalación y pruebas en Windows

Esta guía está pensada para los computadores Windows del equipo. Todos los comandos se ejecutan en PowerShell. Conservamos Flutter para web y Android, backend, migraciones, pruebas y documentos de avance. Los cambios por fase están en `docs/avance` y `docs/cambios-codigo`.

Trabajamos con documentos ficticios. La extracción queda pendiente de revisión profesional y las respuestas educativas del asistente no constituyen diagnóstico ni tratamiento.

## 1. Elegir cómo ejecutar el proyecto

- **Con Docker:** Docker Desktop prepara PostgreSQL, API, procesador y Ollama. Flutter y Android Studio se instalan en Windows.
- **Sin Docker:** instalamos PostgreSQL, Node.js y Ollama en Windows, y arrancamos API y procesador en terminales separadas.
- **AWS S3:** usamos el bucket de pruebas compartido del equipo en ambos caminos. Cada integrante utiliza su propio acceso autorizado.

No ejecutes los dos caminos simultáneamente en los mismos puertos. Docker crea una base independiente de la que ya tienes instalada en Windows. Descargar GitHub no copia los datos de José.

## 2. Herramientas

| Herramienta | Cuándo es necesaria | Descarga y versión |
| --- | --- | --- |
| Docker Desktop | Obligatorio para el camino Docker; opcional para el camino local | [Descargar](https://docs.docker.com/desktop/setup/install/windows-install/). En Windows, usar contenedores Linux con WSL 2. |
| Flutter SDK | Obligatorio para ejecutar o compilar esta web y Android | [Instalar Flutter](https://docs.flutter.dev/install), [archivo de versiones](https://docs.flutter.dev/install/archive). Versión usada en el equipo de desarrollo: stable 3.44.6. |
| Android Studio | Obligatorio si usaremos un emulador Android; no hace falta para web | [Descargar](https://developer.android.com/studio), [configurar Flutter para Android](https://docs.flutter.dev/platform-integration/android/setup). |
| Node.js | Obligatorio en ejecución local y pruebas sin Docker; no hace falta en el equipo para levantar el backend con Docker | [Descargar Node.js](https://nodejs.org/es/download). Usar Node 24 LTS. Docker usa 24.21.0. |
| PostgreSQL | Obligatorio instalado en el equipo solo para el camino local | [Descargar](https://www.postgresql.org/download/windows/). Usar PostgreSQL 16; Docker lo incluye. |
| Ollama | Obligatorio instalado en el equipo solo para IA en el camino local | [Descargar](https://ollama.com/download). Docker lo incluye. Modelo: qwen3:4b-instruct. |
| Visual Studio Code | Opcional; recomendado para abrir y modificar el código | [Descargar](https://code.visualstudio.com/download). Extensiones Flutter y Dart. VS Code no es Visual Studio. |
| Git o GitHub Desktop | Opcional si descargamos ZIP; necesario para trabajar con ramas y subir cambios | [Git](https://git-scm.com/downloads), [GitHub Desktop](https://desktop.github.com/download/). |
| Acceso autorizado a AWS S3 | Obligatorio para el flujo real de documentos, con Docker o sin él | [Consola S3](https://console.aws.amazon.com/s3/). Bucket privado y credenciales propias/autorizadas. |


Usamos Flutter 3.44.6, Dart 3.12.2 y Node 24 en el equipo de desarrollo. Las versiones de imágenes están fijadas en Dockerfile y Compose. Una primera instalación requiere Internet. Es recomendable contar con 16 GB de RAM y espacio para Docker, el modelo y el emulador. El rendimiento de IA depende del computador y sigue sujeto a evaluación.

## 3. Descargar la rama

En el repositorio [Vitalia Health](https://github.com/JoseArgz8658/vitalia-health-capstone), selecciona la rama `develop`. En GitHub Desktop pulsa Fetch origin y Pull origin. Si prefieres descargar sin Git, selecciona `develop` en GitHub y utiliza Code > Download ZIP.

Para una descarga nueva desde PowerShell:

```powershell
git clone --branch develop --single-branch https://github.com/JoseArgz8658/vitalia-health-capstone.git
cd vitalia-health-capstone
```

La raíz es la carpeta con `README.md`, `compose.yaml`, `backend` y `apps`. Si descargaste ZIP, entra a la carpeta extraída. Si el repositorio es privado, necesitas acceso autorizado. Todos los comandos de instalación parten de esta raíz, salvo cuando se indica otra carpeta.

## 4. Docker Desktop y WSL 2 en Windows

Instala Docker Desktop y utiliza el motor WSL 2 con contenedores Linux. Windows sigue siendo el sistema del equipo. No hace falta trabajar desde una terminal de Ubuntu.

Si WSL no está preparado, abre PowerShell **como administrador**:

```powershell
wsl --install
wsl --update
```

Reinicia si Windows lo solicita. Abre Docker Desktop y espera a que arranque el motor.

### Si Docker no arranca por virtualización o componentes de Windows

En el equipo de José, habilitar estos componentes y reiniciar resolvió el problema. Son pasos de recuperación para ese tipo de fallo, no una solución universal a cualquier error de Docker.

Comprueba en Administrador de tareas > Rendimiento > CPU que la virtualización esté habilitada. Si está deshabilitada, debes habilitarla desde BIOS/UEFI siguiendo las instrucciones del fabricante.

En PowerShell **como administrador**:

```powershell
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
bcdedit /set hypervisorlaunchtype auto
wsl --update
```

Reinicia el computador. Abre otra vez Docker Desktop. Los comandos DISM con `/norestart` no reinician por sí solos. En un equipo institucional, estos cambios pueden requerir autorización del administrador.

### Comprobar antes de continuar

En PowerShell normal:

```powershell
docker --version
docker compose version
docker compose version --short
docker info --format '{{.OSType}}'
wsl --status
```

Esperamos una versión de Compose, `linux` como tipo de contenedores y WSL 2. Si Compose no muestra versión, ejecuta `docker compose --help` y revisa Docker Desktop antes de continuar. No se considera validado solo porque el comando no imprimió un error.

Referencias: [instalación Docker en Windows](https://docs.docker.com/desktop/setup/install/windows-install/), [problemas de virtualización](https://docs.docker.com/desktop/troubleshoot-and-support/troubleshoot/topics/), [componentes WSL](https://learn.microsoft.com/es-es/windows/wsl/install-manual).

## 5. Acceso al bucket S3 del equipo

### Nota del acceso compartido — José Aránguiz

Les invité al acceso de AWS para trabajar con los recursos del proyecto. Juan Jiménez ya está dentro y debería tener acceso; todavía debemos comprobar sus permisos sobre el bucket. Quedan pendientes Diego Palma y Mauricio Reyes. Este estado corresponde al 12 de octubre de 2026.

Les dejo los datos del bucket que estoy utilizando. No necesitan crear otro bucket para seguir este manual. Si les falta la invitación, el enlace de acceso o el rol asignado, avísenme antes de continuar. **(José Aránguiz)**

### Paso 1. Identificar el bucket del proyecto

| Dato | Valor o indicación |
| --- | --- |
| Nombre exacto del bucket | `bucket-vitalia-health-0-949847740123-us-east-2-an` |
| Región | `us-east-2`, Este de EE. UU. (Ohio) |
| Enlace de acceso a AWS | Utiliza el enlace de tu invitación. Si no lo tienes, solicítamelo. (José Aránguiz) |
| Cuenta y rol | Utiliza los asignados a tu identidad. La cuenta o el rol de cada integrante deben confirmarse. |
| Documentos de prueba | Solo documentos ficticios. No borres archivos de otros integrantes. |

En el script introduce únicamente el nombre del bucket. No añadas `arn:aws:s3:::`, `s3://`, una URL ni carpetas. Conserva `us-east-2` exactamente como aparece en la tabla.

### Paso 2. Aceptar la invitación y comprobar el acceso

1. Abre tu invitación de AWS y completa el acceso con tu propia identidad.
2. Entra mediante el enlace proporcionado. No utilices la contraseña ni las claves de otro integrante.
3. Selecciona la cuenta y el rol que te hayan asignado, si el portal presenta esas opciones.
4. Abre Amazon S3 y busca el bucket de la tabla.
5. Si no aparece o recibes acceso denegado, avísame para revisar la cuenta y los permisos. No crees un bucket alternativo. (José Aránguiz)

Estar dentro de AWS o ver el bucket no confirma todavía todos los permisos que necesita el backend. La comprobación del paso 5 verifica el acceso desde la aplicación.

### Paso 3. Preparar credenciales individuales — José Aránguiz

Intenté abrir IAM Identity Center desde mis dos sesiones y recibí «No es posible acceder a este servicio». Por ahora no utilizaremos ese servicio como paso de instalación. Mi backend funciona con una clave permanente del usuario IAM `vitalia-backend-dev`. Esto no demuestra que el resto del equipo ya tenga credenciales programáticas propias. (José Aránguiz)

**No les compartiré la clave de vitalia-backend-dev ni su clave secreta. No creen una segunda clave en ese usuario para repartirla.** Seguiría siendo la misma identidad con los mismos permisos.

Para habilitar cada computador necesitamos preparar un acceso individual autorizado. Esta parte está **pendiente de confirmar**, aunque el integrante ya pueda ver el bucket en la consola.

1. Confirma conmigo qué usuario o rol aparece en el menú de cuenta de tu sesión AWS. No envíes secretos.
2. Verificaremos si la cuenta permite crear usuarios IAM individuales y quién tiene permiso para administrarlos. No uses la cuenta raíz para generar claves.
3. Si está permitido, el administrador preparará un usuario por integrante con permisos limitados al bucket del proyecto. No se asignará AdministratorAccess como requisito de instalación.
4. Con tu propio usuario IAM y autorización para gestionar sus claves, abre **IAM > Usuarios > tu usuario > Credenciales de seguridad > Crear clave de acceso**. Si no tienes esa autorización, solicita ayuda al administrador.
5. Guarda tu Access Key ID y Secret Access Key de forma privada. Introduce esos dos valores en el script de configuración. Para este acceso permanente, deja AWS Session Token vacío y pulsa Enter.
6. Ejecuta la comprobación S3 del paso 5. Poder listar el bucket en la consola no acredita los permisos de la aplicación.

Si la cuenta institucional impide crear estos accesos, detén este paso y avísame: debemos coordinar un acceso programático autorizado. No se soluciona compartiendo la clave del usuario técnico. Los accesos individuales no se presentan como ya configurados. (José Aránguiz)

La contraseña de consola no sustituye las claves programáticas. Tener otra dirección de correo o poder abrir IAM no confirma que esa sesión sea un usuario IAM individual. Antes de crear claves revisaremos la identidad activa y sus permisos.

Referencia: [gestión de claves IAM](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html).

### Paso 4. Configurar el entorno elegido

Desde la raíz del proyecto, en PowerShell:

**Para Docker:**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\configurar.ps1 -Modo Docker
```

**Para ejecución sin Docker:**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\configurar.ps1 -Modo Local
```

Ejecuta solo el que corresponda a tu instalación. El script pregunta región, nombre del bucket y tus credenciales. Para credenciales temporales introduce también el Session Token. Para claves permanentes deja ese token vacío y pulsa Enter.

Docker crea `.env` en la raíz. La ejecución local crea `backend/.env`. Si el archivo ya existe, el script no lo reemplaza; revisa el archivo del entorno correcto en tu editor. No publiques su contenido ni envíes capturas de las claves.

### Paso 5. Comprobar S3

Primero completa el arranque y compilación del camino elegido en las secciones 6 o 7. Después comprueba:

**Con Docker, desde la raíz y con la imagen del backend construida:**

```powershell
docker compose run --rm --no-deps api node dist/storage/check.js
$LASTEXITCODE
```

**Sin Docker, desde la carpeta backend después de npm run build:**

```powershell
node --env-file=.env dist/storage/check.js
$LASTEXITCODE
```

Esperamos el mensaje de conexión a S3 correcta, bloqueo público y ACL deshabilitadas, seguido de código `0`. Esta comprobación no sustituye la prueba posterior de subir y consultar un documento.

Si aparece `NoSuchBucket` o `NotFound`, revisa el nombre del bucket en el archivo correcto: raíz para Docker y backend para local. Si aparece `AccessDenied`, revisaremos permisos; si las credenciales temporales caducaron, renueva la sesión.

El backend requiere ListBucket y las comprobaciones de seguridad del bucket, además de PutObject, GetObject y DeleteObject sobre `patients/*`. El bucket se mantiene privado y con ACL deshabilitadas. Coordinaremos cualquier cambio de permisos y pruebas de borrado. (José Aránguiz)

[Guía de credenciales AWS](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-authentication.html).

## 6. Ejecutar con Docker

Desde la raíz del proyecto:

```powershell
Test-Path .env
Test-Path backend\.env
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\configurar.ps1 -Modo Docker
```

El script crea `.env` en la raíz y genera la contraseña del PostgreSQL Docker. No modifica `backend/.env`. Si el archivo de destino ya existe, se detiene para no sobrescribirlo. Usa región y bucket compartidos y tus credenciales autorizadas.

Antes de arrancar:

```powershell
docker compose config --quiet
docker compose config --services
```

No compartas la salida de `docker compose config` sin `--quiet`: puede mostrar secretos.

Arranca la base y descarga el modelo:

```powershell
docker compose up -d postgres ollama
docker compose exec ollama ollama pull qwen3:4b-instruct
docker compose exec ollama ollama list
```

El modelo de Docker se guarda en su propio volumen. No utiliza automáticamente el modelo instalado en Windows.

Detén con Ctrl+C las terminales anteriores de API, worker o Flutter si van a usar los mismos puertos. Después:

```powershell
docker compose up -d --build api worker
docker compose ps -a
docker compose logs --tail 40 migrate api worker
```

`migrate` debe finalizar con código 0. La API debe iniciar y el worker debe indicar que espera trabajos. El worker se mantiene activo, aunque no haya solicitudes. PostgreSQL y Ollama no publican puertos en este Compose. La API utiliza `127.0.0.1:3000`.

### GPU NVIDIA opcional

Solo para equipos con GPU y controladores compatibles con Docker y WSL 2:

```powershell
docker compose -f compose.yaml -f compose.gpu.yaml up -d postgres ollama
docker compose exec ollama ollama pull qwen3:4b-instruct
docker compose -f compose.yaml -f compose.gpu.yaml up -d --build api worker
```

Usa ambos archivos también en posteriores arranques si elegiste GPU. Sin GPU, utiliza los comandos normales. [GPU en Docker Desktop Windows](https://docs.docker.com/desktop/features/gpu/).

## 7. Ejecutar sin Docker

Instala Node 24, PostgreSQL 16, Ollama y Flutter. Crea una base de pruebas y un usuario autorizado en PostgreSQL. El script no crea la base ni el usuario.

Si ya tienes `backend/.env` funcionando, consérvalo y omite la generación. Para una instalación nueva, desde la raíz:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\configurar.ps1 -Modo Local
```

`backend/.env.example` sirve como referencia sin secretos. Para iniciar la API:

```powershell
cd backend
npm ci
npm run build
npm run migrate
node --env-file=.env dist/database/check.js
node --env-file=.env dist/storage/check.js
ollama pull qwen3:4b-instruct
npm start
```

En otra terminal desde la raíz:

```powershell
cd backend
npm run worker
```

No ejecutes el procesador manual mientras el worker esté activo. Para PostgreSQL detenido, en PowerShell administrador:

```powershell
Get-Service *postgres*
net start postgresql-x64-16
```

Verifica el nombre real del servicio. Para Ollama detenido, abre otra terminal con `ollama serve`. Si el puerto ya está ocupado y `ollama list` funciona, ya existe un servidor.

## 8. Abrir la web

Con API y worker activos, desde la raíz en otra terminal:

```powershell
cd apps\vitalia
flutter pub get
flutter run -d edge --web-hostname localhost --web-port 5173 --dart-define=VITALIA_API_URL=http://127.0.0.1:3000
```

Abre `http://localhost:5173`. Mantén la terminal abierta. Para web compilada con Docker, desde la raíz:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\crear-web.ps1
docker compose --profile web up -d web
```

Elige una opción. Ambas usan el puerto 5173 y no deben arrancar simultáneamente.

## 9. Android en Windows

En Android Studio abre Device Manager y crea un emulador Pixel 3a o Pixel 6. Para la primera prueba, usa Android 15 / API 35 con arquitectura compatible con tu PC, normalmente x86_64 en Intel/AMD. El SDK definitivo depende de `flutter doctor` y del proyecto. Prueba más tamaños y versiones antes de afirmar compatibilidad completa.

Arranca el emulador y ejecuta, desde `apps\vitalia`:

```powershell
flutter doctor --android-licenses
flutter doctor
flutter pub get
flutter devices
flutter run -d emulator-5554 --dart-define=VITALIA_API_URL=http://10.0.2.2:3000
```

Usa el identificador que devuelva `flutter devices` si es diferente. `10.0.2.2` conecta el emulador al anfitrión Windows. Esta guía corresponde a debug y emulador. Un teléfono físico o APK productivo necesita dirección accesible, HTTPS, firma y configuración específica.

## 10. Cuentas y recorrido de prueba

Para una base nueva, el paciente se registra en la app. Administrador y profesional se crean desde terminal con contraseña propia, sin selector público de roles.

Con Docker, desde la raíz:

```powershell
docker compose exec api node dist/database/create-privileged-account.js --role administrador --email admin@example.invalid
docker compose exec api node dist/database/create-privileged-account.js --role profesional --email profesional@example.invalid
```

Sin Docker, desde `backend`:

```powershell
node --env-file=.env dist/database/create-privileged-account.js --role administrador --email admin@example.invalid
node --env-file=.env dist/database/create-privileged-account.js --role profesional --email profesional@example.invalid
```

Los comandos piden contraseña y confirmación. Para probar:
1. El paciente sube un documento ficticio con texto y solicita extracción.
2. El worker procesa y guarda el resultado pendiente de revisión.
3. El administrador asigna paciente al profesional en el flujo actual de pruebas.
4. El profesional coteja el original, corrige si corresponde y aprueba una copia revisada.
5. El paciente consulta resultados, explicación y chat del examen.
6. Comprueba también una imagen sin texto y una solicitud de tratamiento que el asistente debe rechazar.

La elección del médico por el paciente, perfiles completos y atención multiclínica siguen pendientes de implementación. No se consideran disponibles por tener un diagrama propuesto.

## 11. Compartir los datos actuales de PostgreSQL

### Opción A: una copia por integrante

Cada uno restaura una copia y prueba sin depender de mi computador. Los cambios no se sincronizan entre copias. Para un entorno vacío usa las migraciones; para conservar datos de prueba usa un respaldo completo.

El respaldo incluye cuentas, hashes de contraseña, sesiones y conversaciones si existen. Antes de compartirlo, revisa los datos y prepara una copia exclusivamente de pruebas. No publiques un respaldo en GitHub ni compartas contraseñas personales. Los archivos PDF e imágenes siguen en S3 y no forman parte del respaldo PostgreSQL.

Detén API y worker durante la preparación para evitar nuevos trabajos y usa una ventana sin procesos activos. Los documentos apuntarán al bucket original. **No borres documentos desde una copia restaurada que comparte S3**, porque podría eliminar el objeto que usa el resto del equipo. Para pruebas destructivas utiliza documentos y cuentas exclusivos o un entorno de almacenamiento separado.

Exportación desde PostgreSQL Windows, ejemplo con base `vitalia_dev`. Comprueba nombre, usuario y puerto con tu configuración local. El archivo queda fuera del repositorio:

```powershell
$pgBin = 'C:\Program Files\PostgreSQL\16\bin'
$backupDir = Join-Path $env:USERPROFILE 'VitaliaBackups'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$backupFile = Join-Path $backupDir 'vitalia-pruebas.backup'
if (Test-Path $backupFile) { throw 'El respaldo ya existe. Usa otro nombre.' }
& "$pgBin\pg_dump.exe" -h 127.0.0.1 -p 5432 -U vitalia -W -d vitalia_dev --format=custom --file=$backupFile
if ($LASTEXITCODE -ne 0) { throw 'El respaldo no terminó correctamente.' }
```

`-W` pide la contraseña sin escribirla en el comando. Si el usuario de tu base tiene otro nombre, cambia `vitalia`. Comparte únicamente el respaldo revisado por un canal privado autorizado.

**Restauración local del compañero:** en pgAdmin crea una base nueva y vacía, por ejemplo `vitalia_equipo`, con un propietario autorizado. No restaura encima de la base que ya usa. Después:

```powershell
$pgBin = 'C:\Program Files\PostgreSQL\16\bin'
$backupFile = Join-Path $env:USERPROFILE 'VitaliaBackups\vitalia-pruebas.backup'
& "$pgBin\pg_restore.exe" -h 127.0.0.1 -p 5432 -U vitalia -W -d vitalia_equipo --no-owner --no-privileges --single-transaction --exit-on-error $backupFile
if ($LASTEXITCODE -ne 0) { throw 'La restauración falló.' }
```

El compañero debe usar su propio usuario existente si no se llama `vitalia`. Actualiza `backend/.env` con esa base y usuario. Compila y ejecuta las comprobaciones de conexión antes de iniciar API y worker. El respaldo completo ya contiene migraciones aplicadas y sus registros.

**Restauración en Docker:** únicamente si el PostgreSQL del Compose tiene la base de destino vacía y API, worker y migrate todavía no se ejecutaron. No hagas este paso si ya tiene tablas. Copia el respaldo y restaura mediante el ejecutable del contenedor, evitando redirecciones binarias de PowerShell:

```powershell
$backupFile = Join-Path $env:USERPROFILE 'VitaliaBackups\vitalia-pruebas.backup'
$pgContainer = docker compose ps -q postgres
if (-not $pgContainer) { throw 'PostgreSQL Docker no está iniciado.' }
docker cp $backupFile "${pgContainer}:/tmp/vitalia-pruebas.backup"
docker compose exec postgres sh -c 'pg_restore --username="$POSTGRES_USER" --dbname="$POSTGRES_DB" --no-owner --no-privileges --single-transaction --exit-on-error /tmp/vitalia-pruebas.backup'
if ($LASTEXITCODE -ne 0) { throw 'La restauración falló.' }
docker compose exec postgres rm /tmp/vitalia-pruebas.backup
```

Los dos últimos comandos llaman a herramientas dentro del contenedor Linux desde PowerShell Windows. Después inicia migrate, API y worker con el procedimiento Docker. No borres volúmenes para vaciar una base existente.

### Opción B: una base central para el equipo

Todos consultan los mismos datos y los cambios se ven en la misma base. El servidor debe estar encendido y accesible. Estar en casas distintas no permite conectarse al `localhost` de José.

Hace falta una red privada o túnel autorizado, usuarios individuales con permisos limitados, configuración de PostgreSQL (`listen_addresses`, `pg_hba.conf`) y firewall restringido. No publiques el puerto 5432 del computador directamente en Internet ni compartas la cuenta superusuario.

El Compose actual fija `PGHOST=postgres`. Cambiar solo el `.env` no lo conecta a un PostgreSQL remoto. Esta opción requiere otra configuración y todavía no está preparada por este manual.

Para las pruebas iniciales, utilicemos copias de datos ficticios y coordinemos S3. La base central se puede preparar después como entorno de integración del equipo.

[Respaldo PostgreSQL 16](https://www.postgresql.org/docs/16/app-pgdump.html) y [restauración](https://www.postgresql.org/docs/16/app-pgrestore.html).

## 12. Pruebas, parada y problemas comunes

Backend local, desde `backend`:

```powershell
npm ci
npm test
```

Backend con Docker, desde la raíz:

```powershell
docker build --target test -t vitalia-backend-test ./backend
```

Flutter, desde `apps\vitalia`:

```powershell
flutter analyze
flutter test
```

Para detener Docker sin eliminar datos:

```powershell
docker compose --profile web stop
```

Para volver a iniciar:

```powershell
docker compose up -d api worker
```

Si usabas GPU, incluye ambos Compose. Si usabas web compilada, inicia también `docker compose --profile web up -d web`. **No uses `docker compose down -v` para conservar datos:** elimina volúmenes PostgreSQL y Ollama.

- Servidor no disponible: revisa API, puerto 3000 y origen web localhost:5173.
- Extracción pendiente: revisa logs del worker y modelo instalado. Una subida no inicia procesamiento sin la solicitud actual.
- Credenciales S3 vencidas: renueva tu sesión, actualiza tu configuración local y recrea API/worker. Nunca envíes los valores al chat.
- Puerto ocupado: detén el proceso anterior. No arranques ambos caminos simultáneamente.
- Cambiar PGPASSWORD en .env no cambia la contraseña de un volumen PostgreSQL existente.
- Trabajo fallido: actualizar solo consulta. El worker no repite trabajos indefinidamente ni modifica revisiones aprobadas.
- Tras un reinicio del worker, un trabajo interrumpido puede quedar fallido. Utiliza una copia ficticia nueva para otra prueba.

## 13. Evidencias y actualización del proyecto

Conservamos los CAM y avances por fase como registros técnicos. Los datos actuales y el modelo propuesto se distinguen en `docs/base-datos`. Las mejoras pendientes están en `docs/pendientes`.

Para actualizar tu copia desde GitHub Desktop, selecciona `develop`, pulsa Fetch origin y después Pull origin. Desde la raíz también puedes ejecutar:

```powershell
git switch develop
git pull --ff-only
```

Conserva la configuración local. No subas .env, respaldos, node_modules ni compilaciones. El código compartido se obtiene del repositorio oficial `https://github.com/JoseArgz8658/vitalia-health-capstone.git`, rama `develop`.

### Estado de comprobación al 12 de octubre de 2026 — José Aránguiz

Confirmé Compose 5.5.1, migraciones 001–011, conexión PostgreSQL y S3, el flujo paciente–extracción–revisión–consulta con Docker y sin Docker, y conservación de cuentas y revisión tras detener y volver a iniciar los contenedores.

La primera extracción Docker agotó el tiempo. Con compose.gpu.yaml y RTX 3050 de 4 GB, Ollama utilizó CPU/GPU y el nuevo intento terminó pendiente de revisión. No es una garantía de rendimiento para otros equipos.

Con Jest 30.5.2, npm test aprobó 423 pruebas de 40 suites. npm audit --omit=dev reportó cero vulnerabilidades; la auditoría completa mantiene 19 avisos moderados en la cadena de desarrollo de sprintf-js. No aplicar audit fix --force: propone una bajada incompatible de Jest. Detalle y seguimiento: [CAM-078](docs/cambios-codigo/CAM-078-jest-validacion-windows.md).

Las fechas de la copia revisada requieren DD-MM-AAAA. Si se corrige información o quedan campos ausentes, registrar observación y confirmar el cotejo con el original. Las incidencias originales permanecen como evidencia.

Si Windows bloquea impellerc.exe, revisar la directiva de control de aplicaciones antes de cambiar seguridad. Desactivar protecciones no es requisito general del manual.

Android, web compilada con Nginx, restauración de respaldos, instalación completa en otro equipo y accesos AWS del resto del equipo quedan por comprobar. Los registros de esta sesión están en CAM-078.
