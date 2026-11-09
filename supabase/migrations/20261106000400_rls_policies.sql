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
