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
