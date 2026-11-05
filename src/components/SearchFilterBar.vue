<script setup>
import { Search, SlidersHorizontal, X } from '@lucide/vue'

defineProps({
  modelValue: { type: String, default: '' },
  placeholder: { type: String, default: 'Buscar...' },
  filters: { type: Array, default: () => [] },
})
const emit = defineEmits(['update:modelValue', 'filter'])
</script>

<template>
  <div class="search-filter-bar">
    <label class="search-box">
      <Search :size="18" aria-hidden="true" />
      <span class="sr-only">Buscar registros</span>
      <input :value="modelValue" :placeholder="placeholder" @input="emit('update:modelValue', $event.target.value)" />
      <button v-if="modelValue" type="button" class="search-clear" aria-label="Limpiar búsqueda" @click="emit('update:modelValue', '')">
        <X :size="15" />
      </button>
    </label>
    <label v-for="filter in filters" :key="filter.key" class="filter-select">
      <SlidersHorizontal :size="16" aria-hidden="true" />
      <span class="sr-only">{{ filter.label }}</span>
      <select :value="filter.value" @change="emit('filter', { key: filter.key, value: $event.target.value })">
        <option v-for="option in filter.options" :key="option.value" :value="option.value">{{ option.label }}</option>
      </select>
    </label>
  </div>
</template>
