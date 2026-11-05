<script setup>
import { CheckCircle2, CircleAlert, X } from '@lucide/vue'
import { school, clearToast } from '../data/demoStore'
</script>

<template>
  <Transition name="toast">
    <div v-if="school.toast" class="toast-message" :class="`toast-message--${school.toast.type}`" role="status" aria-live="polite">
      <CheckCircle2 v-if="school.toast.type === 'success'" :size="19" />
      <CircleAlert v-else :size="19" />
      <span>{{ school.toast.message }}</span>
      <button type="button" aria-label="Cerrar mensaje" @click="clearToast"><X :size="16" /></button>
    </div>
  </Transition>
</template>
