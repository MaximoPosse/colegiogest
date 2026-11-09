-- ============================================================================
-- ColegioGest · Etapa 6
-- Migración 005: vistas de lectura para la aplicación
-- ============================================================================
-- Todas las vistas usan security_invoker = true: las políticas RLS de las
-- tablas base se siguen aplicando con la identidad del usuario autenticado.
-- ============================================================================

drop view if exists public.v_alumnos cascade;
create view public.v_alumnos with (security_invoker = true) as
select
  a.id,
  a.id_usuario,
  u.nombre,
  u.apellido,
  u.dni,
  u.correo,
  u.estado as estado_usuario,
  a.estado,
  a.fecha_nacimiento,
  a.telefono,
  i.id as id_inscripcion,
  i.id_curso,
  i.fecha_inscripcion,
  i.estado as estado_inscripcion,
  c.anio,
  c.division,
  c.turno
from public.alumnos a
join public.usuarios u on u.id = a.id_usuario
left join public.inscripciones i on i.id_alumno = a.id and i.estado = 'activa'
left join public.cursos c on c.id = i.id_curso;

drop view if exists public.v_profesores cascade;
create view public.v_profesores with (security_invoker = true) as
select
  p.id,
  p.id_usuario,
  u.nombre,
  u.apellido,
  u.dni,
  u.correo,
  p.estado,
  u.estado as estado_usuario
from public.profesores p
join public.usuarios u on u.id = p.id_usuario;

drop view if exists public.v_cursos cascade;
create view public.v_cursos with (security_invoker = true) as
select
  c.id,
  c.anio,
  c.division,
  c.turno,
  public.contar_alumnos_curso(c.id) as students_count,
  c.created_at
from public.cursos c;

drop view if exists public.v_asignaciones cascade;
create view public.v_asignaciones with (security_invoker = true) as
select
  a.id,
  a.id_materia,
  m.nombre as materia,
  m.descripcion,
  a.id_curso,
  c.anio,
  c.division,
  c.turno,
  a.id_profesor,
  (up.nombre || ' ' || up.apellido) as profesor,
  up.correo as profesor_correo,
  a.anio_lectivo
from public.asignaciones a
join public.materias m on m.id = a.id_materia
join public.cursos c on c.id = a.id_curso
join public.profesores p on p.id = a.id_profesor
join public.usuarios up on up.id = p.id_usuario;

drop view if exists public.v_inscripciones cascade;
create view public.v_inscripciones with (security_invoker = true) as
select
  i.id,
  i.id_alumno,
  (u.nombre || ' ' || u.apellido) as alumno,
  u.dni,
  i.id_curso,
  c.anio,
  c.division,
  c.turno,
  i.fecha_inscripcion,
  i.estado
from public.inscripciones i
join public.alumnos a on a.id = i.id_alumno
join public.usuarios u on u.id = a.id_usuario
join public.cursos c on c.id = i.id_curso;

drop view if exists public.v_calificaciones cascade;
create view public.v_calificaciones with (security_invoker = true) as
select
  cal.id,
  cal.id_alumno,
  (u.nombre || ' ' || u.apellido) as alumno,
  u.dni as alumno_dni,
  cal.id_materia,
  m.nombre as materia,
  cal.id_profesor,
  (up.nombre || ' ' || up.apellido) as profesor,
  cal.tipo_instancia,
  cal.nota,
  cal.fecha,
  cal.observacion,
  i.id_curso,
  c.anio,
  c.division,
  c.turno
from public.calificaciones cal
join public.alumnos a on a.id = cal.id_alumno
join public.usuarios u on u.id = a.id_usuario
join public.materias m on m.id = cal.id_materia
join public.profesores p on p.id = cal.id_profesor
join public.usuarios up on up.id = p.id_usuario
left join lateral (
  select ins.id_curso
  from public.inscripciones ins
  where ins.id_alumno = cal.id_alumno and ins.estado = 'activa'
  limit 1
) i on true
left join public.cursos c on c.id = i.id_curso;

drop view if exists public.v_asistencias cascade;
create view public.v_asistencias with (security_invoker = true) as
select
  a.id,
  a.id_alumno,
  (u.nombre || ' ' || u.apellido) as alumno,
  u.dni as alumno_dni,
  a.id_curso,
  c.anio,
  c.division,
  c.turno,
  a.id_materia,
  m.nombre as materia,
  a.id_profesor,
  (up.nombre || ' ' || up.apellido) as profesor,
  a.fecha,
  a.estado,
  a.observacion
from public.asistencias a
join public.alumnos al on al.id = a.id_alumno
join public.usuarios u on u.id = al.id_usuario
join public.cursos c on c.id = a.id_curso
join public.materias m on m.id = a.id_materia
join public.profesores p on p.id = a.id_profesor
join public.usuarios up on up.id = p.id_usuario;

drop view if exists public.v_actividades cascade;
create view public.v_actividades with (security_invoker = true) as
select
  ac.id,
  ac.titulo,
  ac.descripcion,
  ac.fecha_entrega,
  ac.id_materia,
  m.nombre as materia,
  ac.id_curso,
  c.anio,
  c.division,
  c.turno,
  ac.id_profesor,
  (u.nombre || ' ' || u.apellido) as profesor,
  ac.fecha_publicacion
from public.actividades ac
join public.materias m on m.id = ac.id_materia
join public.cursos c on c.id = ac.id_curso
join public.profesores p on p.id = ac.id_profesor
join public.usuarios u on u.id = p.id_usuario;

drop view if exists public.v_entregas cascade;
create view public.v_entregas with (security_invoker = true) as
select
  e.id,
  e.id_actividad,
  ac.titulo as actividad,
  e.id_alumno,
  (u.nombre || ' ' || u.apellido) as alumno,
  e.estado,
  e.fecha_entrega,
  e.comentario
from public.entregas_actividades e
join public.actividades ac on ac.id = e.id_actividad
join public.alumnos a on a.id = e.id_alumno
join public.usuarios u on u.id = a.id_usuario;

drop view if exists public.v_avisos cascade;
create view public.v_avisos with (security_invoker = true) as
select
  av.id,
  av.titulo,
  av.contenido,
  av.categoria,
  av.fecha_publicacion,
  av.id_autor,
  (u.nombre || ' ' || u.apellido) as autor,
  av.id_curso_destino,
  c.anio,
  c.division,
  c.turno
from public.avisos av
join public.usuarios u on u.id = av.id_autor
left join public.cursos c on c.id = av.id_curso_destino;

-- ---------------------------------------------------------------------------
-- Permisos
-- ---------------------------------------------------------------------------
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant select on public.v_alumnos, public.v_profesores, public.v_cursos,
  public.v_asignaciones, public.v_inscripciones, public.v_calificaciones,
  public.v_asistencias, public.v_actividades, public.v_entregas, public.v_avisos
  to authenticated;

-- El rol anónimo no accede a datos escolares.
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke all on all functions in schema public from anon;

alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on sequences from anon;
alter default privileges in schema public revoke all on functions from anon;
