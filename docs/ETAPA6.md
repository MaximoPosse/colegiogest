# Etapa 6 · Base de datos, autenticación y seguridad

Documentación técnica de la implementación de Supabase/PostgreSQL en ColegioGest.

> **Actualización final:** las migraciones 009 y 010 endurecen perfiles/bajas/fechas y habilitan alta directa de administradores. Las diez migraciones están aplicadas y registradas en Supabase. Este documento conserva el detalle original y las secciones siguientes indican el estado vigente.

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
10. La interfaz cierra la sesión tras 30 minutos sin actividad y redirige a `/login`.

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
| `administrador` | `/app`, `/app/alumnos`, `/app/profesores`, `/app/usuarios`, `/app/cursos`, `/app/inscripciones`, `/app/calificaciones`, `/app/actividades`, `/app/avisos`, `/app/perfil` | Gestión general. |
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
| `20261110000100_admin_profesores_roles.sql` | Alta/edición/baja de profesores y cambio de rol. |
| `20261110000200_materias_asignaciones.sql` | CRUD de materias y edición/eliminación segura de asignaciones. |
| `20261115000100_security_hardening.sql` | Actualización segura de perfiles, baja docente con asignaciones, altas sin contraseñas predeterminadas y bloqueo de fechas futuras. Aplicada en producción. |
| `20261115000200_admin_account_creation.sql` | Alta directa de usuarios con rol administrador. Preparada; despliegue remoto pendiente. |
| `supabase/seed.sql` | Datos ficticios y 13 cuentas de prueba (contraseña `demo123`). |

### Aplicación manual (sin Supabase CLI)

1. Crear o abrir el proyecto en <https://supabase.com/dashboard>.
2. Ir a **SQL Editor**.
3. Ejecutar `supabase/setup_completo.sql`, que concatena en orden las diez migraciones y el seed.
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
| `usuarios` | Propia fila (aun inactiva) o admin; docente ve usuarios de sus alumnos; alumno ve docentes que le dictan. | Admin. | Admin sobre otros usuarios; la propia fila no se puede actualizar (migración 009). | Admin. |
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
| `proteger_campos_usuario_trg` | `proteger_campos_usuario()` | Bloquea que una cuenta actualice su propia fila y protege campos personales, rol y estado. |
| `set_*_updated_at` | `set_updated_at()` | Actualiza `updated_at` en cada modificación. |
| `validar_calificacion_trg` | `validar_calificacion()` | Exige inscripción activa, asignación vigente y fecha no futura. |
| `validar_asistencia_trg` | `validar_asistencia()` | Exige inscripción activa, asignación vigente y fecha no futura. |
| `validar_actividad_trg` | `validar_actividad()` | Exige asignación vigente del docente. |
| `validar_entrega_trg` | `validar_entrega()` | Exige que el alumno esté inscripto en el curso de la actividad. |
| `validar_inscripcion_trg` | `validar_inscripcion()` | Impide inscribir alumnos inactivos. |

## 9. Funciones RPC

Todas son `SECURITY DEFINER`, validan que el llamador sea administrador (o el caso permitido) y se ejecutan con la publishable key desde el frontend. No requieren `service_role`.

| RPC | Firma resumida | Uso |
| --- | --- | --- |
| `admin_crear_alumno` | `(nombre, apellido, dni, correo, id_curso, password, fecha_nacimiento, telefono)` | Crea `auth.users`, identidad, `usuarios`, `alumnos` e inscripción. |
| `admin_crear_administrador` | `(nombre, apellido, dni, correo, password)` | Crea una cuenta administradora; RPC añadida por la migración 010, aplicada en Supabase. |
| `admin_crear_profesor` | `(nombre, apellido, dni, correo, password)` | Crea cuenta Auth y perfil docente con contraseña indicada explícitamente. |
| `admin_actualizar_alumno` | `(alumno_id, nombre, apellido, dni, correo, estado, id_curso, fecha_nacimiento, telefono)` | Actualiza datos, correo de Auth, estado y cambia la inscripción si corresponde. |
| `admin_baja_alumno` | `(alumno_id)` | Baja lógica: usuario y alumno inactivos, inscripción finalizada. |
| `admin_cambiar_estado_usuario` | `(usuario_id, estado)` | Activa/desactiva cuentas, no permite auto-desactivarse ni baja docente con asignaciones vigentes. |
| `admin_cambiar_rol_usuario` | `(usuario_id, rol)` | Cambia rol y sincroniza perfiles académicos, conservando historial. |
| `admin_actualizar_profesor` / `admin_baja_profesor` | `(profesor_id, ...)` | Edita o da de baja docente; bloquea baja si mantiene asignaciones vigentes. |
| `admin_inscribir_alumno` | `(alumno_id, curso_id)` | Finaliza la inscripción activa anterior y crea la nueva. |
| `admin_crear_asignacion` | `(materia_nombre, curso_id, profesor_id, anio_lectivo, descripcion)` | Crea la materia si no existe y su asignación docente. |
| `admin_eliminar_asignacion` | `(asignacion_id)` | Elimina solo si no hay calificaciones, asistencias ni actividades asociadas. |
| `admin_crear_materia` / `admin_actualizar_materia` / `admin_eliminar_materia` | `(materia_id, ...)` | CRUD del catálogo, con restricción por historial. |
| `admin_actualizar_asignacion` | `(asignacion_id, profesor_id, anio_lectivo)` | Actualiza asignación respetando historial y unicidad. |

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
| Usuarios `/app/usuarios` | Listado, cambio de rol y activación/desactivación; alta directa de administrador con migración 010. |
| Profesores `/app/profesores` | Alta, edición y baja lógica/reactivación con cuenta Auth. |
| Cursos `/app/cursos` | CRUD de cursos y materias; creación, edición y eliminación segura de asignaciones docente-materia-curso. |
| Inscripciones `/app/inscripciones` | Alta de inscripción (finaliza la anterior) y finalización manual. |
| Asistencia `/app/asistencia` | Selección de curso/materia/fecha, carga por alumno y *upsert* por alumno-curso-materia-fecha. |
| Calificaciones `/app/calificaciones` | Listado, alta, edición en línea y eliminación. |
| Actividades `/app/actividades` | Publicación, edición y eliminación según rol; alumnos marcan “entregada”. |
| Avisos `/app/avisos` | Publicación, edición y eliminación según rol; filtros por categoría, curso, texto y fecha. |
| Mis cursos `/app/mis-cursos` | Lectura de materias/asignaciones propias o del curso del alumno. |
| Mis asistencias `/app/mis-asistencias` | Consulta del historial de asistencia propio por materia y fecha. |
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

1. **Estado remoto:** migraciones 001–010 y seed aplicados en Supabase.
2. **Pruebas manuales pendientes:** CRUD completo, cambios de curso y retest de los rechazos de RLS/fechas deben ejecutarse en un proyecto aislado con cuentas descartables.
3. **Correo de recuperación:** requiere Site URL, Redirect URL y configuración de SMTP/buzón de prueba.
4. **Entrega de actividades:** se registra la marca “entregada”; no hay carga de archivos ni comentario desde la interfaz.
5. **Ciclo lectivo:** al cambiar de año hay que crear las asignaciones y cursos correspondientes.
6. **Cuentas demo:** las cuentas del seed son ficticias y solo deben utilizarse en instalaciones de demostración; no reutilizar esas credenciales en un colegio real.
7. **Funciones V2:** reportes PDF/Excel, notificaciones, boletín automático y acceso de tutores no forman parte de la primera versión.
8. **DER:** el diagrama entidad-relación se elabora a partir de `docs/ANALISIS_DATOS_ETAPA3.md` y el esquema SQL.

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
    20261110000100_admin_profesores_roles.sql
    20261110000200_materias_asignaciones.sql
    20261115000100_security_hardening.sql
    20261115000200_admin_account_creation.sql
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
