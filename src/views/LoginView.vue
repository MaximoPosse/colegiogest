<script setup>
import { computed, reactive, ref } from 'vue'
import { ArrowLeft, ArrowRight, BookOpenCheck, LockKeyhole, Mail, ShieldCheck } from '@lucide/vue'
import { useRoute, useRouter } from 'vue-router'
import BaseButton from '../components/BaseButton.vue'
import FormField from '../components/FormField.vue'
import { describeError } from '../lib/errors'
import { notify } from '../stores/toast'
import { session, signIn } from '../stores/auth'

const route = useRoute()
const router = useRouter()
const form = reactive({ email: '', password: '' })
const errors = reactive({ email: '', password: '', form: '' })
const loading = ref(false)

const demoAccounts = [
  { id: 'admin', name: 'María Fernanda', surname: 'Gómez', email: 'admin@colegiogest.edu.ar', role: 'administrador', initials: 'MG', password: 'demo123' },
  { id: 'teacher', name: 'Santiago', surname: 'López', email: 'profesor@colegiogest.edu.ar', role: 'profesor', initials: 'SL', password: 'demo123' },
  { id: 'student', name: 'Lucía', surname: 'Fernández', email: 'alumno@colegiogest.edu.ar', role: 'alumno', initials: 'LF', password: 'demo123' },
]
const selectedDemo = computed(() => demoAccounts.find((user) => user.email === form.email))

function chooseDemo(user) {
  form.email = user.email
  form.password = user.password
  errors.email = ''
  errors.password = ''
  errors.form = ''
}

function validate() {
  errors.email = form.email
    ? /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email.trim())
      ? ''
      : 'Ingresá un correo válido.'
    : 'El correo es obligatorio.'
  errors.password = form.password ? '' : 'La contraseña es obligatoria.'
  errors.form = ''
  return !errors.email && !errors.password
}

async function submit() {
  if (!validate()) return
  loading.value = true
  try {
    const user = await signIn(form.email, form.password)
    notify(`¡Hola, ${user.name}! Iniciaste sesión correctamente.`)
    router.push(typeof route.query.redirect === 'string' ? route.query.redirect : '/app')
  } catch (error) {
    errors.form = describeError(error, 'No pudimos iniciar sesión. Revisá tus datos.')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="auth-page">
    <header class="public-header public-header--auth">
      <RouterLink class="brand" to="/">
        <img src="/escudo-colegiogest.svg" alt="" class="brand__crest" />
        <span><strong>ColegioGest</strong><small>Gestión escolar</small></span>
      </RouterLink>
      <RouterLink class="back-link" to="/"><ArrowLeft :size="16" /> Volver al inicio</RouterLink>
    </header>
    <main class="auth-main">
      <div class="auth-aside">
        <span class="auth-aside__label"><ShieldCheck :size="15" /> TU ESPACIO ESCOLAR</span>
        <h1>Todo lo que pasa<br />en tu colegio,<br /><span>más cerca.</span></h1>
        <p>Ingresá a tu espacio para consultar la información de tu comunidad educativa.</p>
        <div class="auth-aside__quote"><span>“</span><p>Aprender es un camino que recorremos juntos.</p></div>
        <div class="auth-aside__school"><span><BookOpenCheck :size="17" /></span><div><strong>Comunidad ColegioGest</strong><small>Un lugar para crecer</small></div></div>
      </div>
      <section class="auth-card" aria-labelledby="login-title">
        <div class="auth-card__top">
          <span class="auth-card__icon"><LockKeyhole :size="20" /></span>
          <span class="auth-card__welcome">¡Qué bueno verte!</span>
        </div>
        <h2 id="login-title">Iniciar sesión</h2>
        <p class="auth-card__description">Ingresá tus datos para continuar.</p>
        <p v-if="!session.configured" class="form-alert" role="alert">
          Supabase no está configurado. Completá las variables de entorno para poder iniciar sesión.
        </p>
        <form class="stack-form" novalidate @submit.prevent="submit">
          <FormField id="email" label="Correo electrónico" :error="errors.email" required>
            <template #default="{ id }"><div class="input-with-icon"><Mail :size="17" /><input :id="id" v-model="form.email" type="email" autocomplete="username" placeholder="nombre@colegio.edu.ar" :aria-invalid="!!errors.email" /></div></template>
          </FormField>
          <FormField id="password" label="Contraseña" :error="errors.password" required>
            <template #default="{ id }"><div class="input-with-icon"><LockKeyhole :size="17" /><input :id="id" v-model="form.password" type="password" autocomplete="current-password" placeholder="Ingresá tu contraseña" :aria-invalid="!!errors.password" /></div></template>
          </FormField>
          <RouterLink class="forgot-link" to="/recuperar">¿Olvidaste tu contraseña?</RouterLink>
          <p v-if="errors.form" class="form-alert" role="alert">{{ errors.form }}</p>
          <BaseButton type="submit" class="auth-submit" :disabled="loading">{{ loading ? 'Ingresando…' : 'Ingresar' }} <ArrowRight :size="17" /></BaseButton>
        </form>
        <div class="demo-access">
          <div class="demo-access__title"><span>CUENTAS DE PRUEBA</span><i></i></div>
          <p>Elegí un perfil para completar el correo y la contraseña del seed.</p>
          <div class="demo-profiles">
            <button v-for="user in demoAccounts" :key="user.id" type="button" class="demo-profile" :class="{ 'demo-profile--selected': selectedDemo?.id === user.id }" @click="chooseDemo(user)">
              <span class="demo-profile__avatar">{{ user.initials }}</span><span><strong>{{ user.role }}</strong><small>{{ user.email }}</small></span>
            </button>
          </div>
          <span class="demo-access__password"><LockKeyhole :size="13" /> Contraseña para todos: <b>demo123</b></span>
        </div>
        <div class="auth-card__footer"><ShieldCheck :size="15" /> Autenticación segura con Supabase Auth</div>
      </section>
    </main>
    <footer class="public-footer"><span>© 2026 ColegioGest · Sistema de gestión escolar</span><span>Acceso protegido con Supabase</span></footer>
  </div>
</template>
