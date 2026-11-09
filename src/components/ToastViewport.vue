<script setup>
import { CheckCircle2, CircleAlert, X } from '@lucide/vue'
import { ui, clearToast } from '../stores/toast'
</script>

<template>
  <Transition name="toast">
    <div v-if="ui.toast" class="toast-message" :class="`toast-message--${ui.toast.type}`" role="status" aria-live="polite">
      <CheckCircle2 v-if="ui.toast.type === 'success'" :size="19" />
      <CircleAlert v-else :size="19" />
      <span>{{ ui.toast.message }}</span>
      <button type="button" aria-label="Cerrar mensaje" @click="clearToast"><X :size="16" /></button>
    </div>
  </Transition>
</template>
