# Pruebas · Etapa 6

Registro de las verificaciones ejecutadas sobre el proyecto Supabase `dnifipldschmuxkxvizi` y de los casos que todavía requieren recorrido manual de la interfaz.

> **Estado:** el esquema, las políticas RLS y el seed se aplicaron el **2026-11-07** mediante la Management API de Supabase. Las pruebas de API, autenticación, RLS y los flujos principales de UI que figuran abajo se ejecutaron realmente. Quedan pendientes los formularios de alta/edición/baja y el envío real del correo de recuperación.

## 1. Entorno de prueba

| Elemento | Valor |
| --- | --- |
| Fecha | 2026-11-07 |
| Sistema | Windows, PowerShell 5.1 |
| Node / npm | Node del entorno local, Vite 8.3.6 |
| Proyecto Supabase | `https://dnifipldschmuxkxvizi.supabase.co` (región `us-east-2`) |
| Credencial usada para administrar | Personal Access Token vía Management API (no se guardó en el repositorio) |
| Credencial del frontend | Publishable key (`sb_publishable_…`) |
| Base local | No utilizada |
| Navegador | Navegador integrado de OpenCode |

## 2. Pruebas ejecutadas

| ID | Verificación | Evidencia | Resultado |
| --- | --- | --- | --- |
| E1 | Dependencias de Supabase instaladas | `@supabase/ssr@0.12.7`, `@supabase/supabase-js@2.119.0` | **Aprobada** |
| E2 | Compilación de producción | `npm run build` → `✓ 2135 modules transformed`, `✓ built in 1.72s`; `dist/assets/index-CHxxwXJZ.js` (444.04 kB) y `dist/assets/index-CcP2gl4e.css` (35.08 kB) | **Aprobada** |
| E3 | Eliminación de datos mock | Sin coincidencias de `mockData`, `demoStore`, `src/data`; `src/data` no existe | **Aprobada** |
| E4 | Carga de la pantalla de login | Servidor Vite en `http://127.0.0.1:5173/login`; formulario visible | **Aprobada** |
| E5 | Sin errores de consola en login | `browser.console(level: 'error')` → `[]` | **Aprobada** |
| E6 | Variables de entorno | `.env.example` con `VITE_SUPABASE_URL` y `VITE_SUPABASE_ANON_KEY`; `.env` ignorado por git | **Aprobada** |
| E7 | Salud de Supabase Auth | `GET /auth/v1/health` → HTTP `200` | **Aprobada** |
| E8 | Esquema aplicado | `public.usuarios` responde; conteos del seed correctos (ver sección 3) | **Aprobada** |
| E9 | Documentación creada | `docs/ANALISIS_DATOS_ETAPA3.md`, `docs/ETAPA6.md`, `docs/PRUEBAS_ETAPA6.md` | **Aprobada** |
| E10 | DER | Se retiró la versión generada; el diagrama será elaborado manualmente por el usuario | ⏳ Pendiente |
| E11 | Login de las tres cuentas demo | `POST /auth/v1/token` → HTTP `200` para `admin@`, `profesor@` y `alumno@colegiogest.edu.ar` con `demo123` | **Aprobada** |
| E12 | Matriz de visibilidad RLS | Admin 6 alumnos / 17 asignaciones / 9 notas / 13 usuarios. Profesor 4 alumnos / 3 asignaciones / 5 notas / 5 usuarios. Alumno 1 alumno / 6 asignaciones / 4 notas / 7 usuarios | **Aprobada** |
| E13 | Alumno intenta insertar una calificación | HTTP `403`, `42501`, `new row violates row-level security policy for table "calificaciones"` | **Aprobada** |
| E14 | Profesor intenta calificar un curso no asignado | HTTP `400`, `23514`, `La calificación debe corresponder a un alumno inscripto y a una asignación vigente del docente.` | **Aprobada** |
| E15 | Alumno intenta cambiarse el rol | HTTP `403`, `42501`, `No tenés permiso para modificar el rol o el estado de la cuenta.` | **Aprobada** |
| E16 | Alumno intenta publicar un aviso | HTTP `403`, `42501`, `new row violates row-level security policy for table "avisos"` | **Aprobada** |
| E17 | Escrituras válidas | Alumno marca entrega (`201`), profesor carga nota (`201`), admin crea curso (`201`); los tres registros se eliminaron después (`200`) | **Aprobada** |
| E18 | Validación de datos inválidos | Curso con `anio = 99` → HTTP `400` (CHECK) | **Aprobada** |
| E19 | RLS, políticas, vistas y RPC | 12 tablas con `relrowsecurity = true`; 48 políticas; 10 vistas; 7 RPC `admin_*` + `nombre_usuario` | **Aprobada** |
| E20 | Rol anónimo bloqueado | `GET v_alumnos` como `anon` → HTTP `401 permission denied for view v_alumnos`; `rpc/nombre_usuario` como `anon` → HTTP `401 permission denied for function` | **Aprobada** |
| E21 | Corrección de avisos institucionales | Antes del fix: alumno veía 2 avisos y profesor 1. Después de la migración 006: admin 4, profesor 4, alumno 4 | **Aprobada** |

### Evidencia de E2

```text
> colegiogest@0.0.0 build
> vite build

vite v8.3.6 building client environment for production...
transforming...
✓ 2135 modules transformed.
dist/index.html                   0.46 kB │ gzip:   0.29 kB
dist/assets/index-CcP2gl4e.css   35.08 kB │ gzip:   7.23 kB
dist/assets/index-CHxxwXJZ.js   444.04 kB │ gzip: 128.58 kB

✓ built in 1.72s
```

### Evidencia de E11

```text
LOGIN OK  admin@colegiogest.edu.ar     user=11111111-1111-4111-8111-111111111111
LOGIN OK  profesor@colegiogest.edu.ar  user=22222222-2222-4222-8222-222222222222
LOGIN OK  alumno@colegiogest.edu.ar    user=33333333-3333-4333-8333-333333333331
```

### Evidencia de E12 (RLS por rol)

| Vista / tabla | Admin | Profesor (Santiago) | Alumno (Lucía) |
| --- | --- | --- | --- |
| `v_alumnos` | 6 | 4 | 1 |
| `v_asignaciones` | 17 | 3 | 6 |
| `v_calificaciones` | 9 | 5 | 4 |
| `v_avisos` | 4 | 4 | 4 |
| `usuarios` | 13 | 5 | 7 |

Interpretación:

- El profesor solo ve los alumnos de 3.º A, 3.º B y 2.º A, sus 3 asignaciones y las notas que él cargó.
- El alumno solo se ve a sí mismo, las materias de su curso y sus 4 calificaciones.
- Los avisos institucionales llegan a los tres roles después de la migración 006.

### Evidencia de E17

```text
entrega alumno:  HTTP 201  id=d443bb76-1246-4112-af25-c2ceac162dcd
borrar entrega:  HTTP 200
nota profesor:   HTTP 201  id=03bf259f-65b7-4dc7-89ce-495a0be28f1f
borrar nota:     HTTP 200
curso admin:     HTTP 201  id=7b6ad302-6816-499f-9876-0ae8f0f2f37c
borrar curso:    HTTP 200
curso invalido:  HTTP 400
```

Los registros de prueba se eliminaron; los conteos finales coinciden con el seed.

## 3. Conteos verificados después del seed

| Tabla | Esperado | Verificado |
| --- | --- | --- |
| `usuarios` | 13 | 13 |
| `alumnos` | 6 | 6 |
| `profesores` | 6 | 6 |
| `cursos` | 6 | 6 |
| `materias` | 8 | 8 |
| `asignaciones` | 17 | 17 |
| `inscripciones` | 6 | 6 |
| `calificaciones` | 9 | 9 |
| `asistencias` | 5 | 5 |
| `actividades` | 5 | 5 |
| `entregas_actividades` | 1 | 1 |
| `avisos` | 4 | 4 |

Consultas de verificación usadas:

```sql
select 'usuarios' as tabla, count(*) from public.usuarios
union all select 'alumnos', count(*) from public.alumnos
union all select 'profesores', count(*) from public.profesores
union all select 'cursos', count(*) from public.cursos
union all select 'materias', count(*) from public.materias
union all select 'asignaciones', count(*) from public.asignaciones
union all select 'inscripciones', count(*) from public.inscripciones
union all select 'calificaciones', count(*) from public.calificaciones
union all select 'asistencias', count(*) from public.asistencias
union all select 'actividades', count(*) from public.actividades
union all select 'entregas_actividades', count(*) from public.entregas_actividades
union all select 'avisos', count(*) from public.avisos;

select relname, relrowsecurity
from pg_class
where relnamespace = 'public'::regnamespace and relkind = 'r'
order by relname;

select count(*) from pg_policies where schemaname = 'public';
```

## 4. Pruebas de UI ejecutadas

Recorrido realizado el 2026-11-07 en el navegador integrado sobre el servidor Vite `http://127.0.0.1:5173`, con las tres cuentas demo.

| ID | Pantalla / flujo | Resultado observado | Estado |
| --- | --- | --- | --- |
| UI1 | Login admin → `/app` | Panel de administración con datos reales: 6 alumnos, 6 cursos, 6 profesores y 4 avisos. Sin errores de consola. | **Aprobada** |
| UI2 | Login alumno → `/app` | 6 materias, promedio 8,5, asistencia 100 % y 3 actividades pendientes. Sin errores de consola. | **Aprobada** |
| UI3 | Login profesor → `/app` | 3 cursos, 4 alumnos, 3 actividades vigentes y 4 avisos visibles. Sin errores de consola. | **Aprobada** |
| UI4 | Alumno → `/app/avisos` | 4 avisos publicados, con autor, curso o “Toda la comunidad” y fecha. Sin errores. | **Aprobada** |
| UI5 | Alumno → `/app/mis-calificaciones` | 4 calificaciones, 3 materias con nota y promedio 8,5. | **Aprobada** |
| UI6 | Alumno → `/app/usuarios` | Redirección a `/sin-permiso` con el mensaje de acceso restringido. | **Aprobada** |
| UI7 | Profesor → `/app/asistencia` | 3 cursos y 2 estudiantes en 3.º A. Se marcó “Presente” a ambos y se guardó: 2 filas creadas en `asistencias`; se eliminaron después y el conteo volvió a 5. | **Aprobada** |
| UI8 | Profesor → `/app/calificaciones` | 5 registros con sus notas visibles. Se editó 9 → 8,5: “1 calificación actualizada” y cambio confirmado en la base; luego se restauró a 9. | **Aprobada** |
| UI9 | Profesor → `/app/actividades` | 3 actividades de Matemática con curso, entrega y cantidad de entregas. | **Aprobada** |
| UI10 | Alumno → `/app/mis-actividades` | 4 actividades (1 entregada y 3 pendientes). “Marcar entregada” creó la fila en `entregas_actividades` y la tarjeta pasó a “Entregada”; la fila de prueba se eliminó después. | **Aprobada** |
| UI11 | Admin → `/app/alumnos` y `/app/usuarios` | 6 estudiantes encontrados (paginado 1–5 de 6) y 13 usuarios registrados. Sin errores. | **Aprobada** |

### Corrección encontrada durante las pruebas

En `/app/calificaciones` (docente) la nota vigente se mostraba solo como `placeholder` del campo editable. Se veía gris y el valor real del `input` quedaba vacío. Se corrigió `src/views/GradesView.vue` para inicializar cada borrador con la nota actual y guardar únicamente las filas cuyo valor cambió. Después del cambio, las notas se ven como valores reales y la edición 9 → 8,5 → 9 funcionó sin tocar las demás filas.

### Pruebas de UI que quedan pendientes

| Paso | Acción | Resultado esperado |
| --- | --- | --- |
| 1 | Login con contraseña incorrecta | Mensaje “Correo o contraseña incorrectos”, sin sesión. |
| 2 | `/recuperar` con un correo seed y apertura del enlace | Redirección a `/restablecer` y cambio de contraseña. Requiere configurar Redirect URL y un buzón real. |
| 3 | Desactivar una cuenta como admin e intentar ingresar | Sesión rechazada o cerrada con “Tu cuenta está desactivada”. |
| 4 | Crear un alumno con DNI y correo nuevos | Se crea la cuenta Auth, el usuario, el perfil y la inscripción. |
| 5 | Repetir el alta con el mismo DNI | Error de DNI duplicado. |
| 6 | Editar el curso de un alumno | Se finaliza la inscripción anterior y se crea la nueva. |
| 7 | Dar de baja lógica a un alumno | Usuario, alumno e inscripción quedan inactivos/finalizados. |
| 8 | Crear, editar y eliminar un curso | Los cambios persisten. |
| 9 | Crear y eliminar una asignación docente–materia–curso | Se crea la materia si no existe; la baja con historial se rechaza. |
| 10 | Publicar un aviso institucional y uno por curso | Cada rol ve lo que corresponde. |
| 11 | Exportar el listado de alumnos a CSV | Se descarga `alumnos-colegiogest.csv`. |

## 5. Resultado general

| Área | Estado |
| --- | --- |
| Compilación y empaquetado | ✅ Verificado |
| Eliminación de mocks | ✅ Verificado |
| Esquema, claves, restricciones e índices | ✅ Aplicado y verificado |
| Seed y cuentas demo | ✅ Aplicado y verificado |
| Login de los tres roles | ✅ Verificado por API y por UI |
| RLS de lectura por rol | ✅ Verificado por API |
| RLS de escritura y triggers | ✅ Verificado por API |
| Aislamiento del rol `anon` | ✅ Verificado |
| Flujos principales de UI (avisos, notas, asistencia, actividades y guardas) | ✅ Verificado en navegador |
| Documentación | ✅ Verificada |
| DER | ⏳ Elaboración manual pendiente |
| Alta/edición/baja de alumnos, cursos y asignaciones desde la UI | ⏳ Pendiente |
| Envío real de correo de recuperación | ⏳ Pendiente de configurar Redirect URL/SMTP |
