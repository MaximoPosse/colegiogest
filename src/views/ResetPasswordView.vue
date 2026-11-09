<script setup>
import { onMounted, reactive, ref } from 'vue'
import { ArrowLeft, KeyRound, LockKeyhole, ShieldCheck } from '@lucide/vue'
import { useRouter } from 'vue-router'
import BaseButton from '../components/BaseButton.vue'
import FormField from '../components/FormField.vue'
import { supabase } from '../lib/supabase'
import { describeError } from '../lib/errors'
import { signOut, updatePassword } from '../stores/auth'
import { notify } from '../stores/toast'

const router = useRouter()
const form = reactive({ password: '', confirm: '' })
const errors = reactive({ password: '', confirm: '', form: '' })
const loading = ref(false)
const checking = ref(true)
const hasSession = ref(false)

onMounted(async () => {
  if (!supabase) {
    checking.value = false
    return
  }
  const { data } = await supabase.auth.getSession()
  hasSession.value = Boolean(data.session)
  checking.value = false
})

function validate() {
  errors.password = form.password.length >= 6 ? '' : 'La contraseña debe tener al menos 6 caracteres.'
  errors.confirm = form.confirm === form.password ? '' : 'Las contraseñas no coinciden.'
  errors.form = ''
  return !errors.password && !errors.confirm
}

async function savePassword() {
  if (!validate()) return
  loading.value = true
  try {
    await updatePassword(form.password)
    await signOut()
    notify('Tu contraseña se actualizó. Ya podés iniciar sesión.')
    router.push('/login')
  } catch (error) {
    errors.form = describeError(error, 'No pudimos actualizar la contraseña.')
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
        <div class="auth-card__top"><span class="auth-card__icon"><KeyRound :size="20" /></span><span class="auth-card__welcome">Nueva contraseña</span></div>
        <template v-if="checking">
          <h1>Verificando el enlace…</h1>
          <p class="auth-card__description">Estamos comprobando tu sesión de recuperación.</p>
        </template>
        <template v-else-if="!hasSession">
          <h1>Enlace vencido o inválido</h1>
          <p class="auth-card__description">El enlace de recuperación ya no es válido. Solicitá uno nuevo para continuar.</p>
          <p v-if="!supabase" class="form-alert" role="alert">Supabase no está configurado en este entorno.</p>
          <RouterLink class="back-link recover-back" to="/recuperar"><ArrowLeft :size="16" /> Solicitar un nuevo enlace</RouterLink>
        </template>
        <template v-else>
          <h1>Elegí una nueva contraseña</h1>
          <p class="auth-card__description">Ingresá una contraseña de al menos 6 caracteres.</p>
          <form class="stack-form" novalidate @submit.prevent="savePassword">
            <FormField id="reset-password" label="Nueva contraseña" :error="errors.password" required>
              <template #default="{ id }"><div class="input-with-icon"><LockKeyhole :size="17" /><input :id="id" v-model="form.password" type="password" autocomplete="new-password" placeholder="Mínimo 6 caracteres" /></div></template>
            </FormField>
            <FormField id="reset-confirm" label="Repetir contraseña" :error="errors.confirm" required>
              <template #default="{ id }"><div class="input-with-icon"><LockKeyhole :size="17" /><input :id="id" v-model="form.confirm" type="password" autocomplete="new-password" placeholder="Repetí la contraseña" /></div></template>
            </FormField>
            <p v-if="errors.form" class="form-alert" role="alert">{{ errors.form }}</p>
            <BaseButton type="submit" :disabled="loading"><ShieldCheck :size="16" /> {{ loading ? 'Guardando…' : 'Guardar contraseña' }}</BaseButton>
          </form>
        </template>
      </section>
    </main>
  </div>
</template>
