-- ============================================================================
-- ColegioGest · Etapa 6 (completado)
-- Migración 008: gestión de materias y edición de asignaciones
-- ============================================================================
-- Se mantiene el patrón de las RPC administrativas:
--   * La validación real ocurre en PostgreSQL (no en el cliente).
--   * Los errores se identifican con códigos legibles que el frontend traduce.
--   * La eliminación de materias queda bloqueada si tienen historial académico.
--   * La edición de una asignación no permite cambiar el docente cuando ya
--     existen calificaciones, asistencias o actividades que dependen de él.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- RPC: alta de materia en el catálogo.
-- ---------------------------------------------------------------------------
create or replace function public.admin_crear_materia(
  p_nombre text,
  p_descripcion text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_nombre text := btrim(coalesce(p_nombre, ''));
  v_id     uuid;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador puede gestionar materias.' using errcode = '42501';
  end if;
  if v_nombre = '' then
    raise exception 'El nombre de la materia es obligatorio.' using errcode = '22023';
  end if;
  if length(v_nombre) > 120 then
    raise exception 'El nombre de la materia no puede superar los 120 caracteres.' using errcode = '22023';
  end if;
  if exists (select 1 from public.materias where lower(nombre) = lower(v_nombre)) then
    raise exception 'DUPLICATE_MATERIA' using errcode = '23505';
  end if;

  insert into public.materias (nombre, descripcion)
  values (v_nombre, nullif(btrim(coalesce(p_descripcion, '')), ''))
  returning id into v_id;

  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: edición de materia.
-- ---------------------------------------------------------------------------
create or replace function public.admin_actualizar_materia(
  p_materia_id uuid,
  p_nombre text,
  p_descripcion text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_nombre text := btrim(coalesce(p_nombre, ''));
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador puede gestionar materias.' using errcode = '42501';
  end if;
  if not exists (select 1 from public.materias where id = p_materia_id) then
    raise exception 'MATERIA_NO_ENCONTRADA' using errcode = 'P0002';
  end if;
  if v_nombre = '' then
    raise exception 'El nombre de la materia es obligatorio.' using errcode = '22023';
  end if;
  if length(v_nombre) > 120 then
    raise exception 'El nombre de la materia no puede superar los 120 caracteres.' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.materias
    where lower(nombre) = lower(v_nombre) and id <> p_materia_id
  ) then
    raise exception 'DUPLICATE_MATERIA' using errcode = '23505';
  end if;

  update public.materias
     set nombre = v_nombre,
         descripcion = nullif(btrim(coalesce(p_descripcion, '')), '')
   where id = p_materia_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: baja de materia.
-- Se bloquea si la materia participa en asignaciones o tiene historial
-- académico. Así no se rompen calificaciones, asistencias ni actividades.
-- ---------------------------------------------------------------------------
create or replace function public.admin_eliminar_materia(p_materia_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador puede gestionar materias.' using errcode = '42501';
  end if;
  if not exists (select 1 from public.materias where id = p_materia_id) then
    raise exception 'MATERIA_NO_ENCONTRADA' using errcode = 'P0002';
  end if;

  if exists (select 1 from public.asignaciones where id_materia = p_materia_id) then
    raise exception 'MATERIA_CON_ASIGNACIONES' using errcode = '23503';
  end if;
  if exists (select 1 from public.calificaciones where id_materia = p_materia_id) then
    raise exception 'MATERIA_CON_CALIFICACIONES' using errcode = '23503';
  end if;
  if exists (select 1 from public.asistencias where id_materia = p_materia_id) then
    raise exception 'MATERIA_CON_ASISTENCIAS' using errcode = '23503';
  end if;
  if exists (select 1 from public.actividades where id_materia = p_materia_id) then
    raise exception 'MATERIA_CON_ACTIVIDADES' using errcode = '23503';
  end if;

  delete from public.materias where id = p_materia_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: edición de asignación (docente y ciclo lectivo).
-- El curso y la materia no se modifican: si se necesitan distintos, se crea
-- una asignación nueva y se elimina la anterior.
-- ---------------------------------------------------------------------------
create or replace function public.admin_actualizar_asignacion(
  p_asignacion_id uuid,
  p_profesor_id uuid,
  p_anio_lectivo smallint
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_asig public.asignaciones%rowtype;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador puede gestionar asignaciones.' using errcode = '42501';
  end if;

  select * into v_asig from public.asignaciones where id = p_asignacion_id;
  if v_asig.id is null then
    raise exception 'ASIGNACION_NO_ENCONTRADA' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.profesores where id = p_profesor_id) then
    raise exception 'PROFESOR_NO_ENCONTRADO' using errcode = 'P0002';
  end if;
  if p_anio_lectivo is null or p_anio_lectivo not between 2000 and 2100 then
    raise exception 'El ciclo lectivo debe estar entre 2000 y 2100.' using errcode = '22023';
  end if;

  if p_profesor_id is distinct from v_asig.id_profesor and (
    exists (
      select 1 from public.calificaciones c
      where c.id_materia = v_asig.id_materia
        and c.id_profesor = v_asig.id_profesor
    )
    or exists (
      select 1 from public.asistencias a
      where a.id_materia = v_asig.id_materia
        and a.id_curso = v_asig.id_curso
        and a.id_profesor = v_asig.id_profesor
    )
    or exists (
      select 1 from public.actividades ac
      where ac.id_materia = v_asig.id_materia
        and ac.id_curso = v_asig.id_curso
        and ac.id_profesor = v_asig.id_profesor
    )
  ) then
    raise exception 'ASIGNACION_CON_HISTORIAL' using errcode = '23503';
  end if;

  begin
    update public.asignaciones
       set id_profesor = p_profesor_id,
           anio_lectivo = p_anio_lectivo
     where id = p_asignacion_id;
  exception
    when unique_violation then
      raise exception 'ASIGNACION_DUPLICADA' using errcode = '23505';
  end;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: alta de asignación.
-- Se reemplaza la versión de la migración 003 para que un duplicado exacto
-- devuelva un error legible en lugar de reutilizar silenciosamente la fila.
-- ---------------------------------------------------------------------------
create or replace function public.admin_crear_asignacion(
  p_materia_nombre text,
  p_curso_id uuid,
  p_profesor_id uuid,
  p_anio_lectivo smallint default extract(year from current_date)::smallint,
  p_descripcion text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_materia uuid;
  v_asignacion uuid;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador puede gestionar asignaciones.' using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(p_materia_nombre, '')), '') is null then
    raise exception 'El nombre de la materia es obligatorio.' using errcode = '22023';
  end if;
  if p_anio_lectivo is null or p_anio_lectivo not between 2000 and 2100 then
    raise exception 'El ciclo lectivo debe estar entre 2000 y 2100.' using errcode = '22023';
  end if;
  if not exists (select 1 from public.cursos where id = p_curso_id) then
    raise exception 'CURSO_NO_ENCONTRADO' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.profesores where id = p_profesor_id) then
    raise exception 'PROFESOR_NO_ENCONTRADO' using errcode = 'P0002';
  end if;

  select id into v_materia
  from public.materias
  where lower(nombre) = lower(btrim(p_materia_nombre))
  limit 1;

  if v_materia is null then
    insert into public.materias (nombre, descripcion)
    values (btrim(p_materia_nombre), nullif(btrim(coalesce(p_descripcion, '')), ''))
    returning id into v_materia;
  end if;

  if exists (
    select 1 from public.asignaciones
    where id_materia = v_materia
      and id_curso = p_curso_id
      and id_profesor = p_profesor_id
      and anio_lectivo = p_anio_lectivo
  ) then
    raise exception 'ASIGNACION_DUPLICADA' using errcode = '23505';
  end if;

  insert into public.asignaciones (id_materia, id_curso, id_profesor, anio_lectivo)
  values (v_materia, p_curso_id, p_profesor_id, p_anio_lectivo)
  returning id into v_asignacion;

  return v_asignacion;
end;
$$;

-- ---------------------------------------------------------------------------
-- Permisos: solo usuarios autenticados.
-- ---------------------------------------------------------------------------
revoke all on function public.admin_crear_materia(text, text) from public, anon;
revoke all on function public.admin_actualizar_materia(uuid, text, text) from public, anon;
revoke all on function public.admin_eliminar_materia(uuid) from public, anon;
revoke all on function public.admin_actualizar_asignacion(uuid, uuid, smallint) from public, anon;
revoke all on function public.admin_crear_asignacion(text, uuid, uuid, smallint, text) from public, anon;

grant execute on function public.admin_crear_materia(text, text) to authenticated;
grant execute on function public.admin_actualizar_materia(uuid, text, text) to authenticated;
grant execute on function public.admin_eliminar_materia(uuid) to authenticated;
grant execute on function public.admin_actualizar_asignacion(uuid, uuid, smallint) to authenticated;
grant execute on function public.admin_crear_asignacion(text, uuid, uuid, smallint, text) to authenticated;
