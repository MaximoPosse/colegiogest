-- ============================================================================
-- ColegioGest · Hardening de seguridad e integridad
-- Migración 009
-- ============================================================================

-- Los perfiles solo pueden ser actualizados por administradores y nunca por
-- el propio usuario. El trigger añade una segunda defensa para campos sensibles.
drop policy if exists usuarios_update on public.usuarios;
create policy usuarios_update on public.usuarios
for update to authenticated
using (
  public.cuenta_activa()
  and public.es_admin()
  and id <> auth.uid()
)
with check (
  public.cuenta_activa()
  and public.es_admin()
  and id <> auth.uid()
);

create or replace function public.proteger_campos_usuario()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is not null and auth.uid() = old.id and (
    new.nombre is distinct from old.nombre
    or new.apellido is distinct from old.apellido
    or new.dni is distinct from old.dni
    or new.correo is distinct from old.correo
    or new.rol is distinct from old.rol
    or new.estado is distinct from old.estado
  ) then
    raise exception 'No podés modificar los datos de tu propia cuenta.'
      using errcode = '42501';
  end if;

  if auth.uid() is not null and not public.es_admin() and (
    new.nombre is distinct from old.nombre
    or new.apellido is distinct from old.apellido
    or new.dni is distinct from old.dni
    or new.correo is distinct from old.correo
    or new.rol is distinct from old.rol
    or new.estado is distinct from old.estado
  ) then
    raise exception 'No tenés permisos para modificar este perfil.'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

-- Desactivar un usuario por la pantalla general debe respetar las mismas
-- asignaciones vigentes que la baja específica de profesores.
create or replace function public.admin_cambiar_estado_usuario(
  p_usuario_id uuid,
  p_estado public.estado_cuenta
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador puede cambiar el estado de una cuenta.' using errcode = '42501';
  end if;
  if p_usuario_id = auth.uid() then
    raise exception 'No podés cambiar el estado de tu propia cuenta.' using errcode = '42501';
  end if;

  if p_estado = 'inactivo' and exists (
    select 1
    from public.profesores p
    join public.asignaciones a on a.id_profesor = p.id
    where p.id_usuario = p_usuario_id
      and a.anio_lectivo >= extract(year from current_date)::smallint
  ) then
    raise exception 'PROFESOR_CON_ASIGNACIONES' using errcode = '23514';
  end if;

  update public.usuarios set estado = p_estado where id = p_usuario_id;
  update public.alumnos set estado = p_estado where id_usuario = p_usuario_id;
  update public.profesores set estado = p_estado where id_usuario = p_usuario_id;

  if p_estado = 'inactivo' then
    update public.inscripciones i
       set estado = 'finalizada'
     where i.estado = 'activa'
       and i.id_alumno in (
         select a.id from public.alumnos a where a.id_usuario = p_usuario_id
       );
  end if;
end;
$$;

-- Se renombran las implementaciones heredadas, se les quita el acceso desde
-- PostgREST y se exponen wrappers sin contraseña predeterminada. Las funciones
-- internas mantienen las validaciones y la creación transaccional existentes.
do $$
begin
  if to_regprocedure('public.admin_crear_alumno_internal(text,text,text,text,uuid,text,date,text)') is null
     and to_regprocedure('public.admin_crear_alumno(text,text,text,text,uuid,text,date,text)') is not null then
    execute 'alter function public.admin_crear_alumno(text,text,text,text,uuid,text,date,text) rename to admin_crear_alumno_internal';
  end if;

  if to_regprocedure('public.admin_crear_profesor_internal(text,text,text,text,text)') is null
     and to_regprocedure('public.admin_crear_profesor(text,text,text,text,text)') is not null then
    execute 'alter function public.admin_crear_profesor(text,text,text,text,text) rename to admin_crear_profesor_internal';
  end if;
end;
$$;

revoke all on function public.admin_crear_alumno_internal(text,text,text,text,uuid,text,date,text)
  from public, anon, authenticated;
revoke all on function public.admin_crear_profesor_internal(text,text,text,text,text)
  from public, anon, authenticated;

create or replace function public.admin_crear_alumno(
  p_nombre text,
  p_apellido text,
  p_dni text,
  p_correo text,
  p_id_curso uuid,
  p_password text,
  p_fecha_nacimiento date,
  p_telefono text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_password is null or length(p_password) < 6 then
    raise exception 'La contraseña inicial debe tener al menos 6 caracteres.' using errcode = '22023';
  end if;

  return public.admin_crear_alumno_internal(
    p_nombre, p_apellido, p_dni, p_correo, p_id_curso,
    p_password, p_fecha_nacimiento, p_telefono
  );
end;
$$;

create or replace function public.admin_crear_profesor(
  p_nombre text,
  p_apellido text,
  p_dni text,
  p_correo text,
  p_password text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_password is null or length(p_password) < 6 then
    raise exception 'La contraseña inicial debe tener al menos 6 caracteres.' using errcode = '22023';
  end if;

  return public.admin_crear_profesor_internal(
    p_nombre, p_apellido, p_dni, p_correo, p_password
  );
end;
$$;

revoke all on function public.admin_crear_alumno(text,text,text,text,uuid,text,date,text) from public, anon;
revoke all on function public.admin_crear_profesor(text,text,text,text,text) from public, anon;
grant execute on function public.admin_crear_alumno(text,text,text,text,uuid,text,date,text) to authenticated;
grant execute on function public.admin_crear_profesor(text,text,text,text,text) to authenticated;

create or replace function public.validar_calificacion()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.fecha > (now() at time zone 'America/Argentina/Buenos_Aires')::date then
    raise exception 'No se pueden registrar calificaciones con fecha futura.'
      using errcode = '23514';
  end if;

  if not exists (
    select 1
    from public.inscripciones i
    join public.asignaciones a
      on a.id_curso = i.id_curso
     and a.id_materia = new.id_materia
     and a.id_profesor = new.id_profesor
    where i.id_alumno = new.id_alumno
      and i.estado = 'activa'
  ) then
    raise exception 'La calificación debe corresponder a un alumno inscripto y a una asignación vigente del docente.'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create or replace function public.validar_asistencia()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.fecha > (now() at time zone 'America/Argentina/Buenos_Aires')::date then
    raise exception 'No se puede registrar asistencia con fecha futura.'
      using errcode = '23514';
  end if;

  if not exists (
    select 1
    from public.inscripciones i
    join public.asignaciones a
      on a.id_curso = i.id_curso
     and a.id_materia = new.id_materia
     and a.id_profesor = new.id_profesor
    where i.id_alumno = new.id_alumno
      and i.id_curso = new.id_curso
      and i.estado = 'activa'
  ) then
    raise exception 'La asistencia debe corresponder a un alumno inscripto y a una asignación vigente del docente.'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

notify pgrst, 'reload schema';
