# ColegioGest

Aplicación web de gestión escolar desarrollada con **Vue 3 + Vite** y **Supabase** (PostgreSQL + Auth). Permite administrar alumnos, cursos, materias, inscripciones, calificaciones, asistencias, actividades y avisos con permisos diferenciados para administradores, profesores y alumnos.

La Etapa 6 incorporó la base de datos real, autenticación, RLS y la conexión de todas las vistas. Los datos mock fueron eliminados. La etapa de completado agregó la gestión de profesores, el cambio de rol de usuarios, la edición de materias/asignaciones/actividades/avisos, la vista de asistencias del alumno y la paginación de listados (ver `docs/ETAPA6_COMPLETADO.md`).

## Stack

- Vue 3 (`<script setup>`)
- Vite 8
- Vue Router 5
- Supabase JS 2
- Supabase Auth + PostgreSQL + Row Level Security
- Lucide icons

## Requisitos

- Node.js 20 o superior
- npm
- Un proyecto Supabase (o Supabase CLI + PostgreSQL para desarrollo local)

## Puesta en marcha

```bash
npm install
cp .env.example .env
# completar VITE_SUPABASE_URL y VITE_SUPABASE_ANON_KEY en .env
npm run dev
```

La aplicación queda disponible en `http://localhost:5173`.

### Variables de entorno

```env
VITE_SUPABASE_URL=https://<proyecto>.supabase.co
VITE_SUPABASE_ANON_KEY=<publishable-o-anon-key>
```

- Usar únicamente la **publishable / anon key** en el frontend.
- **Nunca** incluir la `service_role` key ni contraseñas de base en variables `VITE_*`.
- `.env` está ignorado por git; `.env.example` sí se versiona.

## Configurar Supabase

### 1. Aplicar migraciones

Con la **Supabase CLI**:

```bash
supabase link --project-ref <project-ref>
supabase db push
psql "<connection-string>" -f supabase/seed.sql
```

**Manualmente** desde el Dashboard (opción rápida):

1. Abrir **SQL Editor**.
2. Copiar todo el contenido de `supabase/setup_completo.sql` y ejecutarlo una sola vez. Ese archivo ya contiene, en orden, las ocho migraciones y el seed.
3. Esperar el mensaje `Seed de ColegioGest cargado correctamente.`.

**Manualmente** por archivos:

1. Abrir **SQL Editor**.
2. Ejecutar en orden los archivos de `supabase/migrations/`:
   - `20261106000100_extensions_and_types.sql`
   - `20261106000200_tables.sql`
   - `20261106000300_functions_triggers.sql`
   - `20261106000400_rls_policies.sql`
   - `20261106000500_views.sql`
   - `20261106000600_fix_v_avisos.sql`
   - `20261110000100_admin_profesores_roles.sql`
   - `20261110000200_materias_asignaciones.sql`
3. Ejecutar `supabase/seed.sql`.

### 2. Configurar Auth

En **Authentication → URL Configuration**:

- **Site URL**: `http://localhost:5173`
- **Redirect URLs**: `http://localhost:5173/restablecer`
- En producción, agregar el dominio real y su ruta `/restablecer`.

El envío de correos de recuperación usa el servicio de Supabase. Para producción conviene configurar un proveedor SMTP propio.

## Cuentas de prueba

Todas las cuentas del seed usan la contraseña **`demo123`**.

| Correo | Rol | Persona |
| --- | --- | --- |
| `admin@colegiogest.edu.ar` | administrador | María Fernanda Gómez |
| `profesor@colegiogest.edu.ar` | profesor | Santiago López |
| `alumno@colegiogest.edu.ar` | alumno | Lucía Fernández |
| `carolina.diaz@colegiogest.edu.ar` | profesor | Carolina Díaz |
| `pablo.acosta@colegiogest.edu.ar` | profesor | Pablo Acosta |
| `andrea.molina@colegiogest.edu.ar` | profesor | Andrea Molina |
| `martin.sosa@colegiogest.edu.ar` | profesor | Martín Sosa |
| `laura.benitez@colegiogest.edu.ar` | profesor | Laura Benítez |
| `mateo.ramirez@email.com` | alumno | Mateo Ramírez |
| `sofia.martinez@email.com` | alumno | Sofía Martínez |
| `benjamin.torres@email.com` | alumno | Benjamín Torres |
| `valentina.castro@email.com` | alumno | Valentina Castro |
| `joaquin.herrera@email.com` | alumno | Joaquín Herrera |

## Funcionalidades

### Administrador

- Panel con métricas generales.
- Alta, edición, baja lógica y exportación CSV de alumnos.
- Alta, edición y baja de profesores (RF05), con cuenta de Auth incluida.
- Cambio de rol de usuarios: alumno ⇄ profesor ⇄ administrador, sin perder el historial.
- Activación/desactivación de cuentas.
- Alta, edición y eliminación de cursos.
- Alta, edición y eliminación de materias; solo se borran si no tienen datos asociados.
- Creación, edición y eliminación de asignaciones docente–materia–curso.
- Gestión de inscripciones (con historial).
- Calificaciones, actividades y avisos.

### Profesor

- Panel con sus cursos y alumnos.
- Registro de asistencia por curso, materia y fecha (una fecha ya registrada se actualiza, no se duplica).
- Carga, edición y eliminación de calificaciones.
- Publicación, edición y eliminación de sus propias actividades.
- Avisos para sus cursos: publicar, editar y eliminar los propios.

### Alumno

- Panel con promedio, asistencia y actividades pendientes.
- Consulta de sus calificaciones.
- Consulta de sus materias y horarios.
- Consulta de sus asistencias con porcentaje por materia (`/app/mis-asistencias`).
- Marcado de actividades como entregadas.
- Avisos institucionales y de su curso.

## Seguridad

- **Supabase Auth** para inicio de sesión y recuperación de contraseña.
- El perfil y el rol se leen de `public.usuarios`; nunca se confía en datos del cliente.
- Las cuentas con `estado = 'inactivo'` no pueden operar: la app cierra la sesión y RLS bloquea las consultas.
- **Row Level Security** en las 12 tablas.
- Los docentes solo acceden a sus asignaciones.
- Los alumnos solo acceden a sus propios datos y a los de su curso.
- Las RPC administrativas (`admin_*`) validan el rol dentro de PostgreSQL.
- Un trigger impide que un usuario no administrador cambie su rol o estado.
- No se utiliza `service_role` en el frontend.

## Scripts

```bash
npm run dev      # servidor de desarrollo
npm run build    # build de producción
npm run preview  # previsualizar el build
```

## Estructura

```text
src/
  components/        componentes reutilizables
  components/catalog secciones separadas del catálogo (usuarios, cursos, materias, inscripciones)
  layouts/           layout de la aplicación autenticada
  lib/               cliente Supabase, mappers, errores y formato
  router/            rutas y guard por rol
  services/          consultas y CRUD por entidad
  stores/            sesión y notificaciones
  views/             pantallas
supabase/
  migrations/        migraciones SQL ordenadas
  seed.sql           datos ficticios de demostración
  dev/               scripts de utilidad para pruebas (limpieza de datos de prueba)
docs/
  ANALISIS_DATOS_ETAPA3.md
  ETAPA6.md
  PRUEBAS_ETAPA6.md
  ETAPA6_COMPLETADO.md
```

## Documentación

- [Análisis de datos de la Etapa 3](docs/ANALISIS_DATOS_ETAPA3.md)
- [Documentación técnica de la Etapa 6](docs/ETAPA6.md)
- [Pruebas de la Etapa 6](docs/PRUEBAS_ETAPA6.md)

## Documentación

- [Análisis de datos de la Etapa 3](docs/ANALISIS_DATOS_ETAPA3.md)
- [Documentación técnica de la Etapa 6](docs/ETAPA6.md)
- [Pruebas de la Etapa 6](docs/PRUEBAS_ETAPA6.md)
- [Cambios de la etapa de completado](docs/ETAPA6_COMPLETADO.md)

## Estado

| Ítem | Estado |
| --- | --- |
| Esquema normalizado, claves, restricciones e índices | ✅ Aplicado en Supabase |
| RLS y permisos por rol | ✅ Aplicado y probado |
| Supabase Auth y recuperación de contraseña | ✅ Aplicado |
| Conexión de vistas y CRUD a Supabase | ✅ Implementado |
| Eliminación de datos mock | ✅ Implementado |
| Gestión de profesores (RF05) | ✅ Implementado (migración 007; SQL pendiente de aplicar por el usuario) |
| Cambio de rol de usuarios (RF03) | ✅ Implementado (migración 007; SQL pendiente de aplicar por el usuario) |
| Edición de actividades y avisos propios (RF12/RF14) | ✅ Implementado |
| Materias y asignaciones editables (RF07) | ✅ Implementado (migración 008; SQL pendiente de aplicar por el usuario) |
| Mis asistencias del alumno (RF11) | ✅ Implementado |
| Paginación y filtros de listados (RF18/RNF05) | ✅ Implementado |
| Build de producción | ✅ Verificado |
| Migraciones 001–006 y seed en el proyecto remoto | ✅ Aplicados el 2026-11-07 |
| Migraciones 007–008 en el proyecto remoto | ⏳ SQL listo; el usuario lo ejecuta manualmente |
| Pruebas de login, RLS y escritura por API | ✅ Ejecutadas |
| Flujos principales de UI (login, avisos, notas, asistencia, actividades y guardas) | ✅ Verificados en navegador |
| Alta/edición de alumnos, profesores, cambio de rol y cambio de curso | ⏳ Pendientes de recorrido manual (ver `docs/ETAPA6_COMPLETADO.md`) |

Ver [docs/PRUEBAS_ETAPA6.md](docs/PRUEBAS_ETAPA6.md) y [docs/ETAPA6_COMPLETADO.md](docs/ETAPA6_COMPLETADO.md) para el detalle.
