-- ============================================================================
-- ColegioGest · Etapa 6
-- Migración 003: funciones de seguridad, triggers y RPC administrativas
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Helpers de identidad y permisos.
-- Todas las funciones son SECURITY DEFINER para evitar recursión de RLS y
-- porque solo devuelven booleanos / identificadores del propio usuario.
-- ---------------------------------------------------------------------------
create or replace function public.rol_actual()
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select u.rol::text
  from public.usuarios u
  where u.id = auth.uid()
    and u.estado = 'activo';
$$;

create or replace function public.cuenta_activa()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.usuarios u
    where u.id = auth.uid() and u.estado = 'activo'
  );
$$;

create or replace function public.es_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(public.rol_actual() = 'administrador', false);
$$;

create or replace function public.es_profesor()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(public.rol_actual() = 'profesor', false);
$$;

create or replace function public.es_alumno()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(public.rol_actual() = 'alumno', false);
$$;

create or replace function public.mi_alumno_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select a.id from public.alumnos a where a.id_usuario = auth.uid();
$$;

create or replace function public.mi_profesor_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.id from public.profesores p where p.id_usuario = auth.uid();
$$;

create or replace function public.mi_curso_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select i.id_curso
  from public.inscripciones i
  join public.alumnos a on a.id = i.id_alumno
  where a.id_usuario = auth.uid()
    and i.estado = 'activa'
  limit 1;
$$;

create or replace function public.curso_de_alumno(p_alumno uuid)
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select i.id_curso
  from public.inscripciones i
  where i.id_alumno = p_alumno
    and i.estado = 'activa'
  limit 1;
$$;

create or replace function public.profesor_dicta(p_materia uuid, p_curso uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.asignaciones a
    join public.profesores p on p.id = a.id_profesor
    where a.id_materia = p_materia
      and a.id_curso = p_curso
      and p.id_usuario = auth.uid()
  );
$$;

create or replace function public.profesor_puede_ver_curso(p_curso uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.asignaciones a
    join public.profesores p on p.id = a.id_profesor
    where a.id_curso = p_curso
      and p.id_usuario = auth.uid()
  );
$$;

create or replace function public.profesor_puede_ver_alumno(p_alumno uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.inscripciones i
    join public.asignaciones a on a.id_curso = i.id_curso
    join public.profesores p on p.id = a.id_profesor
    where i.id_alumno = p_alumno
      and i.estado = 'activa'
      and p.id_usuario = auth.uid()
  );
$$;

create or replace function public.profesor_puede_ver_usuario(p_usuario uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.alumnos a
    where a.id_usuario = p_usuario
      and public.profesor_puede_ver_alumno(a.id)
  );
$$;

create or replace function public.alumno_puede_ver_profesor(p_profesor uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.asignaciones a
    join public.inscripciones i on i.id_curso = a.id_curso
    join public.alumnos al on al.id = i.id_alumno
    where a.id_profesor = p_profesor
      and i.estado = 'activa'
      and al.id_usuario = auth.uid()
  );
$$;

create or replace function public.alumno_puede_ver_materia(p_materia uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.asignaciones a
    join public.inscripciones i on i.id_curso = a.id_curso
    join public.alumnos al on al.id = i.id_alumno
    where a.id_materia = p_materia
      and i.estado = 'activa'
      and al.id_usuario = auth.uid()
  );
$$;

create or replace function public.profesor_puede_ver_materia(p_materia uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.asignaciones a
    join public.profesores p on p.id = a.id_profesor
    where a.id_materia = p_materia
      and p.id_usuario = auth.uid()
  );
$$;

create or replace function public.profesor_es_autor_actividad(p_actividad uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.actividades a
    join public.profesores p on p.id = a.id_profesor
    where a.id = p_actividad
      and p.id_usuario = auth.uid()
  );
$$;

create or replace function public.contar_alumnos_curso(p_curso uuid)
returns bigint
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select count(*)
  from public.inscripciones i
  where i.id_curso = p_curso
    and i.estado = 'activa';
$$;

-- ---------------------------------------------------------------------------
-- Trigger genérico updated_at.
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'usuarios', 'alumnos', 'profesores', 'cursos', 'materias',
    'asignaciones', 'inscripciones', 'calificaciones', 'asistencias',
    'actividades', 'entregas_actividades', 'avisos'
  ]
  loop
    execute format('drop trigger if exists set_%s_updated_at on public.%I', t, t);
    execute format(
      'create trigger set_%s_updated_at before update on public.%I
       for each row execute function public.set_updated_at()',
      t, t
    );
  end loop;
end
$$;

-- ---------------------------------------------------------------------------
-- Alta automática del perfil público al crear un usuario en auth.users.
-- Si el alta no trae metadatos completos (nombre, apellido, dni) no se crea el
-- perfil: la aplicación rechazará el acceso hasta que un administrador lo cree.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_nombre   text;
  v_apellido text;
  v_dni      text;
  v_rol      public.rol_usuario;
begin
  v_nombre   := nullif(btrim(coalesce(new.raw_user_meta_data ->> 'nombre', '')), '');
  v_apellido := nullif(btrim(coalesce(new.raw_user_meta_data ->> 'apellido', '')), '');
  v_dni      := regexp_replace(coalesce(new.raw_user_meta_data ->> 'dni', ''), '\D', '', 'g');

  if v_nombre is null or v_apellido is null or v_dni = '' or new.email is null then
    return new;
  end if;

  v_rol := case
    when new.raw_user_meta_data ->> 'rol' = 'administrador' then 'administrador'::public.rol_usuario
    when new.raw_user_meta_data ->> 'rol' = 'profesor' then 'profesor'::public.rol_usuario
    else 'alumno'::public.rol_usuario
  end;

  insert into public.usuarios (id, nombre, apellido, dni, correo, rol, estado, fecha_alta)
  values (new.id, v_nombre, v_apellido, v_dni, lower(new.email), v_rol, 'activo', coalesce(new.created_at, now()))
  on conflict (id) do nothing;

  if v_rol = 'alumno' then
    insert into public.alumnos (id_usuario) values (new.id)
    on conflict (id_usuario) do nothing;
  elsif v_rol = 'profesor' then
    insert into public.profesores (id_usuario) values (new.id)
    on conflict (id_usuario) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Bloqueo de escalada de privilegios desde la API.
-- Un usuario autenticado no puede cambiar su propio rol ni su estado; un
-- administrador sí puede hacerlo sobre otras cuentas.
-- ---------------------------------------------------------------------------
create or replace function public.proteger_campos_usuario()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is not null and not public.es_admin() then
    if new.rol is distinct from old.rol or new.estado is distinct from old.estado then
      raise exception 'No tenés permiso para modificar el rol o el estado de la cuenta.'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists proteger_campos_usuario_trg on public.usuarios;
create trigger proteger_campos_usuario_trg
  before update on public.usuarios
  for each row execute function public.proteger_campos_usuario();

-- ---------------------------------------------------------------------------
-- Reglas de integridad académica.
-- ---------------------------------------------------------------------------
create or replace function public.validar_calificacion()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
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

drop trigger if exists validar_calificacion_trg on public.calificaciones;
create trigger validar_calificacion_trg
  before insert or update on public.calificaciones
  for each row execute function public.validar_calificacion();

create or replace function public.validar_asistencia()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
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

drop trigger if exists validar_asistencia_trg on public.asistencias;
create trigger validar_asistencia_trg
  before insert or update on public.asistencias
  for each row execute function public.validar_asistencia();

create or replace function public.validar_actividad()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1 from public.asignaciones a
    where a.id_materia = new.id_materia
      and a.id_curso = new.id_curso
      and a.id_profesor = new.id_profesor
  ) then
    raise exception 'La actividad debe estar asociada a una asignación vigente del docente.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists validar_actividad_trg on public.actividades;
create trigger validar_actividad_trg
  before insert or update on public.actividades
  for each row execute function public.validar_actividad();

create or replace function public.validar_entrega()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1
    from public.actividades a
    join public.inscripciones i
      on i.id_curso = a.id_curso
    where a.id = new.id_actividad
      and i.id_alumno = new.id_alumno
      and i.estado = 'activa'
  ) then
    raise exception 'El alumno no está inscripto en el curso de la actividad.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists validar_entrega_trg on public.entregas_actividades;
create trigger validar_entrega_trg
  before insert or update on public.entregas_actividades
  for each row execute function public.validar_entrega();

create or replace function public.validar_inscripcion()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.estado = 'activa' and not exists (
    select 1 from public.alumnos a
    where a.id = new.id_alumno and a.estado = 'activo'
  ) then
    raise exception 'No se puede inscribir a un alumno inactivo.' using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists validar_inscripcion_trg on public.inscripciones;
create trigger validar_inscripcion_trg
  before insert or update on public.inscripciones
  for each row execute function public.validar_inscripcion();

-- ---------------------------------------------------------------------------
-- RPC: alta de alumno (crea auth.users + usuarios + alumnos + inscripción).
-- Se usa desde el panel de administración para no exponer la service_role key.
-- ---------------------------------------------------------------------------
create or replace function public.admin_crear_alumno(
  p_nombre text,
  p_apellido text,
  p_dni text,
  p_correo text,
  p_id_curso uuid default null,
  p_password text default 'demo123',
  p_fecha_nacimiento date default null,
  p_telefono text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, auth, extensions, pg_temp
as $$
declare
  v_user_id  uuid := gen_random_uuid();
  v_dni      text := regexp_replace(coalesce(p_dni, ''), '\D', '', 'g');
  v_correo   text := lower(btrim(coalesce(p_correo, '')));
  v_alumno   uuid;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador puede crear alumnos.' using errcode = '42501';
  end if;
  if length(v_dni) not between 7 and 9 then
    raise exception 'El DNI debe tener entre 7 y 9 dígitos.' using errcode = '22023';
  end if;
  if v_correo !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'El correo electrónico no es válido.' using errcode = '22023';
  end if;
  if p_password is null or length(p_password) < 6 then
    raise exception 'La contraseña inicial debe tener al menos 6 caracteres.' using errcode = '22023';
  end if;
  if exists (select 1 from public.usuarios where dni = v_dni) then
    raise exception 'DUPLICATE_DNI' using errcode = '23505';
  end if;
  if exists (select 1 from public.usuarios where lower(correo) = v_correo) then
    raise exception 'DUPLICATE_EMAIL' using errcode = '23505';
  end if;

  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    v_user_id,
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    v_correo,
    extensions.crypt(p_password, extensions.gen_salt('bf')),
    now(),
    jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
    jsonb_build_object('nombre', btrim(p_nombre), 'apellido', btrim(p_apellido), 'dni', v_dni, 'rol', 'alumno'),
    now(), now(), '', '', '', ''
  );

  insert into auth.identities (user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
  values (
    v_user_id,
    jsonb_build_object('sub', v_user_id::text, 'email', v_correo, 'email_verified', true),
    'email',
    v_user_id::text,
    now(), now(), now()
  )
  on conflict do nothing;

  select id into v_alumno from public.alumnos where id_usuario = v_user_id;
  if v_alumno is null then
    insert into public.alumnos (id_usuario) values (v_user_id) returning id into v_alumno;
  end if;

  update public.alumnos
     set fecha_nacimiento = p_fecha_nacimiento,
         telefono = nullif(btrim(coalesce(p_telefono, '')), '')
   where id = v_alumno;

  if p_id_curso is not null then
    insert into public.inscripciones (id_alumno, id_curso, estado, fecha_inscripcion)
    values (v_alumno, p_id_curso, 'activa', current_date);
  end if;

  return v_alumno;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: actualización de alumno y sincronización con auth.users.
-- ---------------------------------------------------------------------------
create or replace function public.admin_actualizar_alumno(
  p_alumno_id uuid,
  p_nombre text,
  p_apellido text,
  p_dni text,
  p_correo text,
  p_estado public.estado_cuenta,
  p_id_curso uuid default null,
  p_fecha_nacimiento date default null,
  p_telefono text default null
)
returns void
language plpgsql
security definer
set search_path = public, auth, extensions, pg_temp
as $$
declare
  v_usuario_id uuid;
  v_curso_actual uuid;
  v_dni text := regexp_replace(coalesce(p_dni, ''), '\D', '', 'g');
  v_correo text := lower(btrim(coalesce(p_correo, '')));
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador puede modificar alumnos.' using errcode = '42501';
  end if;

  select id_usuario into v_usuario_id from public.alumnos where id = p_alumno_id;
  if v_usuario_id is null then
    raise exception 'ALUMNO_NO_ENCONTRADO' using errcode = 'P0002';
  end if;
  if length(v_dni) not between 7 and 9 then
    raise exception 'El DNI debe tener entre 7 y 9 dígitos.' using errcode = '22023';
  end if;
  if v_correo !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'El correo electrónico no es válido.' using errcode = '22023';
  end if;
  if exists (select 1 from public.usuarios where dni = v_dni and id <> v_usuario_id) then
    raise exception 'DUPLICATE_DNI' using errcode = '23505';
  end if;
  if exists (select 1 from public.usuarios where lower(correo) = v_correo and id <> v_usuario_id) then
    raise exception 'DUPLICATE_EMAIL' using errcode = '23505';
  end if;

  update public.usuarios
     set nombre = btrim(p_nombre),
         apellido = btrim(p_apellido),
         dni = v_dni,
         correo = v_correo,
         estado = p_estado
   where id = v_usuario_id;

  update auth.users
     set email = v_correo,
         updated_at = now()
   where id = v_usuario_id;

  update auth.identities
     set identity_data = jsonb_set(identity_data, '{email}', to_jsonb(v_correo), true),
         updated_at = now()
   where user_id = v_usuario_id and provider = 'email';

  update public.alumnos
     set estado = p_estado,
         fecha_nacimiento = p_fecha_nacimiento,
         telefono = nullif(btrim(coalesce(p_telefono, '')), '')
   where id = p_alumno_id;

  select id_curso into v_curso_actual
  from public.inscripciones
  where id_alumno = p_alumno_id and estado = 'activa'
  limit 1;

  if p_estado = 'inactivo' then
    update public.inscripciones
       set estado = 'finalizada'
     where id_alumno = p_alumno_id and estado = 'activa';
  elsif p_id_curso is not null and p_id_curso is distinct from v_curso_actual then
    update public.inscripciones
       set estado = 'finalizada'
     where id_alumno = p_alumno_id and estado = 'activa';
    insert into public.inscripciones (id_alumno, id_curso, estado, fecha_inscripcion)
    values (p_alumno_id, p_id_curso, 'activa', current_date);
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: baja lógica de alumno.
-- ---------------------------------------------------------------------------
create or replace function public.admin_baja_alumno(p_alumno_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_usuario_id uuid;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador puede dar de baja alumnos.' using errcode = '42501';
  end if;

  select id_usuario into v_usuario_id from public.alumnos where id = p_alumno_id;
  if v_usuario_id is null then
    raise exception 'ALUMNO_NO_ENCONTRADO' using errcode = 'P0002';
  end if;

  update public.usuarios set estado = 'inactivo' where id = v_usuario_id;
  update public.alumnos set estado = 'inactivo' where id = p_alumno_id;
  update public.inscripciones
     set estado = 'finalizada'
   where id_alumno = p_alumno_id and estado = 'activa';
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: activar / desactivar cualquier cuenta.
-- ---------------------------------------------------------------------------
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

  update public.usuarios set estado = p_estado where id = p_usuario_id;
  update public.alumnos set estado = p_estado where id_usuario = p_usuario_id;
  update public.profesores set estado = p_estado where id_usuario = p_usuario_id;

  if p_estado = 'inactivo' then
    update public.inscripciones i
       set estado = 'finalizada'
     where i.estado = 'activa'
       and i.id_alumno in (select a.id from public.alumnos a where a.id_usuario = p_usuario_id);
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: inscribir alumno finalizando la inscripción anterior.
-- ---------------------------------------------------------------------------
create or replace function public.admin_inscribir_alumno(
  p_alumno_id uuid,
  p_curso_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actual uuid;
  v_actual_curso uuid;
  v_nueva uuid;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador puede gestionar inscripciones.' using errcode = '42501';
  end if;
  if not exists (select 1 from public.alumnos where id = p_alumno_id) then
    raise exception 'ALUMNO_NO_ENCONTRADO' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.cursos where id = p_curso_id) then
    raise exception 'CURSO_NO_ENCONTRADO' using errcode = 'P0002';
  end if;

  select id, id_curso into v_actual, v_actual_curso
  from public.inscripciones
  where id_alumno = p_alumno_id and estado = 'activa'
  limit 1;

  if v_actual is not null and v_actual_curso = p_curso_id then
    return v_actual;
  end if;

  update public.inscripciones
     set estado = 'finalizada'
   where id_alumno = p_alumno_id and estado = 'activa';

  insert into public.inscripciones (id_alumno, id_curso, estado, fecha_inscripcion)
  values (p_alumno_id, p_curso_id, 'activa', current_date)
  returning id into v_nueva;

  return v_nueva;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: crear materia (si hace falta) y su asignación.
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

  insert into public.asignaciones (id_materia, id_curso, id_profesor, anio_lectivo)
  values (v_materia, p_curso_id, p_profesor_id, p_anio_lectivo)
  on conflict (id_materia, id_curso, id_profesor, anio_lectivo)
  do update set updated_at = now()
  returning id into v_asignacion;

  return v_asignacion;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: eliminar asignación solo si no tiene historial académico.
-- ---------------------------------------------------------------------------
create or replace function public.admin_eliminar_asignacion(p_asignacion_id uuid)
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

  if exists (
    select 1 from public.calificaciones c
    where c.id_materia = v_asig.id_materia and c.id_profesor = v_asig.id_profesor
  ) or exists (
    select 1 from public.asistencias a
    where a.id_materia = v_asig.id_materia and a.id_curso = v_asig.id_curso and a.id_profesor = v_asig.id_profesor
  ) or exists (
    select 1 from public.actividades ac
    where ac.id_materia = v_asig.id_materia and ac.id_curso = v_asig.id_curso and ac.id_profesor = v_asig.id_profesor
  ) then
    raise exception 'ASIGNACION_CON_HISTORIAL' using errcode = '23503';
  end if;

  delete from public.asignaciones where id = p_asignacion_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Permisos de ejecución. Se revoca a anon; solo usuarios autenticados.
-- ---------------------------------------------------------------------------
revoke all on function public.admin_crear_alumno(text, text, text, text, uuid, text, date, text) from public, anon;
revoke all on function public.admin_actualizar_alumno(uuid, text, text, text, text, public.estado_cuenta, uuid, date, text) from public, anon;
revoke all on function public.admin_baja_alumno(uuid) from public, anon;
revoke all on function public.admin_cambiar_estado_usuario(uuid, public.estado_cuenta) from public, anon;
revoke all on function public.admin_inscribir_alumno(uuid, uuid) from public, anon;
revoke all on function public.admin_crear_asignacion(text, uuid, uuid, smallint, text) from public, anon;
revoke all on function public.admin_eliminar_asignacion(uuid) from public, anon;

grant execute on function public.admin_crear_alumno(text, text, text, text, uuid, text, date, text) to authenticated;
grant execute on function public.admin_actualizar_alumno(uuid, text, text, text, text, public.estado_cuenta, uuid, date, text) to authenticated;
grant execute on function public.admin_baja_alumno(uuid) to authenticated;
grant execute on function public.admin_cambiar_estado_usuario(uuid, public.estado_cuenta) to authenticated;
grant execute on function public.admin_inscribir_alumno(uuid, uuid) to authenticated;
grant execute on function public.admin_crear_asignacion(text, uuid, uuid, smallint, text) to authenticated;
grant execute on function public.admin_eliminar_asignacion(uuid) to authenticated;

grant execute on function public.rol_actual() to authenticated;
grant execute on function public.cuenta_activa() to authenticated;
grant execute on function public.es_admin() to authenticated;
grant execute on function public.es_profesor() to authenticated;
grant execute on function public.es_alumno() to authenticated;
grant execute on function public.mi_alumno_id() to authenticated;
grant execute on function public.mi_profesor_id() to authenticated;
grant execute on function public.mi_curso_id() to authenticated;
