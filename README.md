# ColegioGest

Aplicación web de gestión escolar desarrollada con **Vue 3 + Vite** y **Supabase** (PostgreSQL + Auth). Permite administrar alumnos, cursos, materias, inscripciones, calificaciones, asistencias, actividades y avisos con permisos diferenciados para administradores, profesores y alumnos.

La Etapa 6 incorporó la base de datos real, autenticación, RLS y la conexión de todas las vistas. Los datos mock fueron eliminados.

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
2. Copiar todo el contenido de `supabase/setup_completo.sql` y ejecutarlo una sola vez. Ese archivo ya contiene, en orden, las cinco migraciones y el seed.
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
- Activación/desactivación de cuentas.
- Alta, edición y eliminación de cursos.
- Creación y eliminación de asignaciones docente–materia–curso.
- Gestión de inscripciones (con historial).
- Calificaciones, actividades y avisos.

### Profesor

- Panel con sus cursos y alumnos.
- Registro de asistencia por curso, materia y fecha.
- Carga, edición y eliminación de calificaciones.
- Publicación y eliminación de actividades.
- Avisos para sus cursos.

### Alumno

- Panel con promedio, asistencia y actividades pendientes.
- Consulta de sus calificaciones.
- Consulta de sus materias y horarios.
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
  layouts/           layout de la aplicación autenticada
  lib/               cliente Supabase, mappers, errores y formato
  router/            rutas y guard por rol
  services/          consultas y CRUD por entidad
  stores/            sesión y notificaciones
  views/             pantallas
supabase/
  migrations/        migraciones SQL ordenadas
  seed.sql           datos ficticios de demostración
docs/
  ANALISIS_DATOS_ETAPA3.md
  ETAPA6.md
  PRUEBAS_ETAPA6.md
```

## Documentación

- [Análisis de datos de la Etapa 3](docs/ANALISIS_DATOS_ETAPA3.md)
- [Documentación técnica de la Etapa 6](docs/ETAPA6.md)
- [Pruebas de la Etapa 6](docs/PRUEBAS_ETAPA6.md)

## Estado de la Etapa 6

| Ítem | Estado |
| --- | --- |
| Esquema normalizado, claves, restricciones e índices | ✅ Aplicado en Supabase |
| RLS y permisos por rol | ✅ Aplicado y probado |
| Supabase Auth y recuperación de contraseña | ✅ Aplicado; correo pendiente de configurar |
| Conexión de vistas y CRUD a Supabase | ✅ Implementado |
| Eliminación de datos mock | ✅ Implementado |
| Build de producción | ✅ Verificado |
| Migraciones y seed en el proyecto remoto | ✅ Aplicados el 2026-11-07 |
| Pruebas de login, RLS y escritura por API | ✅ Ejecutadas |
| Flujos principales de UI (login, avisos, notas, asistencia, actividades y guardas) | ✅ Verificados en navegador |
| Alta/edición de alumnos, baja lógica y recuperación de correo | ⏳ Pendientes de recorrido manual |

Ver [docs/PRUEBAS_ETAPA6.md](docs/PRUEBAS_ETAPA6.md) para el detalle de lo ejecutado y los pasos manuales pendientes.
