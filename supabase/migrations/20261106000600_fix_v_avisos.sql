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
