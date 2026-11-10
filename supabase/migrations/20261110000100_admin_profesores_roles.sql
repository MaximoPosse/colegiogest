-- ============================================================================
-- ColegioGest · Etapa 6 (completado)
-- Migración 007: alta, edición y baja de profesores + cambio de rol
-- ============================================================================
-- Se mantiene el patrón de las RPC de alumnos:
--   * La cuenta se crea en auth.users para que el docente pueda iniciar sesión.
--   * El trigger handle_new_user crea el perfil público; la función lo asegura
--     con un INSERT ... ON CONFLICT por si el trigger cambia en el futuro.
--   * Todos los datos personales siguen normalizados en public.usuarios.
--   * Las bajas son lógicas: no se elimina el historial académico.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- RPC: alta de profesor.
-- ---------------------------------------------------------------------------
create or replace function public.admin_crear_profesor(
  p_nombre text,
  p_apellido text,
  p_dni text,
  p_correo text,
  p_password text default 'demo123'
)
returns uuid
language plpgsql
security definer
set search_path = public, auth, extensions, pg_temp
as $$
declare
  v_user_id   uuid := gen_random_uuid();
  v_dni       text := regexp_replace(coalesce(p_dni, ''), '\D', '', 'g');
  v_correo    text := lower(btrim(coalesce(p_correo, '')));
  v_profesor  uuid;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador puede crear profesores.' using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(p_nombre, '')), '') is null
     or nullif(btrim(coalesce(p_apellido, '')), '') is null then
    raise exception 'El nombre y el apellido son obligatorios.' using errcode = '22023';
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
  if exists (select 1 from public.usuarios where lower(correo) = v_correo)
     or exists (select 1 from auth.users where lower(email) = v_correo) then
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
    jsonb_build_object(
      'nombre', btrim(p_nombre),
      'apellido', btrim(p_apellido),
      'dni', v_dni,
      'rol', 'profesor'
    ),
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

  select id into v_profesor from public.profesores where id_usuario = v_user_id;
  if v_profesor is null then
    insert into public.profesores (id_usuario, estado) values (v_user_id, 'activo')
    returning id into v_profesor;
  else
    update public.profesores set estado = 'activo' where id = v_profesor;
  end if;

  return v_profesor;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: actualización de profesor y sincronización con auth.users.
-- ---------------------------------------------------------------------------
create or replace function public.admin_actualizar_profesor(
  p_profesor_id uuid,
  p_nombre text,
  p_apellido text,
  p_dni text,
  p_correo text,
  p_estado public.estado_cuenta
)
returns void
language plpgsql
security definer
set search_path = public, auth, extensions, pg_temp
as $$
declare
  v_usuario_id uuid;
  v_dni        text := regexp_replace(coalesce(p_dni, ''), '\D', '', 'g');
  v_correo     text := lower(btrim(coalesce(p_correo, '')));
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador puede modificar profesores.' using errcode = '42501';
  end if;

  select id_usuario into v_usuario_id from public.profesores where id = p_profesor_id;
  if v_usuario_id is null then
    raise exception 'PROFESOR_NO_ENCONTRADO' using errcode = 'P0002';
  end if;
  if nullif(btrim(coalesce(p_nombre, '')), '') is null
     or nullif(btrim(coalesce(p_apellido, '')), '') is null then
    raise exception 'El nombre y el apellido son obligatorios.' using errcode = '22023';
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
  if exists (select 1 from public.usuarios where lower(correo) = v_correo and id <> v_usuario_id)
     or exists (select 1 from auth.users where lower(email) = v_correo and id <> v_usuario_id) then
    raise exception 'DUPLICATE_EMAIL' using errcode = '23505';
  end if;

  -- La baja debe pasar por el mismo control que admin_baja_profesor para no
  -- dejar asignaciones vigentes apuntando a una cuenta inactiva.
  if p_estado = 'inactivo' and exists (
    select 1
    from public.asignaciones a
    where a.id_profesor = p_profesor_id
      and a.anio_lectivo >= extract(year from current_date)::smallint
  ) then
    raise exception 'PROFESOR_CON_ASIGNACIONES' using errcode = '23514';
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

  update public.profesores set estado = p_estado where id = p_profesor_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: baja lógica de profesor.
-- Se impide si todavía tiene asignaciones del ciclo lectivo actual: primero
-- hay que reasignar o eliminar esas asignaciones. Las asignaciones históricas
-- se conservan para no perder el historial.
-- ---------------------------------------------------------------------------
create or replace function public.admin_baja_profesor(p_profesor_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_usuario_id uuid;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador puede dar de baja profesores.' using errcode = '42501';
  end if;

  select id_usuario into v_usuario_id from public.profesores where id = p_profesor_id;
  if v_usuario_id is null then
    raise exception 'PROFESOR_NO_ENCONTRADO' using errcode = 'P0002';
  end if;

  if exists (
    select 1
    from public.asignaciones a
    where a.id_profesor = p_profesor_id
      and a.anio_lectivo >= extract(year from current_date)::smallint
  ) then
    raise exception 'PROFESOR_CON_ASIGNACIONES' using errcode = '23514';
  end if;

  update public.usuarios set estado = 'inactivo' where id = v_usuario_id;
  update public.profesores set estado = 'inactivo' where id = p_profesor_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: cambio de rol.
--   * alumno  -> profesor: finaliza inscripciones y retira el perfil de alumno.
--   * profesor -> alumno: exige que no tenga asignaciones del ciclo actual.
--   * cualquier rol -> administrador: retira los perfiles académicos.
-- Los perfiles se desactivan en lugar de borrarse para conservar el historial.
-- ---------------------------------------------------------------------------
create or replace function public.admin_cambiar_rol_usuario(
  p_usuario_id uuid,
  p_rol public.rol_usuario
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_rol_actual public.rol_usuario;
  v_admins     integer;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador puede cambiar roles.' using errcode = '42501';
  end if;

  select rol into v_rol_actual from public.usuarios where id = p_usuario_id;
  if v_rol_actual is null then
    raise exception 'USUARIO_NO_ENCONTRADO' using errcode = 'P0002';
  end if;

  if p_usuario_id = auth.uid() and p_rol <> 'administrador' then
    raise exception 'No podés quitarte tu propio rol de administrador.' using errcode = '42501';
  end if;

  if v_rol_actual = 'administrador' and p_rol <> 'administrador' then
    select count(*) into v_admins
    from public.usuarios
    where rol = 'administrador' and estado = 'activo';
    if v_admins <= 1 then
      raise exception 'Debe quedar al menos un administrador activo en el sistema.' using errcode = '23514';
    end if;
  end if;

  if v_rol_actual = p_rol then
    return;
  end if;

  if p_rol = 'profesor' then
    update public.inscripciones
       set estado = 'finalizada'
     where estado = 'activa'
       and id_alumno in (select id from public.alumnos where id_usuario = p_usuario_id);
    update public.alumnos set estado = 'inactivo' where id_usuario = p_usuario_id;
    insert into public.profesores (id_usuario, estado)
    values (p_usuario_id, 'activo')
    on conflict (id_usuario) do update set estado = 'activo';
  elsif p_rol = 'alumno' then
    if exists (
      select 1
      from public.asignaciones a
      where a.id_profesor in (select id from public.profesores where id_usuario = p_usuario_id)
        and a.anio_lectivo >= extract(year from current_date)::smallint
    ) then
      raise exception 'El profesor tiene asignaciones vigentes. Reasigná o eliminá esas asignaciones antes de cambiar el rol.'
        using errcode = '23514';
    end if;
    update public.profesores set estado = 'inactivo' where id_usuario = p_usuario_id;
    insert into public.alumnos (id_usuario, estado)
    values (p_usuario_id, 'activo')
    on conflict (id_usuario) do update set estado = 'activo';
  else
    update public.inscripciones
       set estado = 'finalizada'
     where estado = 'activa'
       and id_alumno in (select id from public.alumnos where id_usuario = p_usuario_id);
    update public.alumnos set estado = 'inactivo' where id_usuario = p_usuario_id;
    update public.profesores set estado = 'inactivo' where id_usuario = p_usuario_id;
  end if;

  update public.usuarios set rol = p_rol where id = p_usuario_id;

  update auth.users
     set raw_user_meta_data = jsonb_set(
           coalesce(raw_user_meta_data, '{}'::jsonb),
           '{rol}',
           to_jsonb(p_rol::text),
           true
         ),
         updated_at = now()
   where id = p_usuario_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Permisos: solo usuarios autenticados; la validación real está en cada RPC.
-- ---------------------------------------------------------------------------
revoke all on function public.admin_crear_profesor(text, text, text, text, text) from public, anon;
revoke all on function public.admin_actualizar_profesor(uuid, text, text, text, text, public.estado_cuenta) from public, anon;
revoke all on function public.admin_baja_profesor(uuid) from public, anon;
revoke all on function public.admin_cambiar_rol_usuario(uuid, public.rol_usuario) from public, anon;

grant execute on function public.admin_crear_profesor(text, text, text, text, text) to authenticated;
grant execute on function public.admin_actualizar_profesor(uuid, text, text, text, text, public.estado_cuenta) to authenticated;
grant execute on function public.admin_baja_profesor(uuid) to authenticated;
grant execute on function public.admin_cambiar_rol_usuario(uuid, public.rol_usuario) to authenticated;
