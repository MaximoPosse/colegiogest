# Etapa 6 · Base de datos, autenticación y seguridad

Documentación técnica de la implementación de Supabase/PostgreSQL en ColegioGest.

## 1. Resumen

La Etapa 6 reemplaza los datos mock de `src/data` por un backend real en Supabase:

- Esquema relacional normalizado en PostgreSQL.
- Row Level Security (RLS) para administradores, profesores y alumnos.
- Supabase Auth con cuentas reales y recuperación de contraseña.
- Consultas, altas, bajas y modificaciones desde la interfaz Vue existente.
- Migraciones reproducibles y seed de datos ficticios.
- Documentación de la seguridad y de las pruebas.

La interfaz, los componentes visuales y el stack Vue 3 + Vite se conservaron. Se eliminaron `src/data/mockData.js` y `src/data/demoStore.js` una vez que todas las vistas dejaron de usarlos.

## 2. Arquitectura

```text
Vue 3 + Vite (SPA)
  ├─ src/lib/supabase.js          cliente Supabase (publishable key)
  ├─ src/stores/auth.js           sesión, perfil, recuperación de contraseña
  ├─ src/services/school.js       consultas y CRUD por entidad
  ├─ src/services/dashboard.js    agregados por rol
  ├─ src/router/index.js          rutas y guard por rol
  └─ src/views/*                  pantallas existentes adaptadas a Supabase
            │
            ▼
Supabase
  ├─ Auth                         auth.users, sesiones, recuperación
  └─ PostgreSQL
      ├─ public.usuarios … public.avisos
      ├─ RLS por rol y pertenencia
      ├─ funciones/RPC administrativas
      └─ vistas v_* security_invoker
```

### Capas del frontend

| Archivo | Responsabilidad |
| --- | --- |
| `src/lib/supabase.js` | Crea el cliente con `VITE_SUPABASE_URL` y `VITE_SUPABASE_ANON_KEY`; expone `requireSupabase()`. |
| `src/lib/mappers.js` | Convierte filas de la base a los modelos que usan las vistas (camelCase, etiquetas). |
| `src/lib/errors.js` | Traduce errores de Supabase/PostgreSQL a mensajes en español. |
| `src/stores/auth.js` | `initAuth`, `signIn`, `signOut`, `recoverPassword`, `updatePassword`, perfil y cierre por cuenta inactiva. |
| `src/services/school.js` | Consultas y operaciones de cursos, usuarios, asignaciones, alumnos, inscripciones, calificaciones, asistencias, actividades, entregas y avisos. |
| `src/services/dashboard.js` | Estadísticas y agenda según el rol. |
| `src/router/index.js` | Rutas públicas/privadas y guard por rol. |

## 3. Variables de entorno

```env
VITE_SUPABASE_URL=https://<proyecto>.supabase.co
VITE_SUPABASE_ANON_KEY=<publishable-o-anon-key>
```

- El archivo `.env.example` documenta las variables.
- `.env` está ignorado por git (`.env`, `.env.*`, con excepción de `!.env.example`).
- **Nunca** se debe incluir la `service_role` key ni la contraseña de la base en variables `VITE_*`: Vite las inserta en el bundle público.
- Si faltan las variables, la aplicación arranca pero muestra un mensaje de configuración pendiente y no permite iniciar sesión.

## 4. Autenticación y sesión

1. `initAuth()` se ejecuta en el guard del router.
2. Se recupera la sesión con `supabase.auth.getSession()`.
3. Si hay sesión, se consulta `public.usuarios` con sus perfiles `alumnos`/`profesores` e inscripción activa.
4. Si el perfil no existe, se cierra la sesión y se muestra un error de configuración.
5. Si `estado` no es `activo`, se cierra la sesión y se informa que la cuenta está desactivada.
6. `onAuthStateChange` mantiene la sesión sincronizada (login, logout, refresh de token).
7. `signIn` usa `signInWithPassword`; el correo se normaliza a minúsculas.
8. `recoverPassword` usa `resetPasswordForEmail` con `redirectTo = ${origin}/restablecer`.
9. `updatePassword` usa `auth.updateUser({ password })` en la pantalla `/restablecer`.

### Flujo de recuperación de contraseña

1. El usuario entra a `/recuperar` e ingresa su correo.
2. Supabase envía un enlace al correo.
3. El enlace redirige a `http://localhost:5173/restablecer` (o al dominio configurado).
4. La vista valida la nueva contraseña y llama a `updatePassword`.
5. El usuario puede iniciar sesión con la nueva contraseña.

> **Configuración manual:** en Supabase → Authentication → URL Configuration, agregar la Site URL y la Redirect URL del entorno (`http://localhost:5173/restablecer` en desarrollo).

## 5. Roles y navegación

| Rol | Rutas principales | Alcance |
| --- | --- | --- |
| `administrador` | `/app`, `/app/alumnos`, `/app/usuarios`, `/app/cursos`, `/app/inscripciones`, `/app/calificaciones`, `/app/actividades`, `/app/avisos`, `/app/perfil` | Gestión general. |
| `profesor` | `/app`, `/app/mis-cursos`, `/app/asistencia`, `/app/calificaciones`, `/app/actividades`, `/app/avisos`, `/app/perfil` | Solo cursos, materias y alumnos de sus asignaciones. |
| `alumno` | `/app`, `/app/mis-cursos`, `/app/mis-calificaciones`, `/app/mis-actividades`, `/app/avisos`, `/app/perfil` | Solo su propia información y la de su curso. |

El guard del router valida `meta.roles` antes de entrar a cada ruta. **No es la única defensa**: RLS vuelve a validar en la base. Si un usuario fuerza una ruta o llama directamente a la API, PostgreSQL igualmente bloquea el acceso.

## 6. Migraciones

Ubicación: `supabase/migrations/`. Se aplican en orden por nombre de archivo.

| Archivo | Contenido |
| --- | --- |
| `20261106000100_extensions_and_types.sql` | `pgcrypto` y enumeraciones `rol_usuario`, `estado_cuenta`, `estado_inscripcion`, `estado_asistencia`, `categoria_aviso`, `estado_entrega`. |
| `20261106000200_tables.sql` | Tablas, PK, FK, `CHECK`, índices únicos y de consulta, comentarios. |
| `20261106000300_functions_triggers.sql` | Helpers de identidad, `updated_at`, alta automática desde `auth.users`, protección de rol/estado, validaciones académicas y RPC administrativas. |
| `20261106000400_rls_policies.sql` | RLS y políticas de `SELECT`, `INSERT`, `UPDATE`, `DELETE` por tabla. |
| `20261106000500_views.sql` | Vistas `v_*` con `security_invoker = true` y permisos para `authenticated`. |
| `20261106000600_fix_v_avisos.sql` | Corrige `v_avisos` para que los avisos institucionales no desaparezcan cuando el autor no es visible por RLS. Agrega `nombre_usuario(uuid)`. |
| `supabase/seed.sql` | Datos ficticios y 13 cuentas de prueba (contraseña `demo123`). |

### Aplicación manual (sin Supabase CLI)

1. Crear o abrir el proyecto en <https://supabase.com/dashboard>.
2. Ir a **SQL Editor**.
3. Ejecutar `supabase/setup_completo.sql`, que ya concatena en orden las cinco migraciones y el seed.
   - Alternativa: ejecutar uno por uno los archivos de `supabase/migrations/` y después `supabase/seed.sql`.
4. Verificar en **Table Editor** que existan las tablas y en **Authentication → Users** las cuentas.
5. Iniciar sesión con `admin@colegiogest.edu.ar` / `demo123`.

### Aplicación con Supabase CLI

```bash
supabase link --project-ref <project-ref>
supabase db push
psql "<connection-string>" -f supabase/seed.sql
```

> Las migraciones y el seed se aplicaron en el proyecto remoto el 2026-11-07. Ver `docs/PRUEBAS_ETAPA6.md`.

## 7. Modelo de datos

El detalle de tablas, columnas y relaciones está en [`docs/ANALISIS_DATOS_ETAPA3.md`](./ANALISIS_DATOS_ETAPA3.md) y en las migraciones de `supabase/migrations/`.

Tablas:

`usuarios`, `alumnos`, `profesores`, `cursos`, `materias`, `asignaciones`, `inscripciones`, `calificaciones`, `asistencias`, `actividades`, `entregas_actividades`, `avisos`.

Enumeraciones:

`rol_usuario`, `estado_cuenta`, `estado_inscripcion`, `estado_asistencia`, `categoria_aviso`, `estado_entrega`.

## 8. Row Level Security

### Principios

- **Sin cuenta activa no hay datos.** Casi todas las políticas incluyen `public.cuenta_activa()`.
- **El rol se lee de `public.usuarios`**, no de `user_metadata` ni de datos del cliente.
- **El alumno solo ve lo propio** y lo vinculado a su curso activo.
- **El profesor solo opera sobre sus asignaciones.**
- **El administrador gestiona el sistema.**
- Los helpers son `SECURITY DEFINER` para evitar recursión de RLS y solo devuelven booleanos, ids del propio usuario o conteos.

### Matriz resumida

| Tabla | SELECT | INSERT | UPDATE | DELETE |
| --- | --- | --- | --- | --- |
| `usuarios` | Propia fila (aun inactiva) o admin; docente ve usuarios de sus alumnos; alumno ve docentes que le dictan. | Admin. | Admin, o el propio usuario con restricción de rol/estado por trigger. | Admin. |
| `alumnos` | Admin, el propio alumno, o docente con acceso al alumno. | Admin. | Admin. | Admin. |
| `profesores` | Admin, el propio docente, o alumno que curse con él. | Admin. | Admin. | Admin. |
| `cursos` | Admin, docente asignado, o alumno en su curso activo. | Admin. | Admin. | Admin. |
| `materias` | Admin, docente asignado, o alumno con esa materia en su curso. | Admin. | Admin. | Admin. |
| `asignaciones` | Admin, docente propio, o alumno de ese curso. | Admin. | Admin. | Admin. |
| `inscripciones` | Admin, el propio alumno, o docente del curso. | Admin. | Admin. | Admin. |
| `calificaciones` | Admin, el propio alumno, o docente que dicta la materia en el curso del alumno. | Admin o docente propio que dicte la materia/curso. | Admin o docente autor. | Admin o docente autor. |
| `asistencias` | Admin, el propio alumno, o docente que dicta materia/curso. | Admin o docente propio que dicte materia/curso. | Admin o docente autor. | Admin o docente autor. |
| `actividades` | Admin, docente autor, o alumno del curso. | Admin o docente propio que dicte materia/curso. | Admin o docente autor. | Admin o docente autor. |
| `entregas_actividades` | Admin, el propio alumno, o docente autor de la actividad. | Admin o alumno propio en actividad de su curso. | Admin, alumno propio o docente autor. | Admin o alumno propio. |
| `avisos` | Admin, autor, aviso institucional (`id_curso_destino is null`), alumno de ese curso o docente de ese curso. | Admin, o docente autor con destino permitido. | Admin o autor. | Admin o autor. |

### Triggers de protección

| Trigger | Función | Efecto |
| --- | --- | --- |
| `on_auth_user_created` | `handle_new_user()` | Crea `usuarios` y el perfil `alumnos`/`profesores` al crear una cuenta en Auth. |
| `proteger_campos_usuario_trg` | `proteger_campos_usuario()` | Impide que un no administrador cambie su propio `rol` o `estado`. |
| `set_*_updated_at` | `set_updated_at()` | Actualiza `updated_at` en cada modificación. |
| `validar_calificacion_trg` | `validar_calificacion()` | Exige inscripción activa y asignación vigente. |
| `validar_asistencia_trg` | `validar_asistencia()` | Exige inscripción activa y asignación vigente. |
| `validar_actividad_trg` | `validar_actividad()` | Exige asignación vigente del docente. |
| `validar_entrega_trg` | `validar_entrega()` | Exige que el alumno esté inscripto en el curso de la actividad. |
| `validar_inscripcion_trg` | `validar_inscripcion()` | Impide inscribir alumnos inactivos. |

## 9. Funciones RPC

Todas son `SECURITY DEFINER`, validan que el llamador sea administrador (o el caso permitido) y se ejecutan con la publishable key desde el frontend. No requieren `service_role`.

| RPC | Firma resumida | Uso |
| --- | --- | --- |
| `admin_crear_alumno` | `(nombre, apellido, dni, correo, id_curso, password, fecha_nacimiento, telefono)` | Crea `auth.users`, identidad, `usuarios`, `alumnos` e inscripción. |
| `admin_actualizar_alumno` | `(alumno_id, nombre, apellido, dni, correo, estado, id_curso, fecha_nacimiento, telefono)` | Actualiza datos, correo de Auth, estado y cambia la inscripción si corresponde. |
| `admin_baja_alumno` | `(alumno_id)` | Baja lógica: usuario y alumno inactivos, inscripción finalizada. |
| `admin_cambiar_estado_usuario` | `(usuario_id, estado)` | Activa o desactiva cualquier cuenta; no permite auto-desactivarse. |
| `admin_inscribir_alumno` | `(alumno_id, curso_id)` | Finaliza la inscripción activa anterior y crea la nueva. |
| `admin_crear_asignacion` | `(materia_nombre, curso_id, profesor_id, anio_lectivo, descripcion)` | Crea la materia si no existe y su asignación docente. |
| `admin_eliminar_asignacion` | `(asignacion_id)` | Elimina solo si no hay calificaciones, asistencias ni actividades asociadas. |

Helpers de RLS: `rol_actual`, `cuenta_activa`, `es_admin`, `es_profesor`, `es_alumno`, `mi_alumno_id`, `mi_profesor_id`, `mi_curso_id`, `curso_de_alumno`, `profesor_dicta`, `profesor_puede_ver_curso`, `profesor_puede_ver_alumno`, `profesor_puede_ver_usuario`, `alumno_puede_ver_profesor`, `alumno_puede_ver_materia`, `profesor_puede_ver_materia`, `profesor_es_autor_actividad`, `contar_alumnos_curso`, `nombre_usuario`.

`nombre_usuario(uuid)` es una excepción deliberada y acotada: solo devuelve `nombre || ' ' || apellido` del autor de un aviso. No expone DNI ni correo, y su ejecución está revocada para `public` y `anon`.

## 10. Vistas de lectura

Todas son `security_invoker = true`: respetan RLS y no elevan privilegios.

| Vista | Contenido |
| --- | --- |
| `v_alumnos` | Alumno + usuario + inscripción activa + curso. |
| `v_profesores` | Profesor + usuario. |
| `v_cursos` | Curso + cantidad de alumnos activos. |
| `v_asignaciones` | Materia, curso, docente y ciclo. |
| `v_inscripciones` | Alumno, DNI, curso, fecha y estado. |
| `v_calificaciones` | Alumno, materia, docente, nota, fecha y curso activo. |
| `v_asistencias` | Alumno, curso, materia, docente, fecha y estado. |
| `v_actividades` | Actividad, materia, curso y docente. |
| `v_entregas` | Entrega, actividad, alumno y estado. |
| `v_avisos` | Aviso, autor (nombre vía `nombre_usuario`), categoría y curso destino. |

> **Corrección (migración 006):** la primera versión de `v_avisos` unía `usuarios` con `INNER JOIN`. Como la política `usuarios_select` no permite que un alumno o profesor lea la fila del administrador, los avisos institucionales desaparecían del resultado. Ahora la vista no une `usuarios` y obtiene solo el nombre del autor con `public.nombre_usuario(...)`; la visibilidad de las filas sigue dependiendo de la RLS de `avisos`.

## 11. CRUD implementado por pantalla

| Pantalla / ruta | Operaciones conectadas a Supabase |
| --- | --- |
| Dashboard `/app` | Lectura de estadísticas, avisos, actividades y agenda según rol. |
| Alumnos `/app/alumnos` | Listado, búsqueda, filtro por curso, paginación, exportación CSV y baja lógica. |
| Nuevo/editar alumno | Alta con cuenta de Auth y contraseña inicial; edición de datos, estado y curso; validación de DNI/correo duplicados. |
| Usuarios `/app/usuarios` | Listado y activación/desactivación de cuentas. |
| Cursos `/app/cursos` | Alta, edición y eliminación de cursos; alta y eliminación de asignaciones docente-materia-curso. |
| Inscripciones `/app/inscripciones` | Alta de inscripción (finaliza la anterior) y finalización manual. |
| Asistencia `/app/asistencia` | Selección de curso/materia/fecha, carga por alumno y *upsert* por alumno-curso-materia-fecha. |
| Calificaciones `/app/calificaciones` | Listado, alta, edición en línea y eliminación. |
| Actividades `/app/actividades` | Listado, publicación y eliminación por docente; alumnos marcan “entregada”. |
| Avisos `/app/avisos` | Listado, filtro por categoría, publicación para toda la comunidad o un curso, y eliminación. |
| Mis cursos `/app/mis-cursos` | Lectura de materias/asignaciones propias o del curso del alumno. |
| Perfil `/app/perfil` | Lectura de datos personales, rol, curso, promedio y asistencia. |

## 12. Seed y cuentas de prueba

Todas las cuentas usan la contraseña **`demo123`**.

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

Datos incluidos: 6 cursos, 8 materias, 17 asignaciones, 6 inscripciones activas, 9 calificaciones, 5 asistencias, 5 actividades, 1 entrega y 4 avisos.

## 13. Seguridad

- La publishable/anon key es la única credencial del frontend. RLS es la frontera de seguridad.
- No se usa `service_role` en el navegador.
- Las RPC administrativas validan `es_admin()` dentro de la base.
- El rol y el estado de la cuenta no se pueden auto-modificar (trigger).
- Los datos personales se guardan una sola vez en `usuarios`.
- Las contraseñas se almacenan en `auth.users` mediante `crypt` de `pgcrypto`; el frontend nunca las lee.
- Las vistas no evitan RLS (`security_invoker = true`).
- `nombre_usuario(uuid)` solo devuelve nombre y apellido; no expone DNI ni correo y está revocada para `anon`.
- `anon` no tiene permisos sobre tablas, secuencias ni funciones del esquema `public`.
- Las bajas de alumnos son lógicas para conservar historial.
- La eliminación de asignaciones con historial está bloqueada.

## 14. Limitaciones y pendientes

1. **Migraciones y seed aplicados:** el esquema y el seed se ejecutaron en el proyecto `dnifipldschmuxkxvizi` el 2026-11-07 mediante la Management API. Los conteos y las políticas se verificaron en vivo (ver `docs/PRUEBAS_ETAPA6.md`).
2. **Pruebas de UI parcialmente recorridas:** login, avisos, calificaciones, asistencia, actividades y guardas de rol se verificaron en navegador (ver `docs/PRUEBAS_ETAPA6.md`, sección 4). Falta recorrer los formularios de alta/edición/baja de alumnos, cursos y asignaciones, además del correo real de recuperación.
3. **Correo de recuperación:** requiere configurar Site URL y Redirect URLs en Supabase Auth. Sin un proveedor SMTP propio, Supabase usa su servicio de correo con límites.
4. **Alta de docentes:** la interfaz actual permite gestionar docentes existentes (asignaciones y estado), pero no crear nuevos docentes desde cero. Se pueden crear desde Supabase Auth + SQL o ampliar una RPC similar a `admin_crear_alumno`.
5. **Edición de avisos:** la interfaz permite publicar y eliminar, pero no editar un aviso existente (la política RLS de `UPDATE` ya está preparada).
6. **Entrega de actividades:** se registra la marca de entrega; no hay carga de archivos ni comentario desde la interfaz.
7. **Ciclo lectivo:** el seed usa 2026. Al cambiar de año hay que crear las asignaciones y cursos correspondientes.
8. **Cuentas demo visibles:** la pantalla de login muestra botones con las cuentas del seed. Conviene ocultarlos o eliminarlos en una instalación de producción.
9. **DER:** el diagrama entidad-relación se elabora de forma manual; no está incluido en el repositorio.

## 15. Archivos principales

```text
supabase/
  migrations/
    20261106000100_extensions_and_types.sql
    20261106000200_tables.sql
    20261106000300_functions_triggers.sql
    20261106000400_rls_policies.sql
    20261106000500_views.sql
    20261106000600_fix_v_avisos.sql
  seed.sql
src/
  lib/{supabase,errors,format,mappers}.js
  stores/{auth,toast}.js
  services/{school,dashboard}.js
  router/index.js
  views/*.vue
docs/
  ANALISIS_DATOS_ETAPA3.md
  ETAPA6.md
  PRUEBAS_ETAPA6.md
.env.example
```
