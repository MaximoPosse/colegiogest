-- ============================================================================
-- ColegioGest · Etapa 6
-- Migración 001: extensiones y tipos enumerados
-- Proyecto Supabase: dnifipldschmuxkxvizi
-- ============================================================================

create extension if not exists pgcrypto with schema extensions;

-- Tipos enumerados del dominio escolar.
-- Se crean con DO para que la migración sea reproducible sin fallar si ya existen.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'rol_usuario') then
    create type public.rol_usuario as enum ('administrador', 'profesor', 'alumno');
  end if;
  if not exists (select 1 from pg_type where typname = 'estado_cuenta') then
    create type public.estado_cuenta as enum ('activo', 'inactivo');
  end if;
  if not exists (select 1 from pg_type where typname = 'estado_inscripcion') then
    create type public.estado_inscripcion as enum ('activa', 'finalizada');
  end if;
  if not exists (select 1 from pg_type where typname = 'estado_asistencia') then
    create type public.estado_asistencia as enum ('presente', 'ausente', 'tardanza', 'justificada');
  end if;
  if not exists (select 1 from pg_type where typname = 'categoria_aviso') then
    create type public.categoria_aviso as enum ('institucional', 'academico', 'evento');
  end if;
  if not exists (select 1 from pg_type where typname = 'estado_entrega') then
    create type public.estado_entrega as enum ('pendiente', 'entregada');
  end if;
end
$$;
