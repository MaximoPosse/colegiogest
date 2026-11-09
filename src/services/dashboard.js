import { requireSupabase } from '../lib/supabase'
import { todayIso } from '../lib/format'
import { fetchActivities, fetchAssignments, fetchDeliveries, fetchGrades, fetchNotices, fetchStudents } from './school'

function db() {
  return requireSupabase()
}

async function countRows(table, configure) {
  let query = db().from(table).select('id', { count: 'exact', head: true })
  if (configure) query = configure(query)
  const { count, error } = await query
  if (error) throw error
  return count ?? 0
}

async function loadStudentDashboard(user) {
  const [grades, notices, activities, deliveries, attendance] = await Promise.all([
    fetchGrades(),
    fetchNotices(),
    fetchActivities(),
    fetchDeliveries(),
    db().from('v_asistencias').select('*').eq('id_alumno', user.alumnoId),
  ])
  if (attendance.error) throw attendance.error

  const deliveredIds = new Set(deliveries.map((item) => item.activityId))
  const pending = activities.filter((activity) => !deliveredIds.has(activity.id) && activity.status === 'Pendiente')
  const average = grades.length
    ? grades.reduce((sum, item) => sum + Number(item.grade), 0) / grades.length
    : null

  const attendanceRows = attendance.data ?? []
  const attended = attendanceRows.filter((item) => item.estado === 'presente').length
  const attendanceRate = attendanceRows.length ? (attended / attendanceRows.length) * 100 : null

  const subjects = user.inscripcion?.id_curso
    ? await fetchAssignments({ courseId: user.inscripcion.id_curso })
    : []

  return {
    role: 'alumno',
    stats: [
      {
        label: 'Mis materias',
        value: subjects.length,
        detail: user.curso ? `${user.curso.anio}.º año · División ${user.curso.division}` : 'Sin curso activo',
        icon: 'BookOpen',
        tone: 'blue',
      },
      {
        label: 'Promedio general',
        value: average === null ? '—' : average.toLocaleString('es-AR', { minimumFractionDigits: 1, maximumFractionDigits: 1 }),
        detail: 'Sobre 10 puntos',
        icon: 'TrendingUp',
        tone: 'green',
      },
      {
        label: 'Asistencia',
        value: attendanceRate === null ? '—' : `${Math.round(attendanceRate)}%`,
        detail: 'Registros del ciclo',
        icon: 'CalendarCheck',
        tone: 'rose',
      },
      {
        label: 'Actividades pendientes',
        value: pending.length,
        detail: 'Próximas entregas',
        icon: 'ClipboardList',
        tone: 'amber',
      },
    ],
    notices: notices.slice(0, 3),
    upcoming: pending.slice(0, 3),
    agenda: subjects.slice(0, 3).map((item) => ({
      time: '',
      title: item.subject,
      detail: `${item.course} · ${item.teacher}`,
    })),
  }
}

async function loadTeacherDashboard(user) {
  const assignments = await fetchAssignments({ teacherId: user.profesorId })
  const courseIds = [...new Set(assignments.map((item) => item.courseId).filter(Boolean))]
  const [notices, activities, students] = await Promise.all([
    fetchNotices(),
    fetchActivities(),
    courseIds.length ? fetchStudents() : Promise.resolve([]),
  ])

  const myStudents = students.filter((student) => courseIds.includes(student.courseId))
  const today = todayIso()

  let presentToday = 0
  if (user.profesorId) {
    const { count, error } = await db()
      .from('v_asistencias')
      .select('id', { count: 'exact', head: true })
      .eq('fecha', today)
      .eq('id_profesor', user.profesorId)
      .eq('estado', 'presente')
    if (error) throw error
    presentToday = count ?? 0
  }

  const pendingActivities = activities.filter(
    (activity) => activity.teacherId === user.profesorId && activity.dueDate >= today,
  )

  return {
    role: 'profesor',
    stats: [
      {
        label: 'Mis cursos',
        value: courseIds.length,
        detail: 'Con asignaciones este ciclo',
        icon: 'BookOpen',
        tone: 'blue',
      },
      {
        label: 'Alumnos',
        value: myStudents.length,
        detail: 'En cursos asignados',
        icon: 'Users',
        tone: 'green',
      },
      {
        label: 'Presentes hoy',
        value: presentToday,
        detail: 'Registros propios del día',
        icon: 'CalendarCheck',
        tone: 'rose',
      },
      {
        label: 'Actividades vigentes',
        value: pendingActivities.length,
        detail: 'Con entrega próxima',
        icon: 'ClipboardList',
        tone: 'amber',
      },
    ],
    notices: notices.slice(0, 3),
    upcoming: pendingActivities.slice(0, 3),
    agenda: assignments.slice(0, 3).map((item) => ({
      time: '',
      title: item.subject,
      detail: `${item.course} · ${item.teacher}`,
    })),
  }
}

async function loadAdminDashboard() {
  const [students, courses, teachers, noticesCount, notices] = await Promise.all([
    countRows('v_alumnos', (query) => query.eq('estado', 'activo')),
    countRows('v_cursos'),
    countRows('v_profesores', (query) => query.eq('estado', 'activo')),
    countRows('v_avisos'),
    fetchNotices(),
  ])

  return {
    role: 'administrador',
    stats: [
      { label: 'Alumnos activos', value: students, detail: 'En la institución', icon: 'Users', tone: 'blue' },
      { label: 'Cursos', value: courses, detail: 'En ambos turnos', icon: 'BookOpen', tone: 'green' },
      { label: 'Profesores', value: teachers, detail: 'En actividad', icon: 'GraduationCap', tone: 'rose' },
      { label: 'Avisos publicados', value: noticesCount, detail: 'Visibles para la comunidad', icon: 'Megaphone', tone: 'amber' },
    ],
    notices: notices.slice(0, 3),
    upcoming: [],
    agenda: [],
  }
}

export async function fetchDashboard(user) {
  if (!user) throw new Error('No hay una sesión activa.')
  if (user.role === 'administrador') return loadAdminDashboard()
  if (user.role === 'profesor') return loadTeacherDashboard(user)
  return loadStudentDashboard(user)
}

export async function fetchStudentOverview(user) {
  if (!user?.alumnoId) return { subjects: [], grades: [], attendance: [], average: null, attendanceRate: null, course: null }
  const [grades, attendance, subjects] = await Promise.all([
    fetchGrades(),
    db().from('v_asistencias').select('*').eq('id_alumno', user.alumnoId),
    user.inscripcion?.id_curso ? fetchAssignments({ courseId: user.inscripcion.id_curso }) : Promise.resolve([]),
  ])
  if (attendance.error) throw attendance.error

  const average = grades.length
    ? grades.reduce((sum, item) => sum + Number(item.grade), 0) / grades.length
    : null
  const attendanceRows = attendance.data ?? []
  const attended = attendanceRows.filter((item) => item.estado === 'presente').length
  const attendanceRate = attendanceRows.length ? (attended / attendanceRows.length) * 100 : null

  return {
    subjects,
    grades,
    attendance: attendanceRows,
    average,
    attendanceRate,
    course: user.curso,
  }
}
