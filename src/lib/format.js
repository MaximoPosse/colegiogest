export function courseLabel(curso) {
  if (!curso) return 'Sin curso'
  return `${curso.anio}.º ${curso.division}`
}

export function courseLongLabel(curso) {
  if (!curso) return 'Sin curso'
  const turno = curso.turno ? ` · Turno ${curso.turno}` : ''
  return `${curso.anio}.º año · División ${curso.division}${turno}`
}

export function normalizeDni(value = '') {
  return String(value).replace(/\D/g, '')
}

export function formatDni(value = '') {
  const digits = normalizeDni(value)
  if (!digits) return ''
  return new Intl.NumberFormat('es-AR').format(Number(digits))
}

export function fullName(nombre = '', apellido = '') {
  return `${nombre} ${apellido}`.trim()
}

export function initials(nombre = '', apellido = '') {
  return `${nombre.charAt(0)}${apellido.charAt(0)}`.toUpperCase()
}

export function capitalize(value = '') {
  return value ? value.charAt(0).toUpperCase() + value.slice(1) : ''
}

export function parseDate(value) {
  if (!value) return null
  if (value instanceof Date) return value
  const normalized = String(value)
  return new Date(normalized.length === 10 ? `${normalized}T12:00:00` : normalized)
}

export function formatDate(value, options = {}) {
  const date = parseDate(value)
  if (!date || Number.isNaN(date.getTime())) return '—'
  return date.toLocaleDateString('es-AR', { day: '2-digit', month: 'short', year: 'numeric', ...options })
}

export function formatLongDate(value) {
  const date = parseDate(value)
  if (!date || Number.isNaN(date.getTime())) return '—'
  return date.toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
}

export function formatDateTime(value) {
  const date = parseDate(value)
  if (!date || Number.isNaN(date.getTime())) return '—'
  return date.toLocaleString('es-AR', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

export function todayIso() {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Argentina/Buenos_Aires' }).format(new Date())
}

export function todayLongLabel() {
  return new Intl.DateTimeFormat('es-AR', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    timeZone: 'America/Argentina/Buenos_Aires',
  }).format(new Date())
}

export function gradeTone(nota) {
  return Number(nota) >= 6 ? 'pass' : 'fail'
}

export function porcentaje(value) {
  return `${Math.round(Number(value) || 0)}%`
}
