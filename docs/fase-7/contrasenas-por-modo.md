# Contraseñas por modo — comprobación local

Preparé este incremento en el repositorio de prueba y la rama `fase-7/02-clinicas-pertenencias`. Conservé los datos y la contraseña del modo original. Los accesos profesionales añadidos a pacientes requieren una contraseña diferente. (José Aránguiz)

## 1. Código y pruebas

Desde `backend`:

```powershell
npm test
$LASTEXITCODE
```

Desde `apps/vitalia`:

```powershell
flutter analyze
flutter test
$LASTEXITCODE
```

El backend comprobado tiene 632 pruebas; Flutter debería ejecutar 112. No confundir formato Dart con análisis o ejecución Flutter.

## 2. Respaldo y migración

Después de aprobar las pruebas, detener la API y guardar un respaldo de `vitalia_dev`. No aplicar 018 a otra base. No editar 017 ni migraciones anteriores.

Desde `backend`, usar credenciales administrativas temporales, conservando el usuario normal en `.env`:

```powershell
$usuarioAnterior = $env:PGUSER
$passwordAnterior = $env:PGPASSWORD
$baseAnterior = $env:PGDATABASE
try {
    $credencial = Get-Credential -UserName postgres -Message "Credenciales administrativas de PostgreSQL local"
    if ($null -eq $credencial) { throw "Operación cancelada." }
    $env:PGUSER = "postgres"
    $env:PGPASSWORD = $credencial.GetNetworkCredential().Password
    $env:PGDATABASE = "vitalia_dev"
    node --env-file=.env dist/database/migrate-mode-passwords.js
    if ($LASTEXITCODE -ne 0) { throw "Falló la migración 018." }
    node --env-file=.env dist/database/verify-mode-passwords.js
    if ($LASTEXITCODE -ne 0) { throw "Falló la verificación." }
}
finally {
    $env:PGUSER = $usuarioAnterior
    $env:PGPASSWORD = $passwordAnterior
    $env:PGDATABASE = $baseAnterior
    $credencial = $null
}
```

Resultados previstos: migración de contraseñas por modo aplicada y 39 comprobaciones correctas con datos sintéticos revertidos. El verificador de modos anterior también utiliza ahora el contrato de 018.

En pgAdmin, conectado como postgres a `vitalia_dev`, ejecutar completo `backend/database/permissions/mode-passwords-app.sql`. Conservar los permisos anteriores. Esperar COMMIT. Reiniciar API y Flutter con la cuenta habitual `vitalia_app`.

La migración no añade tablas: se mantienen 40 tablas y pasan a 18 migraciones. Cierra las sesiones de modos adicionales para obligar a configurar su propia contraseña.

## 3. Cuenta que ya era paciente y profesional

Abrir el acceso profesional y pulsar **Configurar contraseña profesional de mi cuenta de paciente**, o abrir `http://localhost:5173/#/clave-profesional`.

Ingresar correo, contraseña actual del paciente, nueva contraseña profesional diferente y confirmación. Confirmar y guardar. La pantalla cierra su sesión temporal; no cambia la sesión de otra pantalla.

Comprobar:

- El modo paciente acepta su contraseña anterior y conserva su historial.
- El modo profesional acepta únicamente la nueva contraseña y conserva su clínica.
- Las contraseñas intercambiadas entre modos se rechazan.
- La misma contraseña para ambos modos se rechaza.
- Una segunda configuración desde paciente no reemplaza la profesional.
- Una cuenta sin permiso profesional no lo obtiene mediante este formulario.

## 4. Primera invitación para un paciente

Crear una invitación para el correo de un paciente de prueba. Abrir `/#/activar-invitacion`, marcar **Ya tengo una cuenta en Vitalia** y mantener desactivado el ingreso con perfil profesional existente. Completar código, nombres, correo, contraseña actual y nueva contraseña profesional con confirmación. Aceptar.

Una contraseña actual incorrecta, la contraseña profesional igual a la de paciente o una confirmación diferente deben impedir la aceptación. Con datos correctos, comprobar ambos modos con sus respectivas contraseñas y conservar los exámenes y datos personales anteriores. La invitación se utiliza una sola vez.

## 5. Profesional que se incorpora a otra clínica

Marcar **Ya tengo una cuenta en Vitalia** y **Ingresar con mi perfil profesional existente**. Ingresar la contraseña profesional actual. No aparecen campos de nueva contraseña. Aceptar la invitación de otra clínica y comprobar que conserva su contraseña profesional y sus pertenencias anteriores.

Comprobar también el acceso del administrador y un profesional cuya cuenta original era profesional: sus contraseñas anteriores se mantienen.

La entrega manual de invitaciones continúa disponible. El envío por correo y la recuperación de contraseña siguen pendientes de implementación.

(José Aránguiz)
