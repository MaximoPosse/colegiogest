export const demoUsers = [
  {
    id: 'u-admin',
    name: 'María Fernanda',
    surname: 'Gómez',
    email: 'admin@colegiogest.edu.ar',
    role: 'administrador',
    initials: 'MG',
    title: 'Administración',
  },
  {
    id: 'u-teacher',
    name: 'Santiago',
    surname: 'López',
    email: 'profesor@colegiogest.edu.ar',
    role: 'profesor',
    initials: 'SL',
    title: 'Profesor de Matemática',
  },
  {
    id: 'u-student',
    name: 'Lucía',
    surname: 'Fernández',
    email: 'alumno@colegiogest.edu.ar',
    role: 'alumno',
    initials: 'LF',
    title: '3.º año · División A',
  },
]

export const initialStudents = [
  { id: 'a-01', name: 'Lucía', surname: 'Fernández', dni: '45.231.890', email: 'lucia.fernandez@email.com', course: '3.º A', status: 'Activo' },
  { id: 'a-02', name: 'Mateo', surname: 'Ramírez', dni: '46.108.324', email: 'mateo.ramirez@email.com', course: '3.º A', status: 'Activo' },
  { id: 'a-03', name: 'Sofía', surname: 'Martínez', dni: '44.902.156', email: 'sofia.martinez@email.com', course: '2.º B', status: 'Activo' },
  { id: 'a-04', name: 'Benjamín', surname: 'Torres', dni: '45.770.219', email: 'benjamin.torres@email.com', course: '4.º A', status: 'Activo' },
  { id: 'a-05', name: 'Valentina', surname: 'Castro', dni: '43.665.872', email: 'valentina.castro@email.com', course: '3.º B', status: 'Inactivo' },
  { id: 'a-06', name: 'Joaquín', surname: 'Herrera', dni: '46.314.508', email: 'joaquin.herrera@email.com', course: '2.º A', status: 'Activo' },
]

export const initialCourses = [
  { id: 'c-01', name: '1.º año', division: 'A', shift: 'Mañana', students: 28 },
  { id: 'c-02', name: '2.º año', division: 'A', shift: 'Mañana', students: 26 },
  { id: 'c-03', name: '2.º año', division: 'B', shift: 'Tarde', students: 24 },
  { id: 'c-04', name: '3.º año', division: 'A', shift: 'Mañana', students: 27 },
  { id: 'c-05', name: '3.º año', division: 'B', shift: 'Tarde', students: 25 },
  { id: 'c-06', name: '4.º año', division: 'A', shift: 'Mañana', students: 23 },
]

export const initialSubjects = [
  { id: 'm-01', name: 'Matemática', teacher: 'Santiago López', course: '3.º A', schedule: 'Lun. y mié. · 08:00' },
  { id: 'm-02', name: 'Lengua y Literatura', teacher: 'Carolina Díaz', course: '3.º A', schedule: 'Mar. y jue. · 09:30' },
  { id: 'm-03', name: 'Ciencias Naturales', teacher: 'Pablo Acosta', course: '3.º A', schedule: 'Vie. · 10:00' },
  { id: 'm-04', name: 'Historia', teacher: 'Andrea Molina', course: '3.º A', schedule: 'Lun. · 11:00' },
]

export const initialActivities = [
  { id: 'act-01', title: 'Ecuaciones de primer grado', subject: 'Matemática', course: '3.º A', dueDate: '2026-11-12', description: 'Resolver los ejercicios 1 al 12 de la guía entregada en clase.', status: 'Pendiente' },
  { id: 'act-02', title: 'Lectura: El matadero', subject: 'Lengua y Literatura', course: '3.º A', dueDate: '2026-11-14', description: 'Leer la obra y preparar una breve reflexión para el próximo encuentro.', status: 'Pendiente' },
  { id: 'act-03', title: 'Sistema respiratorio', subject: 'Ciencias Naturales', course: '3.º A', dueDate: '2026-11-08', description: 'Actividad entregada. Revisá las observaciones de la profesora.', status: 'Entregada' },
]

export const initialNotices = [
  { id: 'av-01', title: 'Reunión de familias', category: 'Institucional', date: '2026-11-04', audience: 'Toda la comunidad', author: 'Dirección', body: 'Los esperamos el jueves 12 de noviembre a las 18:00 en el salón de actos.' },
  { id: 'av-02', title: 'Material para Matemática', category: 'Académico', date: '2026-11-03', audience: '3.º A', author: 'Santiago López', body: 'Ya está disponible la guía de ejercicios para la evaluación integradora.' },
  { id: 'av-03', title: 'Jornada deportiva', category: 'Evento', date: '2026-11-01', audience: 'Toda la comunidad', author: 'Coordinación', body: 'El viernes 20 tendremos nuestra jornada deportiva anual. ¡Los esperamos!' },
]

export const initialGrades = [
  { id: 'n-01', studentId: 'a-01', student: 'Lucía Fernández', subject: 'Matemática', instance: 'Trabajo práctico 1', date: '2026-10-28', grade: 9, teacher: 'Santiago López' },
  { id: 'n-02', studentId: 'a-01', student: 'Lucía Fernández', subject: 'Matemática', instance: 'Evaluación parcial', date: '2026-10-14', grade: 8, teacher: 'Santiago López' },
  { id: 'n-03', studentId: 'a-01', student: 'Lucía Fernández', subject: 'Lengua y Literatura', instance: 'Lectura comprensiva', date: '2026-10-21', grade: 10, teacher: 'Carolina Díaz' },
  { id: 'n-04', studentId: 'a-01', student: 'Lucía Fernández', subject: 'Ciencias Naturales', instance: 'Sistema respiratorio', date: '2026-10-10', grade: 7, teacher: 'Pablo Acosta' },
  { id: 'n-05', studentId: 'a-02', student: 'Mateo Ramírez', subject: 'Matemática', instance: 'Trabajo práctico 1', date: '2026-10-28', grade: 7, teacher: 'Santiago López' },
]

export const initialAttendance = [
  { id: 'as-01', studentId: 'a-01', date: '2026-11-05', course: '3.º A', subject: 'Matemática', status: 'Presente' },
  { id: 'as-02', studentId: 'a-02', date: '2026-11-05', course: '3.º A', subject: 'Matemática', status: 'Tardanza' },
  { id: 'as-03', studentId: 'a-03', date: '2026-11-05', course: '3.º A', subject: 'Matemática', status: 'Ausente' },
  { id: 'as-04', studentId: 'a-04', date: '2026-11-05', course: '3.º A', subject: 'Matemática', status: 'Presente' },
  { id: 'as-05', studentId: 'a-05', date: '2026-11-05', course: '3.º A', subject: 'Matemática', status: 'Justificada' },
]

export const initialEnrollments = [
  { id: 'ins-01', studentId: 'a-01', student: 'Lucía Fernández', course: '3.º A', date: '2026-03-02' },
  { id: 'ins-02', studentId: 'a-02', student: 'Mateo Ramírez', course: '3.º A', date: '2026-03-02' },
]
