<script setup>
import { computed } from 'vue'

const props = defineProps({ status: { type: String, required: true } })
const kind = computed(() => {
  const value = props.status.toLowerCase()
  if (['activo', 'activa', 'presente', 'aprobado', 'entregada', 'publicado'].includes(value)) return 'success'
  if (['ausente', 'inactivo', 'desaprobado'].includes(value)) return 'danger'
  if (['tardanza', 'pendiente', 'borrador'].includes(value)) return 'warning'
  if (['justificada'].includes(value)) return 'info'
  return 'neutral'
})
</script>

<template>
  <span class="status-badge" :class="`status-badge--${kind}`">
    <span class="status-badge__dot" aria-hidden="true"></span>{{ status }}
  </span>
</template>
