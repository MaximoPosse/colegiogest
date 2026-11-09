import { createClient } from '@supabase/supabase-js'

const url = (import.meta.env.VITE_SUPABASE_URL || '').trim()
const anonKey = (import.meta.env.VITE_SUPABASE_ANON_KEY || '').trim()

export const isSupabaseConfigured = Boolean(url && anonKey)

export const supabase = isSupabaseConfigured
  ? createClient(url, anonKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
        storageKey: 'colegiogest-auth',
      },
    })
  : null

export function requireSupabase() {
  if (!supabase) {
    throw new Error(
      'Supabase no está configurado. Completá VITE_SUPABASE_URL y VITE_SUPABASE_ANON_KEY en el archivo .env.',
    )
  }
  return supabase
}
