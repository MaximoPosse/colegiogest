-- ============================================================================
-- ColegioGest · Alta directa de administradores
-- Migración 010
-- ============================================================================

create or replace function public.admin_crear_administrador(
  p_nombre text,
  p_apellido text,
  p_dni text,
  p_correo text,
  p_password text
)
returns uuid
language plpgsql
security definer
set search_path = public, auth, extensions, pg_temp
as $$
declare
  v_user_id uuid := gen_random_uuid();
  v_dni text := regexp_replace(coalesce(p_dni, ''), '\D', '', 'g');
  v_correo text := lower(btrim(coalesce(p_correo, '')));
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador puede crear administradores.' using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(p_nombre, '')), '') is null
     or length(btrim(p_nombre)) > 80
     or nullif(btrim(coalesce(p_apellido, '')), '') is null
     or length(btrim(p_apellido)) > 80 then
    raise exception 'El nombre y el apellido son obligatorios y no pueden superar 80 caracteres.' using errcode = '22023';
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
      'rol', 'administrador'
    ),
    now(), now(), '', '', '', ''
  );

  insert into auth.identities (
    user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
  ) values (
    v_user_id,
    jsonb_build_object('sub', v_user_id::text, 'email', v_correo, 'email_verified', true),
    'email',
    v_user_id::text,
    now(), now(), now()
  ) on conflict do nothing;

  -- handle_new_user() normally creates this row. Keep the function resilient
  -- if that auth trigger is altered or disabled during a controlled migration.
  insert into public.usuarios (id, nombre, apellido, dni, correo, rol, estado, fecha_alta)
  values (v_user_id, btrim(p_nombre), btrim(p_apellido), v_dni, v_correo, 'administrador', 'activo', now())
  on conflict (id) do nothing;

  return v_user_id;
end;
$$;

revoke all on function public.admin_crear_administrador(text,text,text,text,text) from public, anon;
grant execute on function public.admin_crear_administrador(text,text,text,text,text) to authenticated;

notify pgrst, 'reload schema';
