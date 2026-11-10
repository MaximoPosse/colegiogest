import { capitalize, courseLabel, courseLongLabel, formatDni } from './format'

export function mapCourse(row) {
  return {
    id: row.id,
    anio: row.anio,
    division: row.division,
    turno: row.turno ? capitalize(row.turno) : 'Sin turno',
    turnoRaw: row.turno,
    name: `${row.anio}.º año`,
    label: courseLabel(row),
    students: Number(row.students_count ?? 0),
    studentsCount: Number(row.students_count ?? 0),
  }
}

export function mapTeacher(row) {
  return {
    id: row.id,
    idUsuario: row.id_usuario,
    name: row.nombre,
    surname: row.apellido,
    fullName: `${row.nombre} ${row.apellido}`,
    email: row.correo,
    dni: row.dni,
    dniDisplay: formatDni(row.dni),
    status: row.estado === 'activo' ? 'Activo' : 'Inactivo',
    estado: row.estado,
  }
}

export function mapUser(row) {
  return {
    id: row.id,
    name: row.nombre,
    surname: row.apellido,
    fullName: `${row.apellido}, ${row.nombre}`,
    email: row.correo,
    dni: row.dni,
    dniDisplay: formatDni(row.dni),
    role: row.rol,
    roleLabel: capitalize(row.rol),
    status: row.estado === 'activo' ? 'Activo' : 'Inactivo',
    estado: row.estado,
    initials: `${row.nombre.charAt(0)}${row.apellido.charAt(0)}`.toUpperCase(),
    fechaAlta: row.fecha_alta,
  }
}

export function mapStudent(row) {
  const hasCourse = Boolean(row.id_curso)
  const curso = hasCourse ? { anio: row.anio, division: row.division, turno: row.turno } : null
  return {
    id: row.id,
    idUsuario: row.id_usuario,
    name: row.nombre,
    surname: row.apellido,
    fullName: `${row.apellido}, ${row.nombre}`,
    dni: row.dni,
    dniDisplay: formatDni(row.dni),
    email: row.correo,
    status: row.estado === 'activo' ? 'Activo' : 'Inactivo',
    estado: row.estado,
    estadoUsuario: row.estado_usuario,
    courseId: row.id_curso,
    course: hasCourse ? courseLabel(curso) : 'Sin curso',
    courseLong: hasCourse ? courseLongLabel(curso) : 'Sin curso',
    curso,
    enrollmentId: row.id_inscripcion,
    enrollmentDate: row.fecha_inscripcion,
    fechaNacimiento: row.fecha_nacimiento,
    telefono: row.telefono,
  }
}

export function mapEnrollment(row) {
  const curso = { anio: row.anio, division: row.division, turno: row.turno }
  return {
    id: row.id,
    studentId: row.id_alumno,
    student: row.alumno,
    dni: row.dni,
    courseId: row.id_curso,
    course: courseLabel(curso),
    date: row.fecha_inscripcion,
    status: capitalize(row.estado),
    estado: row.estado,
  }
}

export function mapSubject(row) {
  return {
    id: row.id,
    name: row.nombre,
    description: row.descripcion ?? '',
    assignmentCount: Number(row.asignaciones?.[0]?.count ?? row.assignment_count ?? 0),
  }
}

export function mapAssignment(row) {
  const curso = { anio: row.anio, division: row.division, turno: row.turno }
  return {
    id: row.id,
    subjectId: row.id_materia,
    subject: row.materia,
    description: row.descripcion,
    courseId: row.id_curso,
    course: courseLabel(curso),
    courseLong: courseLongLabel(curso),
    teacherId: row.id_profesor,
    teacher: row.profesor,
    teacherEmail: row.profesor_correo,
    year: row.anio_lectivo,
    schedule: 'Horario a definir',
  }
}

export function mapGrade(row) {
  const curso = { anio: row.anio, division: row.division, turno: row.turno }
  return {
    id: row.id,
    studentId: row.id_alumno,
    student: row.alumno,
    studentDni: row.alumno_dni,
    subjectId: row.id_materia,
    subject: row.materia,
    teacherId: row.id_profesor,
    teacher: row.profesor,
    instance: row.tipo_instancia,
    grade: Number(row.nota),
    date: row.fecha,
    observation: row.observacion,
    courseId: row.id_curso,
    course: row.id_curso ? courseLabel(curso) : 'Sin curso',
  }
}

export function mapAttendance(row) {
  return {
    id: row.id,
    studentId: row.id_alumno,
    student: row.alumno,
    dni: row.alumno_dni,
    courseId: row.id_curso,
    subjectId: row.id_materia,
    subject: row.materia,
    teacherId: row.id_profesor,
    date: row.fecha,
    status: capitalize(row.estado),
    estado: row.estado,
    observation: row.observacion,
  }
}

export function mapActivity(row) {
  const curso = { anio: row.anio, division: row.division, turno: row.turno }
  return {
    id: row.id,
    title: row.titulo,
    description: row.descripcion,
    dueDate: row.fecha_entrega,
    subjectId: row.id_materia,
    subject: row.materia,
    courseId: row.id_curso,
    course: courseLabel(curso),
    teacherId: row.id_profesor,
    teacher: row.profesor,
    publishedAt: row.fecha_publicacion,
    status: 'Pendiente',
  }
}

export function mapDelivery(row) {
  return {
    id: row.id,
    activityId: row.id_actividad,
    activity: row.actividad,
    studentId: row.id_alumno,
    student: row.alumno,
    status: capitalize(row.estado),
    deliveredAt: row.fecha_entrega,
    comment: row.comentario,
  }
}

const NOTICE_CATEGORY_LABELS = {
  institucional: 'Institucional',
  academico: 'Académico',
  evento: 'Evento',
}

export function mapNotice(row) {
  const curso = row.id_curso_destino
    ? { anio: row.anio, division: row.division, turno: row.turno }
    : null
  return {
    id: row.id,
    title: row.titulo,
    body: row.contenido,
    category: NOTICE_CATEGORY_LABELS[row.categoria] ?? capitalize(row.categoria),
    categoryRaw: row.categoria,
    date: row.fecha_publicacion,
    authorId: row.id_autor,
    author: row.autor,
    courseId: row.id_curso_destino,
    audience: curso ? courseLabel(curso) : 'Toda la comunidad',
  }
}
