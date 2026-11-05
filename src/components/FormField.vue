<script setup>
defineProps({
  label: { type: String, required: true },
  id: { type: String, required: true },
  error: { type: String, default: '' },
  required: { type: Boolean, default: false },
  hint: { type: String, default: '' },
})
</script>

<template>
  <div class="form-field" :class="{ 'form-field--invalid': error }">
    <label :for="id">{{ label }}<span v-if="required" class="required-mark"> *</span></label>
    <slot :id="id" />
    <p v-if="error" class="field-error" :id="`${id}-error`">{{ error }}</p>
    <p v-else-if="hint" class="field-hint">{{ hint }}</p>
  </div>
</template>
