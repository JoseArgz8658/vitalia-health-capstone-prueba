# Fase 7.2 — Clínicas y pertenencias

Preparé la base institucional en fase-7/02-clinicas-pertenencias. Este primer incremento contiene estructura y verificaciones; no habilita gestión clínica ni invitaciones. La evidencia y límites están en [CAM-087](../cambios-codigo/CAM-087-estructura-clinicas-pertenencias.md). (José Aránguiz)

| Tabla nueva | Finalidad |
|---|---|
| vitalia_clinics | Nombre, contacto opcional y estado de la clínica. |
| vitalia_branches | Clínica, comuna, nombre, dirección, piso/unidad opcionales y estado. |
| vitalia_specialties | Catálogo de especialidades sin cargar una lista clínica no revisada. |
| vitalia_professional_specialties | Relación entre perfil profesional y especialidad. |
| vitalia_clinic_memberships | Pertenencia del profesional a una clínica; inactiva por defecto. |
| vitalia_branch_memberships | Vinculación con sucursales de la misma clínica mediante FK compuestas. |

Aplicar 013 añade seis tablas a las 25 de la fase 7.1: el esquema pasará a 31. Una fila profesional no acredita habilitación; una pertenencia no concede acceso clínico automático. No se asignan clínicas a documentos antiguos ni se cambian revisiones. (José Aránguiz)

## Comprobar código antes de modificar PostgreSQL

Desde la raíz en PowerShell de VS Code, conserva los cambios locales antes de cambiar de rama:

```powershell
git status --short
git fetch origin
git switch fase-7/02-clinicas-pertenencias
cd backend
npm test
$LASTEXITCODE
```

Esperado: 504 pruebas de 45 suites, salida 0. Estas pruebas no migran tu base. No necesitas repetir Flutter por este bloque exclusivamente de backend/datos. (José Aránguiz)

## Aplicación deliberada después de respaldo y revisión

Comprueba en backend/.env y en Query Tool que la base es vitalia_dev y que 012 ya está aplicada. Genera y conserva un respaldo actualizado de la fase 7.1. No reutilices un respaldo anterior de 17 tablas como si incluyera perfiles y ubicación. Revisa el SQL 013 completo antes de ejecutarlo. (José Aránguiz)

Con credenciales administrativas temporales en la terminal, desde backend:

```powershell
node --env-file=.env dist/database/migrate-clinics-memberships.js
$LASTEXITCODE
node --env-file=.env dist/database/verify-clinics-memberships.js
$LASTEXITCODE
```

El primer comando debe informar Migración de clínicas y pertenencias aplicada y salida 0. Si ya estaba aplicada y coincide, lo informa sin duplicar objetos. Ejecuta el verificador solo si la migración terminó correctamente. Esperado: Clínicas y pertenencias: 28 comprobaciones correctas. Datos sintéticos revertidos, salida 0. Usa una conexión administrativa para preparar y revertir esos datos; el usuario de la API continúa siendo vitalia_app. (José Aránguiz)

No conviertas vitalia_app en propietario, superusuario o cuenta de migraciones. No cambies permanentemente backend/.env a postgres. No se requiere otorgar permisos sobre las seis tablas nuevas para el flujo actual. El CRUD institucional todavía no está habilitado. (José Aránguiz)

## Docker y reversión

No inicies Compose sobre volúmenes habituales sin revisar y respaldar: migrate-all descubrirá 013. La construcción de la etapa test, por sí sola, no aplica el cambio a una base externa. La ejecución del contenedor y sus roles requieren validación aparte. (José Aránguiz)

Si falla la migración, la transacción intenta revertirla. Si falla el verificador, revierte sus datos sintéticos y conserva el esquema aplicado. No borres tablas ni edites migraciones ya aplicadas para forzar una repetición. La restauración o eliminación de una copia de pruebas debe planificarse identificando su base y respaldo. (José Aránguiz)

## Continuación funcional

Faltan servicios y pantallas de gestión institucional con auditoría y restricciones por institución. Antes de activar jefes clínicos se incorporará el flujo de autorización externa verificable e invitación; el administrador no podrá nombrarlos por decisión propia. Después se integrarán gestión de profesionales y atención por examen. Ninguna de esas capacidades se considera disponible por esta migración. (José Aránguiz)
