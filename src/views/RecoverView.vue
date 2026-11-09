<script setup>
import { reactive, ref } from 'vue'
import { ArrowLeft, Mail, Send } from '@lucide/vue'
import BaseButton from '../components/BaseButton.vue'
import FormField from '../components/FormField.vue'
import { describeError } from '../lib/errors'
import { notify } from '../stores/toast'
import { recoverPassword, session } from '../stores/auth'

const form = reactive({ email: '' })
const error = ref('')
const sent = ref(false)
const loading = ref(false)

async function sendRecovery() {
  error.value = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email.trim())
    ? ''
    : 'Ingresá un correo electrónico válido.'
  if (error.value) return

  loading.value = true
  try {
    await recoverPassword(form.email)
    sent.value = true
    notify('Solicitud de recuperación enviada.')
  } catch (err) {
    error.value = describeError(err, 'No pudimos enviar las instrucciones. Intentá nuevamente.')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="auth-page">
    <header class="public-header public-header--auth">
      <RouterLink class="brand" to="/"><img src="/escudo-colegiogest.svg" alt="" class="brand__crest" /><span><strong>ColegioGest</strong><small>Gestión escolar</small></span></RouterLink>
      <RouterLink class="back-link" to="/login"><ArrowLeft :size="16" /> Volver al acceso</RouterLink>
    </header>
    <main class="recover-main">
      <section class="auth-card recover-card">
        <div class="auth-card__top"><span class="auth-card__icon"><Mail :size="20" /></span><span class="auth-card__welcome">Recuperación de acceso</span></div>
        <template v-if="!sent">
          <h1>¿Olvidaste tu contraseña?</h1>
          <p class="auth-card__description">No te preocupes. Ingresá tu correo y te enviaremos un enlace para recuperar el acceso.</p>
          <form class="stack-form" novalidate @submit.prevent="sendRecovery">
            <FormField id="recovery-email" label="Correo electrónico" :error="error" required>
              <template #default="{ id }"><div class="input-with-icon"><Mail :size="17" /><input :id="id" v-model="form.email" type="email" placeholder="nombre@colegio.edu.ar" autocomplete="email" /></div></template>
            </FormField>
            <BaseButton type="submit" :disabled="loading || !session.configured"><Send :size="16" /> {{ loading ? 'Enviando…' : 'Enviar instrucciones' }}</BaseButton>
          </form>
          <p v-if="!session.configured" class="form-alert" role="alert">Supabase no está configurado en este entorno.</p>
        </template>
        <div v-else class="success-panel" role="status">
          <span class="success-panel__icon"><Mail :size="24" /></span><h1>Revisá tu correo</h1>
          <p>Si <strong>{{ form.email }}</strong> pertenece a una cuenta, recibirás un enlace para restablecer tu contraseña.</p>
          <p class="demo-note">Revisá también la carpeta de correo no deseado. El enlace tiene vencimiento.</p>
        </div>
        <RouterLink class="back-link recover-back" to="/login"><ArrowLeft :size="16" /> Volver a iniciar sesión</RouterLink>
      </section>
    </main>
  </div>
</template>
