# Etapa 6 · Completado de funcionalidades

Detalle de los cambios de la etapa que completa ColegioGest sobre la base de la Etapa 6 (base de datos, Auth y RLS). Asume que las migraciones 001–006 y el seed ya están aplicados.

## 1. Resumen

Se completaron nueve tareas sobre la implementación existente, todo con el patrón ya consolidado:

- Cambios de base de datos en migraciones nuevas (numeración 2026111000*), nunca editando las anteriores.
- Permisos aplicados en PostgreSQL: RPC `admin_*` `SECURITY DEFINER` que validan `es_admin()`, más RLS. `service_role` sigue sin usarse en el frontend.
- Validación de formularios + mensajes con toast + confirmación en operaciones destructivas + refresco automático de listados sin recargar la página.
- Interfaz y mensajes en español, reutilizando los componentes (`DataTable`, `FormField`, `SearchFilterBar`, `StatCard`, etc.) y estilos de `style.css`.

## 2. Migraciones nuevas (en orden de ejecución)

| Archivo | Contenido |
| --- | --- |
| `supabase/migrations/20261110000100_admin_profesores_roles.sql` | RPC `admin_crear_profesor`, `admin_actualizar_profesor`, `admin_baja_profesor` (baja lógica con control de asignaciones vigentes) y `admin_cambiar_rol_usuario`. |
| `supabase/migrations/20261110000200_materias_asignaciones.sql` | RPC `admin_crear_materia`, `admin_actualizar_materia`, `admin_eliminar_materia` (con motivo si tiene datos), `admin_actualizar_asignacion` y `admin_crear_asignacion` actualizada (duplicado con error legible). |

Además:

- `supabase/setup_completo.sql` se regeneró para incluir las migraciones 007 y 008 antes del seed. Si el proyecto ya tiene 001–006 y el seed aplicados, alcanza con ejecutar las dos migraciones nuevas directamente en el SQL Editor.
- `supabase/dev/limpiar_datos_test.sql` es un script de limpieza para pruebas (ver sección 6).

> **Pendiente del usuario:** las migraciones 007 y 008 se ejecutan a mano en el SQL Editor. El código ya las usa, así que la aplicación depende de que estén aplicadas.

## 3. Cambios por tarea

### (1) Gestión de profesores · RF05
- Nueva ruta `/app/profesores` para administrador con entrada en `SideMenu`.
- Listado con búsqueda, filtro por estado y paginación; alta y edición con formulario validado; baja con diálogo de confirmación que explica si el profesor tiene asignaciones.
- Codigos de error nuevos traducidos en `src/lib/errors.js`: `PROFESOR_NO_ENCONTRADO`, `PROFESOR_CON_ASIGNACIONES`.

### (2) Cambio de rol de usuarios · RF03
- Selector de rol con confirmación en la sección Usuarios (`UsersSection`).
- La RPC impide que el administrador se quite su propio rol y que el sistema quede sin administradores activos; conserva el historial finalizando inscripciones y desactivando perfiles en lugar de borrarlos.
- El trigger `proteger_campos_usuario` sigue funcionando: las RPC son `SECURITY DEFINER` y escriben con la identidad admin.

### (3) Edición de actividades y avisos · RF12/RF14
- Verificado en las políticas RLS de `actividades` y `avisos`: `UPDATE` ya permitía al autor-docente y al administrador; no fue necesario cambiarlas ni crear migración extra.
- `updateActivity`/`updateNotice` en `school.js`; edición desde la lista reutilizando el formulario de alta. El profesor solo edita lo propio (`id_profesor = mi_profesor_id()` / `id_autor = auth.uid()`).

### (4) Materias y asignaciones · RF07
- Edición de nombre/descripción de materia y eliminación con motivo (`MATERIA_CON_ASIGNACIONES`, `MATERIA_CON_CALIFICACIONES`, `MATERIA_CON_ASISTENCIAS`, `MATERIA_CON_ACTIVIDADES`).
- Edición de asignación (docente y ciclo lectivo) con `admin_actualizar_asignacion`; no permite cambiar el docente si hay calificaciones, asistencias o actividades de esa asignación (`ASIGNACION_CON_HISTORIAL`).
- UI implementada en `CoursesSection` dentro del catálogo.

### (5) Verificaciones RF08, RF09 y RF11
- RF08 (cambio de curso): `admin_inscribir_alumno` ya finaliza la inscripción anterior, crea la nueva y respeta el índice `inscripciones_una_activa_por_alumno`; el historial se conserva. Sin cambios.
- RF09 (modificar asistencia): `saveAttendance` ya hace *upsert* por `(id_alumno, id_curso, id_materia, fecha)` y la pantalla precarga la fecha registrada. Sin cambios.
- RF11: nueva vista **Mis asistencias** (`/app/mis-asistencias`, solo alumno) con detalle por materia y fecha y porcentaje por materia. Solo lectura.

### (6) Búsquedas, filtros y paginación · RF18/RNF05
- `DataTable.vue` incorpora paginación opcional (10 por página) con reinicio a la página 1 al cambiar el contenido; se usa en calificaciones, profesores y mis-asistencias.
- Alumnos usa paginación del lado del servidor con `range()` (`fetchStudentsPage`).
- Avisos ya filtra por curso y por texto; asistencia ya filtra por curso/materia/fecha. Los vacíos muestran "No hay resultados" con los textos de `DataTable`.

### (7) Limpieza y organización
- Se eliminaron `HelloWorld.vue` y los assets sin uso (`hero.png`, `vue.svg`, `vite.svg`).
- `CatalogView.vue` se dividió en `src/components/catalog/`: `UsersSection`, `CoursesSection` y `EnrollmentsSection`, con una única vista que renderiza la sección según la ruta (`/app/usuarios`, `/app/cursos`, `/app/inscripciones`).
- Verificación de navegación: menú por rol, rutas con `meta.roles`, redirecciones a login/sin-permiso/404 sin pantallas rotas.

### (8) Script de limpieza para pruebas
- `supabase/dev/limpiar_datos_test.sql`: borra en orden de dependencias las cuentas (`auth.users`) y datos cuyo correo empieza con `test_` y las filas con nombres/títulos/descripciones con prefijo `TEST_` (materias, actividades, avisos y todo lo dependiente: entregas, calificaciones, asistencias, inscripciones, asignaciones). Al terminar informa cuántos registros borró por tabla y el total. No toca datos del seed y es re-ejecutable.
- Ejecutarlo SOLO desde el SQL Editor del dashboard, nunca desde el frontend.

## 4. Lista de archivos

### Creados

| Archivo | Propósito |
| --- | --- |
| `supabase/migrations/20261110000100_admin_profesores_roles.sql` | Profesores y cambio de rol. |
| `supabase/migrations/20261110000200_materias_asignaciones.sql` | Materias y asignaciones editables. |
| `supabase/dev/limpiar_datos_test.sql` | Limpieza de datos de prueba. |
| `src/views/TeachersView.vue` | Pantalla Profesores (RF05). |
| `src/views/MyAttendanceView.vue` | Pantalla Mis asistencias (RF11). |
| `src/components/catalog/UsersSection.vue` | Sección usuarios del catálogo. |
| `src/components/catalog/CoursesSection.vue` | Sección cursos/materias/asignaciones del catálogo. |
| `src/components/catalog/EnrollmentsSection.vue` | Sección inscripciones del catálogo. |

### Modificados

`src/services/school.js`, `src/services/dashboard.js`, `src/lib/errors.js`, `src/lib/mappers.js`, `src/router/index.js`, `src/components/DataTable.vue`, `src/components/SideMenu.vue`, `src/style.css`, `src/views/ActivitiesView.vue`, `src/views/CatalogView.vue`, `src/views/GradesView.vue`, `src/views/NoticesView.vue`, `src/views/StudentsView.vue`, `supabase/setup_completo.sql`, `README.md`.

### Eliminados

`src/components/HelloWorld.vue`, `src/assets/hero.png`, `src/assets/vue.svg`, `src/assets/vite.svg`.

## 5. Pasos de prueba manual por rol

Asumir migraciones 007/008 aplicadas y el seed cargado. Contraseña de las cuentas del seed: `demo123`.

### Administrador (admin@colegiogest.edu.ar)

1. **Profesores:** crear en `/app/profesores` un profesor con correo `test_profesor@colegiogest.edu.ar`. Verificar toasts de éxito y búsqueda por nombre/DNI. Cerrar sesión y loguear con esa cuenta (contraseña `demo123`): el menú debe ser el de profesor.
2. **Baja de profesor:** como admin, intentar dar de baja `profesor@colegiogest.edu.ar` (Santiago López): debe bloquearse avisando que tiene asignaciones vigentes. Dar de baja de otra forma: primero reasignar las asignaciones. Luego verificar que la cuenta no puede iniciar sesión.
3. **Cambio de rol:** en `/app/usuarios` cambiar el rol de un alumno a profesor y volver a iniciar sesión con él (menú de profesor). Devolverlo a alumno.
4. **Materias:** en `/app/cursos` editar el nombre de una materia; intentar eliminar una con asignaciones (debe bloquearse explicando el motivo) y eliminar una creada al efecto sin datos (debe borrar).
5. **Asignaciones:** editar una asignación cambiando el docente o el año; intentar cambiar el docente de una asignación con calificaciones (por historial).
6. **Cambio de curso (RF08):** en `/app/inscripciones` inscribir un alumno en curso activo en otro curso; la inscripción anterior debe quedar `finalizada` y la nueva `activa`.
7. **Limpieza:** ejecutar `supabase/dev/limpiar_datos_test.sql` en el SQL Editor y verificar el detalle de registros borrados (PI08).

### Profesor (profesor@colegiogest.edu.ar)

1. **Actividades:** en `/app/actividades` editar una actividad propia y verificar que persiste el cambio.
2. **Avisos:** en `/app/avisos` publicar un aviso `TEST_Aviso`, editarlo y eliminarlo. Con otro docente, verificar que no aparecen los botones de editar/eliminar sobre avisos ajenos.
3. **Asistencia:** en `/app/asistencia` registrar una fecha, cambiar estados y volver a guardar; no se deben duplicar filas.
4. **Alcance:** entrar a una ruta de administrador (`/app/profesores`) con la URL directa: debe aparecer «sin permiso».

### Alumno (alumno@colegiogest.edu.ar)

1. **Mis asistencias:** abrir `/app/mis-asistencias` y verificar detalle por materia/fecha y porcentaje por materia.
2. **Avisos y actividades:** verificar que ve los cambios hechos por el profesor (actividad editada) y que no tiene botones de edición.
3. **Alcance:** entrar a `/app/alumnos` con la URL directa: debe aparecer «sin permiso».

## 6. Pruebas de integración habilitadas

Con la migración 007 aplicada, quedan ejecutables:

- **PI08 — desactivar un profesor:** alta de profesor → asignación → baja bloqueada → reasignación → baja con cuenta sin acceso.
- **PI09 — cambio de rol:** alumno → profesor → login como profesor → profesor → alumno → login como alumno.

Después de cada corrida, ejecutar `supabase/dev/limpiar_datos_test.sql` para restaurar el estado.
