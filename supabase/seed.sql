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
