import { reactive } from 'vue'
import { supabase, isSupabaseConfigured } from '../lib/supabase'
import { describeError } from '../lib/errors'
import { capitalize, courseLongLabel, fullName, initials } from '../lib/format'

const PROFILE_SELECT = `
  id, nombre, apellido, dni, correo, rol, estado, fecha_alta,
  alumnos (
    id, estado, fecha_nacimiento, telefono,
    inscripciones ( id, id_curso, estado, fecha_inscripcion, cursos ( anio, division, turno ) )
  ),
  profesores ( id, estado )
`

export const session = reactive({
  ready: false,
  configured: isSupabaseConfigured,
  user: null,
  profile: null,
  error: '',
})

let initialized = false
let loadingProfile = null

function first(value) {
  if (Array.isArray(value)) return value[0] ?? null
  return value ?? null
}

function mapProfile(profile) {
  const alumno = first(profile.alumnos)
  const profesor = first(profile.profesores)
  const inscripciones = alumno?.inscripciones ?? []
  const inscripcion = (Array.isArray(inscripciones) ? inscripciones : [inscripciones]).find(
    (item) => item?.estado === 'activa',
  )
  const curso = first(inscripcion?.cursos)

  const title =
    profile.rol === 'administrador'
      ? 'Administración general'
      : profile.rol === 'profesor'
        ? 'Docente'
        : curso
          ? courseLongLabel(curso)
          : 'Estudiante'

  return {
    id: profile.id,
    name: profile.nombre,
    surname: profile.apellido,
    fullName: fullName(profile.nombre, profile.apellido),
    dni: profile.dni,
    email: profile.correo,
    role: profile.rol,
    roleLabel: capitalize(profile.rol),
    estado: profile.estado,
    initials: initials(profile.nombre, profile.apellido),
    title,
    fechaAlta: profile.fecha_alta,
    alumnoId: alumno?.id ?? null,
    profesorId: profesor?.id ?? null,
    curso: curso ?? null,
    inscripcion: inscripcion ?? null,
  }
}

function clearSession() {
  session.user = null
  session.profile = null
}

async function loadProfile(userId) {
  if (!supabase) throw new Error('Supabase no está configurado.')
  if (loadingProfile) return loadingProfile

  loadingProfile = (async () => {
    const { data, error } = await supabase
      .from('usuarios')
      .select(PROFILE_SELECT)
      .eq('id', userId)
      .maybeSingle()

    if (error) throw error

    if (!data) {
      await supabase.auth.signOut().catch(() => {})
      clearSession()
      throw new Error(
        'Tu cuenta no tiene un perfil configurado en ColegioGest. Contactá a la administración.',
      )
    }

    if (data.estado !== 'activo') {
      await supabase.auth.signOut().catch(() => {})
      clearSession()
      throw new Error('Tu cuenta está desactivada. Contactá a la administración del colegio.')
    }

    session.profile = data
    session.user = mapProfile(data)
    session.error = ''
    return session.user
  })()

  try {
    return await loadingProfile
  } finally {
    loadingProfile = null
  }
}

export async function initAuth() {
  if (initialized) return session
  initialized = true

  if (!supabase) {
    session.ready = true
    session.error =
      'Supabase no está configurado. Completá VITE_SUPABASE_URL y VITE_SUPABASE_ANON_KEY en el archivo .env.'
    return session
  }

  try {
    const { data, error } = await supabase.auth.getSession()
    if (error) throw error
    if (data.session?.user) {
      try {
        await loadProfile(data.session.user.id)
      } catch (error) {
        session.error = describeError(error)
        await supabase.auth.signOut().catch(() => {})
        clearSession()
      }
    }
  } catch (error) {
    session.error = describeError(error)
  } finally {
    session.ready = true
  }

  supabase.auth.onAuthStateChange((event, newSession) => {
    if (event === 'SIGNED_OUT') {
      clearSession()
      return
    }
    if (
      (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED' || event === 'USER_UPDATED') &&
      newSession?.user &&
      session.user?.id !== newSession.user.id
    ) {
      // No se deben hacer consultas a Supabase dentro del callback de auth.
      setTimeout(() => {
        loadProfile(newSession.user.id).catch((error) => {
          session.error = describeError(error)
        })
      }, 0)
    }
  })

  return session
}

export async function signIn(email, password) {
  if (!supabase) throw new Error('Supabase no está configurado.')
  session.error = ''
  const { data, error } = await supabase.auth.signInWithPassword({
    email: String(email).trim().toLowerCase(),
    password,
  })
  if (error) throw error
  return loadProfile(data.user.id)
}

export async function signOut() {
  if (supabase) await supabase.auth.signOut()
  clearSession()
}

export async function recoverPassword(email) {
  if (!supabase) throw new Error('Supabase no está configurado.')
  const redirectTo = `${window.location.origin}/restablecer`
  const { error } = await supabase.auth.resetPasswordForEmail(String(email).trim().toLowerCase(), {
    redirectTo,
  })
  if (error) throw error
}

export async function updatePassword(password) {
  if (!supabase) throw new Error('Supabase no está configurado.')
  const { error } = await supabase.auth.updateUser({ password })
  if (error) throw error
}

export async function refreshProfile() {
  if (!supabase) return null
  const { data } = await supabase.auth.getUser()
  if (!data?.user) return null
  return loadProfile(data.user.id)
}

export function roleHome() {
  return session.user ? '/app' : '/login'
}
