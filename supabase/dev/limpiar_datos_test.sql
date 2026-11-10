-- ============================================================================
-- ColegioGest · Script de limpieza para pruebas
-- ============================================================================
-- PROPÓSITO
--   Elimina todos los registros creados por las pruebas de integración para
--   poder volver a ejecutarlas sobre una base limpia, sin tocar los datos del
--   seed (admin@colegiogest.edu.ar, profesor@..., alumno@..., etc.).
--
-- QUÉ BORRA
--   * Cuentas cuya dirección de correo empiece con "test_" (Auth + usuarios).
--   * Filas cuyo texto identificatorio empiece con "TEST_":
--       - materias  (nombre o descripción)
--       - actividades (título o descripción)
--       - avisos    (título o contenido)
--   * Todo el dato dependiente de esas cuentas o filas: inscripciones,
--     calificaciones, asistencias, entregas, actividades, asignaciones.
--
-- CÓMO EJECUTARLO
--   SOLO desde el SQL Editor del dashboard de Supabase (rol postgres).
--   NUNCA desde el frontend o una clave de API: el script borra en auth.users.
--
-- ORDEN
--   Respeta el orden de dependencias de las FK (restrict o cascade):
--   entregas → calificaciones/asistencias → inscripciones → avisos →
--   actividades → asignaciones → materias → perfiles → usuarios → auth.users.
--
-- ES RE-EJECUTABLE: si no hay datos de prueba, no borra nada y avisa.
-- ============================================================================

do $$
declare
  -- Contadores para el resumen final.
  n_entregas      bigint := 0;
  n_calif         bigint := 0;
  n_asist         bigint := 0;
  n_ins           bigint := 0;
  n_avisos        bigint := 0;
  n_actividades   bigint := 0;
  n_asign         bigint := 0;
  n_materias      bigint := 0;
  n_alumnos       bigint := 0;
  n_profes        bigint := 0;
  n_usuarios      bigint := 0;
  n_auth          bigint := 0;
  n_total         bigint := 0;

  v_pasadas integer;
  r record;
begin
  -- --------------------------------------------------------------------------
  -- 0) Sanity check: no correr si no hay esquema (proyecto equivocado).
  -- --------------------------------------------------------------------------
  select count(*) into v_pasadas
  from information_schema.tables
  where table_schema = 'public' and table_name in ('usuarios', 'materias');
  if v_pasadas < 2 then
    raise exception 'El esquema de ColegioGest no existe en este proyecto. Revisá dónde lo ejecutás.';
  end if;

  -- --------------------------------------------------------------------------
  -- 1) Conjuntos temporales de datos de prueba.
  -- --------------------------------------------------------------------------
  create temp table _t_usuarios on commit drop as
    select id from public.usuarios
    where correo ilike 'test\_%' escape '\' or id in (
      select id from auth.users where email ilike 'test\_%' escape '\'
    );

  create temp table _t_alumnos on commit drop as
    select id from public.alumnos where id_usuario in (select id from _t_usuarios);

  create temp table _t_profes on commit drop as
    select id from public.profesores where id_usuario in (select id from _t_usuarios);

  create temp table _t_materias on commit drop as
    select id from public.materias
    where nombre ilike 'TEST\_%' escape '\'
       or coalesce(descripcion, '') ilike 'TEST\_%' escape '\';

  create temp table _t_actividades on commit drop as
    select id from public.actividades
    where titulo ilike 'TEST\_%' escape '\'
       or descripcion ilike 'TEST\_%' escape '\'
       or id_profesor in (select id from _t_profes)
       or id_materia in (select id from _t_materias);

  -- --------------------------------------------------------------------------
  -- 2) Borrado en orden de dependencias.
  -- --------------------------------------------------------------------------

  -- 2.1 Entregas de actividades (dependen de actividades y alumnos).
  delete from public.entregas_actividades e
    where e.id_alumno in (select id from _t_alumnos)
       or e.id_actividad in (select id from _t_actividades);
  get diagnostics n_entregas = row_count;

  -- 2.2 Calificaciones (dependen de alumnos, profesores y materias).
  delete from public.calificaciones c
    where c.id_alumno in (select id from _t_alumnos)
       or c.id_profesor in (select id from _t_profes)
       or c.id_materia in (select id from _t_materias);
  get diagnostics n_calif = row_count;

  -- 2.3 Asistencias (dependen de alumnos, profesores, cursos y materias).
  delete from public.asistencias a
    where a.id_alumno in (select id from _t_alumnos)
       or a.id_profesor in (select id from _t_profes)
       or a.id_materia in (select id from _t_materias);
  get diagnostics n_asist = row_count;

  -- 2.4 Inscripciones (historial: se borra por completo si el alumno es de prueba).
  delete from public.inscripciones i
    where i.id_alumno in (select id from _t_alumnos);
  get diagnostics n_ins = row_count;

  -- 2.5 Avisos (el autor es usuarios con FK restrict).
  delete from public.avisos av
    where av.id_autor in (select id from _t_usuarios)
       or av.titulo ilike 'TEST\_%' escape '\'
       or av.contenido ilike 'TEST\_%' escape '\';
  get diagnostics n_avisos = row_count;

  -- 2.6 Actividades (profesor y materia tienen FK restrict; las entregas van por cascade).
  delete from public.actividades ac
    where ac.id in (select id from _t_actividades)
       or ac.id_profesor in (select id from _t_profes)
       or ac.id_materia in (select id from _t_materias);
  get diagnostics n_actividades = row_count;

  -- 2.7 Asignaciones (profesor y materia tienen FK restrict).
  delete from public.asignaciones asg
    where asg.id_profesor in (select id from _t_profes)
       or asg.id_materia in (select id from _t_materias);
  get diagnostics n_asign = row_count;

  -- 2.8 Materias de prueba (ya sin dependientes).
  delete from public.materias m
    where m.id in (select id from _t_materias);
  get diagnostics n_materias = row_count;

  -- 2.9 Perfiles 1:1 (alumnos y profesores de prueba; el resto va por cascade
  --     al borrar usuarios, se listan igual para el resumen).
  delete from public.alumnos al
    where al.id_usuario in (select id from _t_usuarios);
  get diagnostics n_alumnos = row_count;

  delete from public.profesores pr
    where pr.id_usuario in (select id from _t_usuarios);
  get diagnostics n_profes = row_count;

  -- 2.10 Usuarios de prueba (public.usuarios).
  delete from public.usuarios u
    where u.id in (select id from _t_usuarios);
  get diagnostics n_usuarios = row_count;

  -- 2.11 Cuentas de Auth (cascada a identities, sessions y refresh tokens).
  for r in
    select id from auth.users where email ilike 'test\_%' escape '\'
  loop
    delete from auth.users where id = r.id;
    n_auth := n_auth + 1;
  end loop;

  -- --------------------------------------------------------------------------
  -- 3) Resumen.
  -- --------------------------------------------------------------------------
  n_total := n_entregas + n_calif + n_asist + n_ins + n_avisos
           + n_actividades + n_asign + n_materias + n_alumnos + n_profes
           + n_usuarios + n_auth;

  raise notice '──────────────── Limpieza de datos de prueba ────────────────';
  raise notice 'entregas_actividades ....... %', n_entregas;
  raise notice 'calificaciones ............. %', n_calif;
  raise notice 'asistencias ................ %', n_asist;
  raise notice 'inscripciones .............. %', n_ins;
  raise notice 'avisos ..................... %', n_avisos;
  raise notice 'actividades ................ %', n_actividades;
  raise notice 'asignaciones ............... %', n_asign;
  raise notice 'materias ................... %', n_materias;
  raise notice 'alumnos .................... %', n_alumnos;
  raise notice 'profesores ................. %', n_profes;
  raise notice 'usuarios ................... %', n_usuarios;
  raise notice 'auth.users (cuentas) ....... %', n_auth;
  raise notice '─────────────────────────────────────────────────────────────';
  if n_total = 0 then
    raise notice 'No se encontraron datos de prueba: la base ya está limpia.';
  else
    raise notice 'Total de registros eliminados: %', n_total;
  end if;
end;
$$;

-- --------------------------------------------------------------------------
-- Verificación posterior (opcional): ejecutar en otra pestaña del SQL Editor.
--
-- select count(*) as usuarios_test from public.usuarios
--   where correo ilike 'test\_%' escape '\';
-- select count(*) as auth_test from auth.users
--   where email ilike 'test\_%' escape '\';
-- select count(*) as materias_test from public.materias
--   where nombre ilike 'TEST\_%' escape '\';
-- --------------------------------------------------------------------------

-- Nota: el seed (setup_completo.sql) no se ve afectado porque ninguna cuenta
-- del seed usa un correo test_* ni textos TEST_*; los UUID fijos del seed
-- (11111111-..., 22222222-..., etc.) solo se eliminan si su correo también
-- empieza con "test_", cosa que no ocurre con los datos precargados.
