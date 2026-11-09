<script setup>
import { Bell, LogOut, Menu, X } from '@lucide/vue'
import { useRouter } from 'vue-router'
import { describeError } from '../lib/errors'
import { notify } from '../stores/toast'
import { session, signOut } from '../stores/auth'

defineProps({ menuOpen: { type: Boolean, default: false } })
const emit = defineEmits(['toggle-menu'])
const router = useRouter()

async function handleSignOut() {
  try {
    await signOut()
    notify('Cerraste sesión correctamente.')
  } catch (error) {
    notify(describeError(error, 'No pudimos cerrar la sesión.'), 'error')
  }
  router.push('/login')
}
</script>

<template>
  <header class="app-header">
    <div class="app-header__brand">
      <button class="mobile-menu-toggle" type="button" aria-label="Abrir menú" @click="emit('toggle-menu')">
        <X v-if="menuOpen" :size="20" /><Menu v-else :size="20" />
      </button>
      <RouterLink class="brand brand--header" to="/app" aria-label="ColegioGest, ir al panel">
        <img src="/escudo-colegiogest.svg" alt="" class="brand__crest" />
        <span><strong>ColegioGest</strong><small>Gestión escolar</small></span>
      </RouterLink>
    </div>
    <div class="app-header__right">
      <RouterLink class="icon-button header-notice" to="/app/avisos" aria-label="Ver avisos"><Bell :size="19" /><span class="notification-dot"></span></RouterLink>
      <RouterLink class="header-user" to="/app/perfil">
        <span class="avatar">{{ session.user?.initials }}</span>
        <span class="header-user__info"><strong>{{ session.user?.name }} {{ session.user?.surname }}</strong><small>{{ session.user?.roleLabel }}</small></span>
      </RouterLink>
      <button class="icon-button signout-button" type="button" aria-label="Cerrar sesión" title="Cerrar sesión" @click="handleSignOut"><LogOut :size="18" /></button>
    </div>
  </header>
</template>
