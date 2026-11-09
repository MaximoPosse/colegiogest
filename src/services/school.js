import { requireSupabase } from '../lib/supabase'
import {
  mapActivity,
  mapAssignment,
  mapAttendance,
  mapCourse,
  mapDelivery,
  mapEnrollment,
  mapGrade,
  mapNotice,
  mapStudent,
  mapTeacher,
  mapUser,
} from '../lib/mappers'

function db() {
  return requireSupabase()
}

function cleanSearch(value = '') {
  return String(value).replace(/[%,()]/g, ' ').trim()
}

async function run(query) {
  const { data, error } = await query
  if (error) throw error
  return data
}

// ---------------------------------------------------------------------------
// Cursos
// ---------------------------------------------------------------------------
export async function fetchCourses() {
  const data = await run(db().from('v_cursos').select('*').order('anio').order('division'))
  return (data ?? []).map(mapCourse)
}

export async function createCourse({ anio, division, turno }) {
  const data = await run(
    db()
      .from('cursos')
      .insert({ anio: Number(anio), division: String(division).trim().toUpperCase(), turno: turno || null })
      .select('*')
      .single(),
  )
  return mapCourse({ ...data, students_count: 0 })
}

export async function updateCourse(id, { anio, division, turno }) {
  const data = await run(
    db()
      .from('cursos')
      .update({ anio: Number(anio), division: String(division).trim().toUpperCase(), turno: turno || null })
      .eq('id', id)
      .select('*')
      .single(),
  )
  return mapCourse({ ...data, students_count: 0 })
}

export async function deleteCourse(id) {
  return run(db().from('cursos').delete().eq('id', id))
}

// ---------------------------------------------------------------------------
// Profesores / usuarios
// ---------------------------------------------------------------------------
export async function fetchTeachers() {
  const data = await run(
    db().from('v_profesores').select('*').eq('estado', 'activo').order('apellido').order('nombre'),
  )
  return (data ?? []).map(mapTeacher)
}

export async function fetchUsers() {
  const data = await run(
    db()
      .from('usuarios')
      .select('id, nombre, apellido, dni, correo, rol, estado, fecha_alta')
      .order('apellido')
      .order('nombre'),
  )
  return (data ?? []).map(mapUser)
}

export async function setUserStatus(id, estado) {
  return run(
    db().rpc('admin_cambiar_estado_usuario', {
      p_usuario_id: id,
      p_estado: estado,
    }),
  )
}

// ---------------------------------------------------------------------------
// Materias y asignaciones
// ---------------------------------------------------------------------------
export async function fetchAssignments({ courseId, teacherId, year } = {}) {
  let query = db().from('v_asignaciones').select('*').order('materia')
  if (courseId) query = query.eq('id_curso', courseId)
  if (teacherId) query = query.eq('id_profesor', teacherId)
  if (year) query = query.eq('anio_lectivo', year)
  const data = await run(query)
  return (data ?? []).map(mapAssignment)
}

export async function createAssignment({ materia, courseId, teacherId, year, descripcion }) {
  const id = await run(
    db().rpc('admin_crear_asignacion', {
      p_materia_nombre: String(materia).trim(),
      p_curso_id: courseId,
      p_profesor_id: teacherId,
      p_anio_lectivo: Number(year) || new Date().getFullYear(),
      p_descripcion: descripcion || null,
    }),
  )
  return id
}

export async function deleteAssignment(id) {
  return run(db().rpc('admin_eliminar_asignacion', { p_asignacion_id: id }))
}

// ---------------------------------------------------------------------------
// Alumnos
// ---------------------------------------------------------------------------
export async function fetchStudents({ courseId, search } = {}) {
  let query = db().from('v_alumnos').select('*').order('apellido').order('nombre')
  if (courseId) query = query.eq('id_curso', courseId)
  const term = cleanSearch(search)
  if (term) {
    query = query.or(
      `nombre.ilike.%${term}%,apellido.ilike.%${term}%,dni.ilike.%${term}%,correo.ilike.%${term}%`,
    )
  }
  const data = await run(query)
  return (data ?? []).map(mapStudent)
}

export async function fetchStudent(alumnoId) {
  const data = await run(db().from('v_alumnos').select('*').eq('id', alumnoId).maybeSingle())
  return data ? mapStudent(data) : null
}

export async function createStudent(payload) {
  const alumnoId = await run(
    db().rpc('admin_crear_alumno', {
      p_nombre: payload.nombre.trim(),
      p_apellido: payload.apellido.trim(),
      p_dni: payload.dni,
      p_correo: payload.correo.trim().toLowerCase(),
      p_id_curso: payload.idCurso || null,
      p_password: payload.password || 'demo123',
      p_fecha_nacimiento: payload.fechaNacimiento || null,
      p_telefono: payload.telefono || null,
    }),
  )
  return fetchStudent(alumnoId)
}

export async function updateStudent(alumnoId, payload) {
  await run(
    db().rpc('admin_actualizar_alumno', {
      p_alumno_id: alumnoId,
      p_nombre: payload.nombre.trim(),
      p_apellido: payload.apellido.trim(),
      p_dni: payload.dni,
      p_correo: payload.correo.trim().toLowerCase(),
      p_estado: payload.estado,
      p_id_curso: payload.idCurso || null,
      p_fecha_nacimiento: payload.fechaNacimiento || null,
      p_telefono: payload.telefono || null,
    }),
  )
  return fetchStudent(alumnoId)
}

export async function deactivateStudent(alumnoId) {
  return run(db().rpc('admin_baja_alumno', { p_alumno_id: alumnoId }))
}

// ---------------------------------------------------------------------------
// Inscripciones
// ---------------------------------------------------------------------------
export async function fetchEnrollments({ courseId } = {}) {
  let query = db().from('v_inscripciones').select('*').order('fecha_inscripcion', { ascending: false })
  if (courseId) query = query.eq('id_curso', courseId)
  const data = await run(query)
  return (data ?? []).map(mapEnrollment)
}

export async function enrollStudent(alumnoId, courseId) {
  return run(
    db().rpc('admin_inscribir_alumno', {
      p_alumno_id: alumnoId,
      p_curso_id: courseId,
    }),
  )
}

export async function finalizeEnrollment(enrollmentId) {
  return run(
    db().from('inscripciones').update({ estado: 'finalizada' }).eq('id', enrollmentId),
  )
}

// ---------------------------------------------------------------------------
// Calificaciones
// ---------------------------------------------------------------------------
export async function fetchGrades() {
  const data = await run(
    db().from('v_calificaciones').select('*').order('fecha', { ascending: false }),
  )
  return (data ?? []).map(mapGrade)
}

export async function createGrade(payload) {
  return run(
    db()
      .from('calificaciones')
      .insert({
        id_alumno: payload.alumnoId,
        id_materia: payload.materiaId,
        id_profesor: payload.profesorId,
        tipo_instancia: payload.instancia.trim(),
        nota: Number(payload.nota),
        fecha: payload.fecha,
        observacion: payload.observacion?.trim() || null,
      })
      .select('*')
      .single(),
  )
}

export async function updateGrade(id, payload) {
  return run(
    db()
      .from('calificaciones')
      .update({
        tipo_instancia: payload.instancia.trim(),
        nota: Number(payload.nota),
        fecha: payload.fecha,
        observacion: payload.observacion?.trim() || null,
      })
      .eq('id', id)
      .select('*')
      .single(),
  )
}

export async function deleteGrade(id) {
  return run(db().from('calificaciones').delete().eq('id', id))
}

// ---------------------------------------------------------------------------
// Asistencias
// ---------------------------------------------------------------------------
export async function fetchAttendance({ courseId, subjectId, date }) {
  let query = db().from('v_asistencias').select('*').order('alumno')
  if (courseId) query = query.eq('id_curso', courseId)
  if (subjectId) query = query.eq('id_materia', subjectId)
  if (date) query = query.eq('fecha', date)
  const data = await run(query)
  return (data ?? []).map(mapAttendance)
}

export async function saveAttendance(records) {
  if (!records.length) return []
  return run(
    db().from('asistencias').upsert(records, {
      onConflict: 'id_alumno,id_curso,id_materia,fecha',
    }),
  )
}

// ---------------------------------------------------------------------------
// Actividades y entregas
// ---------------------------------------------------------------------------
export async function fetchActivities() {
  const data = await run(
    db().from('v_actividades').select('*').order('fecha_entrega', { ascending: true }),
  )
  return (data ?? []).map(mapActivity)
}

export async function fetchDeliveries() {
  const data = await run(db().from('v_entregas').select('*'))
  return (data ?? []).map(mapDelivery)
}

export async function createActivity(payload) {
  return run(
    db()
      .from('actividades')
      .insert({
        titulo: payload.titulo.trim(),
        descripcion: payload.descripcion.trim(),
        fecha_entrega: payload.fechaEntrega,
        id_materia: payload.materiaId,
        id_curso: payload.cursoId,
        id_profesor: payload.profesorId,
      })
      .select('*')
      .single(),
  )
}

export async function deleteActivity(id) {
  return run(db().from('actividades').delete().eq('id', id))
}

export async function markActivityDelivered(activityId, alumnoId) {
  return run(
    db()
      .from('entregas_actividades')
      .upsert(
        {
          id_actividad: activityId,
          id_alumno: alumnoId,
          estado: 'entregada',
          fecha_entrega: new Date().toISOString(),
        },
        { onConflict: 'id_actividad,id_alumno' },
      ),
  )
}

// ---------------------------------------------------------------------------
// Avisos
// ---------------------------------------------------------------------------
export async function fetchNotices() {
  const data = await run(
    db().from('v_avisos').select('*').order('fecha_publicacion', { ascending: false }),
  )
  return (data ?? []).map(mapNotice)
}

export async function createNotice(payload) {
  return run(
    db()
      .from('avisos')
      .insert({
        titulo: payload.titulo.trim(),
        contenido: payload.contenido.trim(),
        categoria: payload.categoria,
        id_autor: payload.autorId,
        id_curso_destino: payload.cursoId || null,
      })
      .select('*')
      .single(),
  )
}

export async function deleteNotice(id) {
  return run(db().from('avisos').delete().eq('id', id))
}
