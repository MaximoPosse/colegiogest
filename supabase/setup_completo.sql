-- ============================================================================
-- ColegioGest · Etapa 6 · Script único de puesta en marcha
-- Ejecutar UNA sola vez en Supabase → SQL Editor (proyecto vacío).
-- Incluye, en orden: extensiones/tipos, tablas, funciones/triggers, RLS, vistas, fix y seed.
-- Es re-ejecutable en su mayor parte: usa IF NOT EXISTS / CREATE OR REPLACE / DROP POLICY IF EXISTS,
-- y el seed se omite si public.usuarios ya tiene filas.
-- ============================================================================

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- ARCHIVO: supabase/migrations/20261106000100_extensions_and_types.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

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


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- ARCHIVO: supabase/migrations/20261106000200_tables.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================================
-- ColegioGest · Etapa 6
-- Migración 002: modelo relacional
-- ============================================================================
-- Criterio de normalización:
--   * Los datos personales (nombre, apellido, DNI, correo) viven una sola vez
--     en public.usuarios.
--   * public.alumnos y public.profesores son perfiles 1:1 que referencian a
--     public.usuarios.
--   * Inscripción y Asignación resuelven las relaciones N:M.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Usuarios: espejo de auth.users + datos de negocio.
-- ---------------------------------------------------------------------------
create table if not exists public.usuarios (
  id          uuid primary key references auth.users (id) on delete cascade,
  nombre      text not null,
  apellido    text not null,
  dni         text not null,
  correo      text not null,
  rol         public.rol_usuario not null default 'alumno',
  estado      public.estado_cuenta not null default 'activo',
  fecha_alta  timestamptz not null default now(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint usuarios_nombre_chk    check (length(btrim(nombre)) between 1 and 80),
  constraint usuarios_apellido_chk  check (length(btrim(apellido)) between 1 and 80),
  constraint usuarios_dni_chk       check (dni ~ '^[0-9]{7,9}$'),
  constraint usuarios_correo_chk    check (correo ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')
);

-- Unicidad insensible a mayúsculas para correo y DNI.
create unique index if not exists usuarios_correo_lower_key on public.usuarios (lower(correo));
create unique index if not exists usuarios_dni_key on public.usuarios (dni);

comment on table public.usuarios is
  'Cuentas del sistema. id es el mismo uuid de auth.users. Contiene los datos personales normalizados.';
comment on column public.usuarios.rol is
  'Rol de negocio: administrador, profesor o alumno. No debe ser modificado por el propio usuario.';
comment on column public.usuarios.estado is
  'Estado de la cuenta. Una cuenta inactiva no puede iniciar sesión ni operar en la aplicación.';

-- ---------------------------------------------------------------------------
-- Alumnos: perfil 1:1 con usuarios.
-- ---------------------------------------------------------------------------
create table if not exists public.alumnos (
  id                uuid primary key default gen_random_uuid(),
  id_usuario        uuid not null unique references public.usuarios (id) on delete cascade,
  fecha_nacimiento  date,
  telefono          text,
  estado            public.estado_cuenta not null default 'activo',
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint alumnos_telefono_chk check (telefono is null or length(btrim(telefono)) between 6 and 30)
);

comment on table public.alumnos is
  'Perfil académico del estudiante. Los datos personales se consultan desde usuarios (1:1).';

-- ---------------------------------------------------------------------------
-- Profesores: perfil 1:1 con usuarios.
-- ---------------------------------------------------------------------------
create table if not exists public.profesores (
  id          uuid primary key default gen_random_uuid(),
  id_usuario  uuid not null unique references public.usuarios (id) on delete cascade,
  estado      public.estado_cuenta not null default 'activo',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.profesores is
  'Perfil docente. Los datos personales se consultan desde usuarios (1:1).';

-- ---------------------------------------------------------------------------
-- Cursos.
-- ---------------------------------------------------------------------------
create table if not exists public.cursos (
  id          uuid primary key default gen_random_uuid(),
  anio        smallint not null,
  division    varchar(10) not null,
  turno       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint cursos_anio_chk     check (anio between 1 and 12),
  constraint cursos_division_chk check (length(btrim(division)) between 1 and 10),
  constraint cursos_turno_chk    check (turno is null or turno in ('mañana', 'tarde', 'noche'))
);

create unique index if not exists cursos_anio_division_turno_key
  on public.cursos (anio, division, coalesce(turno, ''));

comment on table public.cursos is
  'Cursos escolares. anio + division + turno identifican funcionalmente un curso.';

-- ---------------------------------------------------------------------------
-- Materias: catálogo independiente de curso y profesor.
-- ---------------------------------------------------------------------------
create table if not exists public.materias (
  id          uuid primary key default gen_random_uuid(),
  nombre      text not null,
  descripcion text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint materias_nombre_chk check (length(btrim(nombre)) between 1 and 120)
);

create unique index if not exists materias_nombre_lower_key on public.materias (lower(nombre));

comment on table public.materias is
  'Catálogo de materias. Una materia puede dictarse en varios cursos y por varios profesores mediante asignaciones.';

-- ---------------------------------------------------------------------------
-- Asignaciones: N:M entre materia, curso y profesor para un año lectivo.
-- ---------------------------------------------------------------------------
create table if not exists public.asignaciones (
  id            uuid primary key default gen_random_uuid(),
  id_materia    uuid not null references public.materias (id) on delete restrict,
  id_curso      uuid not null references public.cursos (id) on delete restrict,
  id_profesor   uuid not null references public.profesores (id) on delete restrict,
  anio_lectivo  smallint not null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint asignaciones_anio_chk check (anio_lectivo between 2000 and 2100),
  constraint asignaciones_unique unique (id_materia, id_curso, id_profesor, anio_lectivo)
);

create index if not exists asignaciones_profesor_idx on public.asignaciones (id_profesor);
create index if not exists asignaciones_curso_idx    on public.asignaciones (id_curso);
create index if not exists asignaciones_materia_idx  on public.asignaciones (id_materia);

comment on table public.asignaciones is
  'Define qué materia dicta qué profesor en qué curso y año lectivo. Es la base de los permisos del docente.';

-- ---------------------------------------------------------------------------
-- Inscripciones: historial N:M entre alumno y curso.
-- ---------------------------------------------------------------------------
create table if not exists public.inscripciones (
  id                  uuid primary key default gen_random_uuid(),
  id_alumno           uuid not null references public.alumnos (id) on delete cascade,
  id_curso            uuid not null references public.cursos (id) on delete restrict,
  fecha_inscripcion   date not null default current_date,
  estado              public.estado_inscripcion not null default 'activa',
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint inscripciones_unique unique (id_alumno, id_curso, fecha_inscripcion)
);

-- Un alumno solo puede tener una inscripción activa a la vez.
create unique index if not exists inscripciones_una_activa_por_alumno
  on public.inscripciones (id_alumno)
  where estado = 'activa';

create index if not exists inscripciones_curso_estado_idx
  on public.inscripciones (id_curso, estado);

comment on table public.inscripciones is
  'Historial de inscripciones. Cambiar de curso finaliza la inscripción anterior y crea una nueva.';

-- ---------------------------------------------------------------------------
-- Calificaciones.
-- ---------------------------------------------------------------------------
create table if not exists public.calificaciones (
  id              uuid primary key default gen_random_uuid(),
  id_alumno       uuid not null references public.alumnos (id) on delete cascade,
  id_materia      uuid not null references public.materias (id) on delete restrict,
  id_profesor     uuid not null references public.profesores (id) on delete restrict,
  tipo_instancia  text not null,
  nota            numeric(4,2) not null,
  fecha           date not null default current_date,
  observacion     text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint calificaciones_instancia_chk check (length(btrim(tipo_instancia)) between 1 and 120),
  constraint calificaciones_nota_chk check (nota between 1 and 10)
);

create index if not exists calificaciones_alumno_idx on public.calificaciones (id_alumno);
create index if not exists calificaciones_materia_idx on public.calificaciones (id_materia);
create index if not exists calificaciones_fecha_idx on public.calificaciones (fecha desc);

comment on table public.calificaciones is
  'Notas de alumnos. La nota se expresa en una escala de 1 a 10.';

-- ---------------------------------------------------------------------------
-- Asistencias.
-- ---------------------------------------------------------------------------
create table if not exists public.asistencias (
  id            uuid primary key default gen_random_uuid(),
  id_alumno     uuid not null references public.alumnos (id) on delete cascade,
  id_curso      uuid not null references public.cursos (id) on delete restrict,
  id_materia    uuid not null references public.materias (id) on delete restrict,
  id_profesor   uuid not null references public.profesores (id) on delete restrict,
  fecha         date not null default current_date,
  estado        public.estado_asistencia not null,
  observacion   text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint asistencias_unique unique (id_alumno, id_curso, id_materia, fecha)
);

create index if not exists asistencias_alumno_idx on public.asistencias (id_alumno, fecha desc);
create index if not exists asistencias_curso_fecha_idx on public.asistencias (id_curso, fecha desc);

comment on table public.asistencias is
  'Registro diario de asistencia por alumno, curso y materia.';

-- ---------------------------------------------------------------------------
-- Actividades.
-- ---------------------------------------------------------------------------
create table if not exists public.actividades (
  id                  uuid primary key default gen_random_uuid(),
  titulo              text not null,
  descripcion         text not null,
  fecha_entrega       date not null,
  id_materia          uuid not null references public.materias (id) on delete restrict,
  id_curso            uuid not null references public.cursos (id) on delete restrict,
  id_profesor         uuid not null references public.profesores (id) on delete restrict,
  fecha_publicacion   timestamptz not null default now(),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint actividades_titulo_chk      check (length(btrim(titulo)) between 1 and 160),
  constraint actividades_descripcion_chk check (length(btrim(descripcion)) between 1 and 4000)
);

create index if not exists actividades_curso_entrega_idx
  on public.actividades (id_curso, fecha_entrega);

comment on table public.actividades is
  'Tareas, trabajos prácticos y evaluaciones publicadas por un profesor para un curso y materia.';

-- ---------------------------------------------------------------------------
-- Entregas de actividades (funcionalidad existente "Marcar entregada").
-- ---------------------------------------------------------------------------
create table if not exists public.entregas_actividades (
  id              uuid primary key default gen_random_uuid(),
  id_actividad    uuid not null references public.actividades (id) on delete cascade,
  id_alumno       uuid not null references public.alumnos (id) on delete cascade,
  estado          public.estado_entrega not null default 'entregada',
  fecha_entrega   timestamptz not null default now(),
  comentario      text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint entregas_unique unique (id_actividad, id_alumno)
);

create index if not exists entregas_alumno_idx on public.entregas_actividades (id_alumno);

comment on table public.entregas_actividades is
  'Marca de entrega de una actividad por alumno. Se agrega porque la Etapa 5 ya ofrecía "Marcar entregada".';

-- ---------------------------------------------------------------------------
-- Avisos.
-- ---------------------------------------------------------------------------
create table if not exists public.avisos (
  id                  uuid primary key default gen_random_uuid(),
  titulo              text not null,
  contenido           text not null,
  categoria           public.categoria_aviso not null default 'institucional',
  fecha_publicacion   timestamptz not null default now(),
  id_autor            uuid not null references public.usuarios (id) on delete restrict,
  id_curso_destino    uuid references public.cursos (id) on delete restrict,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint avisos_titulo_chk    check (length(btrim(titulo)) between 1 and 160),
  constraint avisos_contenido_chk check (length(btrim(contenido)) between 1 and 4000)
);

create index if not exists avisos_publicacion_idx on public.avisos (fecha_publicacion desc);
create index if not exists avisos_curso_idx on public.avisos (id_curso_destino);

comment on table public.avisos is
  'Comunicados. Si id_curso_destino es null el aviso es institucional y se muestra a toda la comunidad.';
comment on column public.avisos.categoria is
  'Categoría usada por la interfaz (Institucional, Académico, Evento).';


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- ARCHIVO: supabase/migrations/20261106000300_functions_triggers.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

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


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- ARCHIVO: supabase/migrations/20261106000400_rls_policies.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================================
-- ColegioGest · Etapa 6
-- Migración 004: Row Level Security
-- ============================================================================
-- Principios:
--   * Sin cuenta activa no hay acceso a datos.
--   * El rol se obtiene SIEMPRE de public.usuarios, nunca de datos del cliente.
--   * El alumno solo ve su propia información.
--   * El profesor solo opera sobre sus asignaciones.
--   * El administrador gestiona el sistema.
-- ============================================================================

alter table public.usuarios              enable row level security;
alter table public.alumnos               enable row level security;
alter table public.profesores            enable row level security;
alter table public.cursos                enable row level security;
alter table public.materias              enable row level security;
alter table public.asignaciones          enable row level security;
alter table public.inscripciones         enable row level security;
alter table public.calificaciones        enable row level security;
alter table public.asistencias           enable row level security;
alter table public.actividades           enable row level security;
alter table public.entregas_actividades  enable row level security;
alter table public.avisos                enable row level security;

-- ---------------------------------------------------------------------------
-- usuarios
-- ---------------------------------------------------------------------------
drop policy if exists usuarios_select on public.usuarios;
create policy usuarios_select on public.usuarios
for select to authenticated
using (
  -- El propio usuario puede leer su fila aun si está inactivo. La aplicación
  -- usa este dato para cerrar la sesión de una cuenta desactivada (RN11).
  id = auth.uid()
  or (
    public.cuenta_activa()
    and (
      public.es_admin()
      or (public.es_profesor() and public.profesor_puede_ver_usuario(id))
      or (
        public.es_alumno()
        and exists (
          select 1 from public.profesores p
          where p.id_usuario = usuarios.id
            and public.alumno_puede_ver_profesor(p.id)
        )
      )
    )
  )
);

drop policy if exists usuarios_insert on public.usuarios;
create policy usuarios_insert on public.usuarios
for insert to authenticated
with check (public.cuenta_activa() and public.es_admin());

drop policy if exists usuarios_update on public.usuarios;
create policy usuarios_update on public.usuarios
for update to authenticated
using (public.cuenta_activa() and (id = auth.uid() or public.es_admin()))
with check (public.cuenta_activa() and (id = auth.uid() or public.es_admin()));

drop policy if exists usuarios_delete on public.usuarios;
create policy usuarios_delete on public.usuarios
for delete to authenticated
using (public.es_admin());

-- ---------------------------------------------------------------------------
-- alumnos
-- ---------------------------------------------------------------------------
drop policy if exists alumnos_select on public.alumnos;
create policy alumnos_select on public.alumnos
for select to authenticated
using (
  public.cuenta_activa()
  and (
    public.es_admin()
    or id_usuario = auth.uid()
    or (public.es_profesor() and public.profesor_puede_ver_alumno(id))
  )
);

drop policy if exists alumnos_insert on public.alumnos;
create policy alumnos_insert on public.alumnos
for insert to authenticated
with check (public.es_admin());

drop policy if exists alumnos_update on public.alumnos;
create policy alumnos_update on public.alumnos
for update to authenticated
using (public.es_admin())
with check (public.es_admin());

drop policy if exists alumnos_delete on public.alumnos;
create policy alumnos_delete on public.alumnos
for delete to authenticated
using (public.es_admin());

-- ---------------------------------------------------------------------------
-- profesores
-- ---------------------------------------------------------------------------
drop policy if exists profesores_select on public.profesores;
create policy profesores_select on public.profesores
for select to authenticated
using (
  public.cuenta_activa()
  and (
    public.es_admin()
    or id_usuario = auth.uid()
    or (public.es_alumno() and public.alumno_puede_ver_profesor(id))
  )
);

drop policy if exists profesores_insert on public.profesores;
create policy profesores_insert on public.profesores
for insert to authenticated
with check (public.es_admin());

drop policy if exists profesores_update on public.profesores;
create policy profesores_update on public.profesores
for update to authenticated
using (public.es_admin())
with check (public.es_admin());

drop policy if exists profesores_delete on public.profesores;
create policy profesores_delete on public.profesores
for delete to authenticated
using (public.es_admin());

-- ---------------------------------------------------------------------------
-- cursos
-- ---------------------------------------------------------------------------
drop policy if exists cursos_select on public.cursos;
create policy cursos_select on public.cursos
for select to authenticated
using (
  public.cuenta_activa()
  and (
    public.es_admin()
    or (public.es_profesor() and public.profesor_puede_ver_curso(id))
    or (public.es_alumno() and id = public.mi_curso_id())
  )
);

drop policy if exists cursos_insert on public.cursos;
create policy cursos_insert on public.cursos
for insert to authenticated
with check (public.es_admin());

drop policy if exists cursos_update on public.cursos;
create policy cursos_update on public.cursos
for update to authenticated
using (public.es_admin())
with check (public.es_admin());

drop policy if exists cursos_delete on public.cursos;
create policy cursos_delete on public.cursos
for delete to authenticated
using (public.es_admin());

-- ---------------------------------------------------------------------------
-- materias
-- ---------------------------------------------------------------------------
drop policy if exists materias_select on public.materias;
create policy materias_select on public.materias
for select to authenticated
using (
  public.cuenta_activa()
  and (
    public.es_admin()
    or (public.es_profesor() and public.profesor_puede_ver_materia(id))
    or (public.es_alumno() and public.alumno_puede_ver_materia(id))
  )
);

drop policy if exists materias_insert on public.materias;
create policy materias_insert on public.materias
for insert to authenticated
with check (public.es_admin());

drop policy if exists materias_update on public.materias;
create policy materias_update on public.materias
for update to authenticated
using (public.es_admin())
with check (public.es_admin());

drop policy if exists materias_delete on public.materias;
create policy materias_delete on public.materias
for delete to authenticated
using (public.es_admin());

-- ---------------------------------------------------------------------------
-- asignaciones
-- ---------------------------------------------------------------------------
drop policy if exists asignaciones_select on public.asignaciones;
create policy asignaciones_select on public.asignaciones
for select to authenticated
using (
  public.cuenta_activa()
  and (
    public.es_admin()
    or (public.es_profesor() and id_profesor = public.mi_profesor_id())
    or (public.es_alumno() and id_curso = public.mi_curso_id())
  )
);

drop policy if exists asignaciones_insert on public.asignaciones;
create policy asignaciones_insert on public.asignaciones
for insert to authenticated
with check (public.es_admin());

drop policy if exists asignaciones_update on public.asignaciones;
create policy asignaciones_update on public.asignaciones
for update to authenticated
using (public.es_admin())
with check (public.es_admin());

drop policy if exists asignaciones_delete on public.asignaciones;
create policy asignaciones_delete on public.asignaciones
for delete to authenticated
using (public.es_admin());

-- ---------------------------------------------------------------------------
-- inscripciones
-- ---------------------------------------------------------------------------
drop policy if exists inscripciones_select on public.inscripciones;
create policy inscripciones_select on public.inscripciones
for select to authenticated
using (
  public.cuenta_activa()
  and (
    public.es_admin()
    or id_alumno = public.mi_alumno_id()
    or (public.es_profesor() and public.profesor_puede_ver_curso(id_curso))
  )
);

drop policy if exists inscripciones_insert on public.inscripciones;
create policy inscripciones_insert on public.inscripciones
for insert to authenticated
with check (public.es_admin());

drop policy if exists inscripciones_update on public.inscripciones;
create policy inscripciones_update on public.inscripciones
for update to authenticated
using (public.es_admin())
with check (public.es_admin());

drop policy if exists inscripciones_delete on public.inscripciones;
create policy inscripciones_delete on public.inscripciones
for delete to authenticated
using (public.es_admin());

-- ---------------------------------------------------------------------------
-- calificaciones
-- ---------------------------------------------------------------------------
drop policy if exists calificaciones_select on public.calificaciones;
create policy calificaciones_select on public.calificaciones
for select to authenticated
using (
  public.cuenta_activa()
  and (
    public.es_admin()
    or id_alumno = public.mi_alumno_id()
    or (
      public.es_profesor()
      and public.profesor_dicta(id_materia, public.curso_de_alumno(id_alumno))
    )
  )
);

drop policy if exists calificaciones_insert on public.calificaciones;
create policy calificaciones_insert on public.calificaciones
for insert to authenticated
with check (
  public.cuenta_activa()
  and (
    public.es_admin()
    or (
      public.es_profesor()
      and id_profesor = public.mi_profesor_id()
      and public.profesor_dicta(id_materia, public.curso_de_alumno(id_alumno))
    )
  )
);

drop policy if exists calificaciones_update on public.calificaciones;
create policy calificaciones_update on public.calificaciones
for update to authenticated
using (
  public.cuenta_activa()
  and (
    public.es_admin()
    or (public.es_profesor() and id_profesor = public.mi_profesor_id())
  )
)
with check (
  public.cuenta_activa()
  and (
    public.es_admin()
    or (
      public.es_profesor()
      and id_profesor = public.mi_profesor_id()
      and public.profesor_dicta(id_materia, public.curso_de_alumno(id_alumno))
    )
  )
);

drop policy if exists calificaciones_delete on public.calificaciones;
create policy calificaciones_delete on public.calificaciones
for delete to authenticated
using (
  public.cuenta_activa()
  and (
    public.es_admin()
    or (public.es_profesor() and id_profesor = public.mi_profesor_id())
  )
);

-- ---------------------------------------------------------------------------
-- asistencias
-- ---------------------------------------------------------------------------
drop policy if exists asistencias_select on public.asistencias;
create policy asistencias_select on public.asistencias
for select to authenticated
using (
  public.cuenta_activa()
  and (
    public.es_admin()
    or id_alumno = public.mi_alumno_id()
    or (
      public.es_profesor()
      and public.profesor_dicta(id_materia, id_curso)
    )
  )
);

drop policy if exists asistencias_insert on public.asistencias;
create policy asistencias_insert on public.asistencias
for insert to authenticated
with check (
  public.cuenta_activa()
  and (
    public.es_admin()
    or (
      public.es_profesor()
      and id_profesor = public.mi_profesor_id()
      and public.profesor_dicta(id_materia, id_curso)
    )
  )
);

drop policy if exists asistencias_update on public.asistencias;
create policy asistencias_update on public.asistencias
for update to authenticated
using (
  public.cuenta_activa()
  and (
    public.es_admin()
    or (public.es_profesor() and id_profesor = public.mi_profesor_id())
  )
)
with check (
  public.cuenta_activa()
  and (
    public.es_admin()
    or (
      public.es_profesor()
      and id_profesor = public.mi_profesor_id()
      and public.profesor_dicta(id_materia, id_curso)
    )
  )
);

drop policy if exists asistencias_delete on public.asistencias;
create policy asistencias_delete on public.asistencias
for delete to authenticated
using (
  public.cuenta_activa()
  and (
    public.es_admin()
    or (public.es_profesor() and id_profesor = public.mi_profesor_id())
  )
);

-- ---------------------------------------------------------------------------
-- actividades
-- ---------------------------------------------------------------------------
drop policy if exists actividades_select on public.actividades;
create policy actividades_select on public.actividades
for select to authenticated
using (
  public.cuenta_activa()
  and (
    public.es_admin()
    or (public.es_profesor() and id_profesor = public.mi_profesor_id())
    or (public.es_alumno() and id_curso = public.mi_curso_id())
  )
);

drop policy if exists actividades_insert on public.actividades;
create policy actividades_insert on public.actividades
for insert to authenticated
with check (
  public.cuenta_activa()
  and (
    public.es_admin()
    or (
      public.es_profesor()
      and id_profesor = public.mi_profesor_id()
      and public.profesor_dicta(id_materia, id_curso)
    )
  )
);

drop policy if exists actividades_update on public.actividades;
create policy actividades_update on public.actividades
for update to authenticated
using (
  public.cuenta_activa()
  and (
    public.es_admin()
    or (public.es_profesor() and id_profesor = public.mi_profesor_id())
  )
)
with check (
  public.cuenta_activa()
  and (
    public.es_admin()
    or (
      public.es_profesor()
      and id_profesor = public.mi_profesor_id()
      and public.profesor_dicta(id_materia, id_curso)
    )
  )
);

drop policy if exists actividades_delete on public.actividades;
create policy actividades_delete on public.actividades
for delete to authenticated
using (
  public.cuenta_activa()
  and (
    public.es_admin()
    or (public.es_profesor() and id_profesor = public.mi_profesor_id())
  )
);

-- ---------------------------------------------------------------------------
-- entregas_actividades
-- ---------------------------------------------------------------------------
drop policy if exists entregas_select on public.entregas_actividades;
create policy entregas_select on public.entregas_actividades
for select to authenticated
using (
  public.cuenta_activa()
  and (
    public.es_admin()
    or id_alumno = public.mi_alumno_id()
    or (public.es_profesor() and public.profesor_es_autor_actividad(id_actividad))
  )
);

drop policy if exists entregas_insert on public.entregas_actividades;
create policy entregas_insert on public.entregas_actividades
for insert to authenticated
with check (
  public.cuenta_activa()
  and (
    public.es_admin()
    or (
      public.es_alumno()
      and id_alumno = public.mi_alumno_id()
      and exists (
        select 1 from public.actividades a
        where a.id = id_actividad
          and a.id_curso = public.mi_curso_id()
      )
    )
  )
);

drop policy if exists entregas_update on public.entregas_actividades;
create policy entregas_update on public.entregas_actividades
for update to authenticated
using (
  public.cuenta_activa()
  and (
    public.es_admin()
    or id_alumno = public.mi_alumno_id()
    or (public.es_profesor() and public.profesor_es_autor_actividad(id_actividad))
  )
)
with check (
  public.cuenta_activa()
  and (
    public.es_admin()
    or id_alumno = public.mi_alumno_id()
    or (public.es_profesor() and public.profesor_es_autor_actividad(id_actividad))
  )
);

drop policy if exists entregas_delete on public.entregas_actividades;
create policy entregas_delete on public.entregas_actividades
for delete to authenticated
using (
  public.cuenta_activa()
  and (
    public.es_admin()
    or id_alumno = public.mi_alumno_id()
  )
);

-- ---------------------------------------------------------------------------
-- avisos
-- ---------------------------------------------------------------------------
drop policy if exists avisos_select on public.avisos;
create policy avisos_select on public.avisos
for select to authenticated
using (
  public.cuenta_activa()
  and (
    public.es_admin()
    or id_autor = auth.uid()
    or id_curso_destino is null
    or (public.es_alumno() and id_curso_destino = public.mi_curso_id())
    or (public.es_profesor() and public.profesor_puede_ver_curso(id_curso_destino))
  )
);

drop policy if exists avisos_insert on public.avisos;
create policy avisos_insert on public.avisos
for insert to authenticated
with check (
  public.cuenta_activa()
  and (
    public.es_admin()
    or (
      public.es_profesor()
      and id_autor = auth.uid()
      and (id_curso_destino is null or public.profesor_puede_ver_curso(id_curso_destino))
    )
  )
);

drop policy if exists avisos_update on public.avisos;
create policy avisos_update on public.avisos
for update to authenticated
using (
  public.cuenta_activa()
  and (public.es_admin() or id_autor = auth.uid())
)
with check (
  public.cuenta_activa()
  and (
    public.es_admin()
    or (
      public.es_profesor()
      and id_autor = auth.uid()
      and (id_curso_destino is null or public.profesor_puede_ver_curso(id_curso_destino))
    )
  )
);

drop policy if exists avisos_delete on public.avisos;
create policy avisos_delete on public.avisos
for delete to authenticated
using (
  public.cuenta_activa()
  and (public.es_admin() or id_autor = auth.uid())
);


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- ARCHIVO: supabase/migrations/20261106000500_views.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

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


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- ARCHIVO: supabase/migrations/20261106000600_fix_v_avisos.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================================
-- ColegioGest · Etapa 6
-- Migración 006: corrección de v_avisos (autores no visibles por RLS)
-- ============================================================================
-- Problema detectado en las pruebas:
--   v_avisos hacía INNER JOIN con public.usuarios para obtener el nombre del
--   autor. La política usuarios_select no deja que un alumno o un profesor vea
--   la fila del administrador, por lo que los avisos institucionales (autor =
--   admin) desaparecían del resultado aunque la política avisos_select sí los
--   permitía.
--
-- Solución:
--   * La vista deja de unir usuarios y usa una función SECURITY DEFINER mínima
--     que devuelve únicamente "nombre apellido" del autor.
--   * La visibilidad de las filas sigue dependiendo exclusivamente de la RLS de
--     public.avisos, porque la vista es security_invoker.
-- ============================================================================

create or replace function public.nombre_usuario(p_id uuid)
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select nullif(btrim(u.nombre || ' ' || u.apellido), '')
  from public.usuarios u
  where u.id = p_id;
$$;

revoke all on function public.nombre_usuario(uuid) from public;
revoke all on function public.nombre_usuario(uuid) from anon;
grant execute on function public.nombre_usuario(uuid) to authenticated;

drop view if exists public.v_avisos cascade;
create view public.v_avisos with (security_invoker = true) as
select
  av.id,
  av.titulo,
  av.contenido,
  av.categoria,
  av.fecha_publicacion,
  av.id_autor,
  public.nombre_usuario(av.id_autor) as autor,
  av.id_curso_destino,
  c.anio,
  c.division,
  c.turno
from public.avisos av
left join public.cursos c on c.id = av.id_curso_destino;

grant select on public.v_avisos to authenticated;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- ARCHIVO: supabase/seed.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================================
-- ColegioGest · Etapa 6
-- Seed de datos ficticios coherentes
-- ============================================================================
-- Ejecutar DESPUÉS de las migraciones. El script es idempotente a nivel global:
-- si ya existen usuarios, no vuelve a insertar nada.
--
-- Cuentas de prueba (todas con contraseña demo123):
--   admin@colegiogest.edu.ar      · administrador
--   profesor@colegiogest.edu.ar   · profesor (Santiago López)
--   alumno@colegiogest.edu.ar     · alumno (Lucía Fernández)
-- ============================================================================

do $$
declare
  r record;
  v_id uuid;

  v_admin_user      uuid := '11111111-1111-4111-8111-111111111111';
  v_santiago_user   uuid := '22222222-2222-4222-8222-222222222222';
  v_carolina_user   uuid := '22222222-2222-4222-8222-222222222223';
  v_pablo_user      uuid := '22222222-2222-4222-8222-222222222224';
  v_andrea_user     uuid := '22222222-2222-4222-8222-222222222225';
  v_martin_user     uuid := '22222222-2222-4222-8222-222222222226';
  v_laura_user      uuid := '22222222-2222-4222-8222-222222222227';
  v_lucia_user      uuid := '33333333-3333-4333-8333-333333333331';
  v_mateo_user      uuid := '33333333-3333-4333-8333-333333333332';
  v_sofia_user      uuid := '33333333-3333-4333-8333-333333333333';
  v_benjamin_user   uuid := '33333333-3333-4333-8333-333333333334';
  v_valentina_user  uuid := '33333333-3333-4333-8333-333333333335';
  v_joaquin_user    uuid := '33333333-3333-4333-8333-333333333336';

  v_santiago   uuid;
  v_carolina   uuid;
  v_pablo      uuid;
  v_andrea     uuid;
  v_martin     uuid;
  v_laura      uuid;

  v_lucia      uuid;
  v_mateo      uuid;
  v_sofia      uuid;
  v_benjamin   uuid;
  v_valentina  uuid;
  v_joaquin    uuid;

  v_c1a uuid := 'c0000000-0000-4000-8000-000000000001';
  v_c2a uuid := 'c0000000-0000-4000-8000-000000000002';
  v_c2b uuid := 'c0000000-0000-4000-8000-000000000003';
  v_c3a uuid := 'c0000000-0000-4000-8000-000000000004';
  v_c3b uuid := 'c0000000-0000-4000-8000-000000000005';
  v_c4a uuid := 'c0000000-0000-4000-8000-000000000006';

  v_m_mate  uuid := 'a0000000-0000-4000-8000-000000000001';
  v_m_leng  uuid := 'a0000000-0000-4000-8000-000000000002';
  v_m_nat   uuid := 'a0000000-0000-4000-8000-000000000003';
  v_m_hist  uuid := 'a0000000-0000-4000-8000-000000000004';
  v_m_geo   uuid := 'a0000000-0000-4000-8000-000000000005';
  v_m_ing   uuid := 'a0000000-0000-4000-8000-000000000006';
  v_m_ef    uuid := 'a0000000-0000-4000-8000-000000000007';
  v_m_bio   uuid := 'a0000000-0000-4000-8000-000000000008';

  v_act_sistema uuid;
  v_act_lengua  uuid;
begin
  if exists (select 1 from public.usuarios) then
    raise notice 'Seed omitido: la base ya contiene usuarios.';
    return;
  end if;

  -- -------------------------------------------------------------------------
  -- 1. Cuentas en auth.users. El trigger handle_new_user crea usuarios y
  --    el perfil de alumno/profesor correspondiente.
  -- -------------------------------------------------------------------------
  for r in
    select * from (values
      (v_admin_user,     'admin@colegiogest.edu.ar',     'María Fernanda', 'Gómez',    '30111222', 'administrador'),
      (v_santiago_user,  'profesor@colegiogest.edu.ar',  'Santiago',       'López',    '32444555', 'profesor'),
      (v_carolina_user,  'carolina.diaz@colegiogest.edu.ar', 'Carolina',   'Díaz',     '31555666', 'profesor'),
      (v_pablo_user,     'pablo.acosta@colegiogest.edu.ar',  'Pablo',      'Acosta',   '33666777', 'profesor'),
      (v_andrea_user,    'andrea.molina@colegiogest.edu.ar', 'Andrea',     'Molina',   '29777888', 'profesor'),
      (v_martin_user,    'martin.sosa@colegiogest.edu.ar',   'Martín',     'Sosa',     '34888999', 'profesor'),
      (v_laura_user,     'laura.benitez@colegiogest.edu.ar', 'Laura',      'Benítez',  '35999000', 'profesor'),
      (v_lucia_user,     'alumno@colegiogest.edu.ar',       'Lucía',      'Fernández','45231890', 'alumno'),
      (v_mateo_user,     'mateo.ramirez@email.com',         'Mateo',      'Ramírez',  '46108324', 'alumno'),
      (v_sofia_user,     'sofia.martinez@email.com',        'Sofía',      'Martínez', '44902156', 'alumno'),
      (v_benjamin_user,  'benjamin.torres@email.com',       'Benjamín',   'Torres',   '45770219', 'alumno'),
      (v_valentina_user, 'valentina.castro@email.com',      'Valentina',  'Castro',   '43665872', 'alumno'),
      (v_joaquin_user,   'joaquin.herrera@email.com',       'Joaquín',    'Herrera',  '46314508', 'alumno')
    ) as v(user_id, correo, nombre, apellido, dni, rol)
  loop
    v_id := r.user_id::uuid;

    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      v_id,
      '00000000-0000-0000-0000-000000000000'::uuid,
      'authenticated',
      'authenticated',
      r.correo,
      extensions.crypt('demo123', extensions.gen_salt('bf')),
      now(),
      jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
      jsonb_build_object('nombre', r.nombre, 'apellido', r.apellido, 'dni', r.dni, 'rol', r.rol),
      now(), now(), '', '', '', ''
    );

    insert into auth.identities (
      user_id, identity_data, provider, provider_id,
      last_sign_in_at, created_at, updated_at
    ) values (
      v_id,
      jsonb_build_object('sub', v_id::text, 'email', r.correo, 'email_verified', true),
      'email',
      v_id::text,
      now(), now(), now()
    );
  end loop;

  -- Datos complementarios de alumnos.
  update public.alumnos set fecha_nacimiento = '2008-05-14', telefono = '11-5555-1001'
   where id_usuario = v_lucia_user;
  update public.alumnos set fecha_nacimiento = '2008-09-02', telefono = '11-5555-1002'
   where id_usuario = v_mateo_user;
  update public.alumnos set fecha_nacimiento = '2009-03-21', telefono = '11-5555-1003'
   where id_usuario = v_sofia_user;
  update public.alumnos set fecha_nacimiento = '2007-11-30', telefono = '11-5555-1004'
   where id_usuario = v_benjamin_user;
  update public.alumnos set fecha_nacimiento = '2008-07-08', telefono = '11-5555-1005'
   where id_usuario = v_valentina_user;
  update public.alumnos set fecha_nacimiento = '2009-01-19', telefono = '11-5555-1006'
   where id_usuario = v_joaquin_user;

  select id into v_santiago from public.profesores where id_usuario = v_santiago_user;
  select id into v_carolina from public.profesores where id_usuario = v_carolina_user;
  select id into v_pablo    from public.profesores where id_usuario = v_pablo_user;
  select id into v_andrea   from public.profesores where id_usuario = v_andrea_user;
  select id into v_martin   from public.profesores where id_usuario = v_martin_user;
  select id into v_laura    from public.profesores where id_usuario = v_laura_user;

  select id into v_lucia     from public.alumnos where id_usuario = v_lucia_user;
  select id into v_mateo     from public.alumnos where id_usuario = v_mateo_user;
  select id into v_sofia     from public.alumnos where id_usuario = v_sofia_user;
  select id into v_benjamin  from public.alumnos where id_usuario = v_benjamin_user;
  select id into v_valentina from public.alumnos where id_usuario = v_valentina_user;
  select id into v_joaquin   from public.alumnos where id_usuario = v_joaquin_user;

  -- -------------------------------------------------------------------------
  -- 2. Cursos y materias.
  -- -------------------------------------------------------------------------
  insert into public.cursos (id, anio, division, turno) values
    (v_c1a, 1, 'A', 'mañana'),
    (v_c2a, 2, 'A', 'mañana'),
    (v_c2b, 2, 'B', 'tarde'),
    (v_c3a, 3, 'A', 'mañana'),
    (v_c3b, 3, 'B', 'tarde'),
    (v_c4a, 4, 'A', 'mañana');

  insert into public.materias (id, nombre, descripcion) values
    (v_m_mate, 'Matemática', 'Números, álgebra, funciones y geometría.'),
    (v_m_leng, 'Lengua y Literatura', 'Lectura, escritura y análisis literario.'),
    (v_m_nat,  'Ciencias Naturales', 'Biología, física y química.'),
    (v_m_hist, 'Historia', 'Historia argentina y latinoamericana.'),
    (v_m_geo,  'Geografía', 'Territorio, ambiente y población.'),
    (v_m_ing,  'Inglés', 'Comunicación oral y escrita en inglés.'),
    (v_m_ef,   'Educación Física', 'Deporte y desarrollo corporal.'),
    (v_m_bio,  'Biología', 'Seres vivos y procesos biológicos.');

  -- -------------------------------------------------------------------------
  -- 3. Asignaciones docente · materia · curso · año lectivo.
  -- -------------------------------------------------------------------------
  insert into public.asignaciones (id_materia, id_curso, id_profesor, anio_lectivo) values
    (v_m_mate, v_c3a, v_santiago, 2026),
    (v_m_mate, v_c3b, v_santiago, 2026),
    (v_m_mate, v_c2a, v_santiago, 2026),
    (v_m_leng, v_c3a, v_carolina, 2026),
    (v_m_leng, v_c3b, v_carolina, 2026),
    (v_m_leng, v_c2a, v_carolina, 2026),
    (v_m_nat,  v_c3a, v_pablo,    2026),
    (v_m_bio,  v_c4a, v_pablo,    2026),
    (v_m_hist, v_c3a, v_andrea,   2026),
    (v_m_hist, v_c3b, v_andrea,   2026),
    (v_m_hist, v_c4a, v_andrea,   2026),
    (v_m_geo,  v_c2b, v_andrea,   2026),
    (v_m_geo,  v_c2a, v_andrea,   2026),
    (v_m_ing,  v_c3a, v_martin,   2026),
    (v_m_ing,  v_c1a, v_martin,   2026),
    (v_m_ef,   v_c3a, v_laura,    2026),
    (v_m_ef,   v_c1a, v_laura,    2026);

  -- -------------------------------------------------------------------------
  -- 4. Inscripciones activas (historial 2026).
  -- -------------------------------------------------------------------------
  insert into public.inscripciones (id_alumno, id_curso, fecha_inscripcion, estado) values
    (v_lucia,     v_c3a, '2026-03-02', 'activa'),
    (v_mateo,     v_c3a, '2026-03-02', 'activa'),
    (v_sofia,     v_c2b, '2026-03-02', 'activa'),
    (v_benjamin,  v_c4a, '2026-03-02', 'activa'),
    (v_valentina, v_c3b, '2026-03-02', 'activa'),
    (v_joaquin,   v_c2a, '2026-03-02', 'activa');

  -- -------------------------------------------------------------------------
  -- 5. Calificaciones.
  -- -------------------------------------------------------------------------
  insert into public.calificaciones (id_alumno, id_materia, id_profesor, tipo_instancia, nota, fecha, observacion) values
    (v_lucia, v_m_mate, v_santiago, 'Trabajo práctico 1', 9,  '2026-10-28', 'Muy buen desempeño.'),
    (v_lucia, v_m_mate, v_santiago, 'Evaluación parcial', 8, '2026-10-14', null),
    (v_lucia, v_m_leng, v_carolina, 'Lectura comprensiva', 10, '2026-10-21', 'Excelente análisis.'),
    (v_lucia, v_m_nat,  v_pablo,   'Sistema respiratorio', 7, '2026-10-10', 'Revisar vocabulario específico.'),
    (v_mateo, v_m_mate, v_santiago, 'Trabajo práctico 1', 7,  '2026-10-28', null),
    (v_sofia, v_m_geo,  v_andrea,  'Mapa de relieves', 8, '2026-10-22', null),
    (v_benjamin, v_m_bio, v_pablo, 'Célula', 9, '2026-10-16', null),
    (v_valentina, v_m_mate, v_santiago, 'Trabajo práctico 1', 6, '2026-10-28', 'Aprobado.'),
    (v_joaquin, v_m_mate, v_santiago, 'Trabajo práctico 1', 8, '2026-10-28', null);

  -- -------------------------------------------------------------------------
  -- 6. Asistencias del 5 de noviembre de 2026.
  -- -------------------------------------------------------------------------
  insert into public.asistencias (id_alumno, id_curso, id_materia, id_profesor, fecha, estado) values
    (v_lucia,     v_c3a, v_m_mate, v_santiago, '2026-11-05', 'presente'),
    (v_mateo,     v_c3a, v_m_mate, v_santiago, '2026-11-05', 'tardanza'),
    (v_lucia,     v_c3a, v_m_leng, v_carolina, '2026-11-05', 'presente'),
    (v_joaquin,   v_c2a, v_m_mate, v_santiago, '2026-11-05', 'ausente'),
    (v_valentina, v_c3b, v_m_mate, v_santiago, '2026-11-05', 'justificada');

  -- -------------------------------------------------------------------------
  -- 7. Actividades.
  -- -------------------------------------------------------------------------
  insert into public.actividades (titulo, descripcion, fecha_entrega, id_materia, id_curso, id_profesor, fecha_publicacion) values
    ('Ecuaciones de primer grado', 'Resolver los ejercicios 1 al 12 de la guía entregada en clase.', '2026-11-12', v_m_mate, v_c3a, v_santiago, '2026-11-01 09:00:00-03'),
    ('Sistema de ecuaciones', 'Resolver la situación problemática y explicar el procedimiento.', '2026-11-20', v_m_mate, v_c3a, v_santiago, '2026-11-05 09:00:00-03'),
    ('Lectura: El matadero', 'Leer la obra y preparar una breve reflexión para el próximo encuentro.', '2026-11-14', v_m_leng, v_c3a, v_carolina, '2026-11-02 10:00:00-03'),
    ('Sistema respiratorio', 'Completar el esquema y responder las preguntas de la actividad.', '2026-11-08', v_m_nat, v_c3a, v_pablo, '2026-10-30 08:00:00-03'),
    ('Números enteros', 'Resolver la ejercitación de la unidad 3.', '2026-11-18', v_m_mate, v_c2a, v_santiago, '2026-11-03 11:00:00-03');

  select id into v_act_sistema from public.actividades where titulo = 'Sistema respiratorio' limit 1;
  select id into v_act_lengua  from public.actividades where titulo = 'Lectura: El matadero' limit 1;

  insert into public.entregas_actividades (id_actividad, id_alumno, estado, fecha_entrega) values
    (v_act_sistema, v_lucia, 'entregada', '2026-11-06 19:30:00-03');

  -- -------------------------------------------------------------------------
  -- 8. Avisos.
  -- -------------------------------------------------------------------------
  insert into public.avisos (titulo, contenido, categoria, fecha_publicacion, id_autor, id_curso_destino) values
    ('Reunión de familias', 'Los esperamos el jueves 12 de noviembre a las 18:00 en el salón de actos.', 'institucional', '2026-11-04 08:00:00-03', v_admin_user, null),
    ('Material para Matemática', 'Ya está disponible la guía de ejercicios para la evaluación integradora.', 'academico', '2026-11-03 09:00:00-03', v_santiago_user, v_c3a),
    ('Jornada deportiva', 'El viernes 20 tendremos nuestra jornada deportiva anual. ¡Los esperamos!', 'evento', '2026-11-01 10:00:00-03', v_admin_user, null),
    ('Lectura para el jueves', 'Recuerden traer el texto seleccionado para el taller de lectura.', 'academico', '2026-11-05 11:00:00-03', v_carolina_user, v_c3a);

  raise notice 'Seed de ColegioGest cargado correctamente.';
end
$$;

