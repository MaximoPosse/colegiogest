const FRIENDLY_MESSAGES = {
  DUPLICATE_EMAIL: 'Ya existe un usuario registrado con ese correo electrónico.',
  DUPLICATE_DNI: 'Ya existe un usuario registrado con ese DNI.',
  ALUMNO_NO_ENCONTRADO: 'No encontramos el alumno solicitado.',
  CURSO_NO_ENCONTRADO: 'No encontramos el curso solicitado.',
  PROFESOR_NO_ENCONTRADO: 'No encontramos el profesor solicitado.',
  PROFESOR_CON_ASIGNACIONES:
    'El profesor tiene asignaciones vigentes. Reasigná o eliminá esas asignaciones antes de darlo de baja.',
  USUARIO_NO_ENCONTRADO: 'No encontramos el usuario solicitado.',
  ASIGNACION_NO_ENCONTRADA: 'No encontramos la asignación solicitada.',
  ASIGNACION_CON_HISTORIAL:
    'No se puede modificar o eliminar la asignación porque tiene calificaciones, asistencias o actividades asociadas.',
  ASIGNACION_DUPLICADA: 'Ya existe una asignación con esa materia, curso, docente y ciclo lectivo.',
  MATERIA_NO_ENCONTRADA: 'No encontramos la materia solicitada.',
  DUPLICATE_MATERIA: 'Ya existe una materia con ese nombre.',
  MATERIA_CON_ASIGNACIONES:
    'No se puede eliminar la materia porque tiene asignaciones docentes. Eliminá primero esas asignaciones.',
  MATERIA_CON_CALIFICACIONES: 'No se puede eliminar la materia porque tiene calificaciones registradas.',
  MATERIA_CON_ASISTENCIAS: 'No se puede eliminar la materia porque tiene asistencias registradas.',
  MATERIA_CON_ACTIVIDADES: 'No se puede eliminar la materia porque tiene actividades registradas.',
  '23505': 'El registro ya existe. Revisá el correo o el DNI.',
  '23503': 'No se puede eliminar el registro porque está vinculado con otros datos.',
  '42501': 'No tenés permisos para realizar esta operación.',
  '23514': 'Los datos no cumplen una regla de integridad académica.',
}

const AUTH_MESSAGES = {
  'Invalid login credentials': 'Correo o contraseña incorrectos.',
  'Email not confirmed': 'El correo de la cuenta todavía no fue confirmado.',
  'User already registered': 'Ya existe una cuenta con ese correo electrónico.',
  'Password should be at least 6 characters': 'La contraseña debe tener al menos 6 caracteres.',
  'New password should be different from the old password':
    'La nueva contraseña debe ser diferente de la anterior.',
  'Auth session missing!': 'Tu sesión venció. Volvé a iniciar sesión.',
}

export function describeError(error, fallback = 'Ocurrió un error inesperado. Intentá nuevamente.') {
  if (!error) return fallback
  const raw = typeof error === 'string' ? error : error.message || ''
  const code = error.code || error.status || ''

  if (FRIENDLY_MESSAGES[raw]) return FRIENDLY_MESSAGES[raw]
  if (raw && FRIENDLY_MESSAGES[raw.split(':')[0]]) return FRIENDLY_MESSAGES[raw.split(':')[0]]
  if (code && FRIENDLY_MESSAGES[code]) return FRIENDLY_MESSAGES[code]
  if (AUTH_MESSAGES[raw]) return AUTH_MESSAGES[raw]
  if (/duplicate key.*correo/i.test(raw)) return FRIENDLY_MESSAGES.DUPLICATE_EMAIL
  if (/duplicate key.*dni/i.test(raw)) return FRIENDLY_MESSAGES.DUPLICATE_DNI
  if (/row-level security/i.test(raw)) {
    return 'No tenés permisos para acceder a este registro.'
  }
  if (/JWT expired/i.test(raw)) return 'Tu sesión venció. Volvé a iniciar sesión.'
  if (/Failed to fetch|NetworkError|fetch failed/i.test(raw)) {
    return 'No pudimos conectarnos con Supabase. Revisá tu conexión e intentá nuevamente.'
  }
  return raw || fallback
}

export function isDuplicateError(error, field) {
  const raw = typeof error === 'string' ? error : error?.message || ''
  if (field === 'email') return raw.includes('DUPLICATE_EMAIL') || /duplicate key.*correo/i.test(raw)
  if (field === 'dni') return raw.includes('DUPLICATE_DNI') || /duplicate key.*dni/i.test(raw)
  return /duplicate key/i.test(raw)
}
