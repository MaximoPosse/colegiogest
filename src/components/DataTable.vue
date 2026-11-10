<script setup>
import { computed, ref, watch } from 'vue'
import { ArrowLeft, ArrowRight } from '@lucide/vue'

const props = defineProps({
  columns: { type: Array, required: true },
  rows: { type: Array, required: true },
  rowKey: { type: String, default: 'id' },
  emptyTitle: { type: String, default: 'No hay registros para mostrar' },
  emptyText: { type: String, default: 'Probá ajustar la búsqueda o los filtros.' },
  paginated: { type: Boolean, default: false },
  pageSize: { type: Number, default: 10 },
})

const page = ref(1)
const totalPages = computed(() => Math.max(1, Math.ceil(props.rows.length / props.pageSize)))
const start = computed(() => (page.value - 1) * props.pageSize + 1)
const end = computed(() => Math.min(page.value * props.pageSize, props.rows.length))
const visibleRows = computed(() => {
  if (!props.paginated) return props.rows
  return props.rows.slice((page.value - 1) * props.pageSize, page.value * props.pageSize)
})

watch(() => props.rows, () => {
  page.value = 1
})

watch(totalPages, (value) => {
  if (page.value > value) page.value = value
})
</script>

<template>
  <div class="table-wrap">
    <table v-if="rows.length">
      <thead>
        <tr><th v-for="column in columns" :key="column.key" :class="{ 'text-right': column.align === 'right' }">{{ column.label }}</th></tr>
      </thead>
      <tbody>
        <tr v-for="row in visibleRows" :key="row[rowKey]">
          <td v-for="column in columns" :key="column.key" :class="{ 'text-right': column.align === 'right' }">
            <slot name="cell" :row="row" :column="column">{{ row[column.key] }}</slot>
          </td>
        </tr>
      </tbody>
    </table>
    <div v-else class="empty-state">
      <div class="empty-state__icon">∅</div>
      <h3>{{ emptyTitle }}</h3>
      <p>{{ emptyText }}</p>
    </div>
  </div>
  <div v-if="paginated && rows.length" class="table-footer">
    <span>Mostrando {{ start }}–{{ end }} de {{ rows.length }}</span>
    <div class="pagination">
      <button type="button" :disabled="page === 1" @click="page--"><ArrowLeft :size="14" /> Anterior</button>
      <span class="pagination__page">Página {{ page }} de {{ totalPages }}</span>
      <button type="button" :disabled="page >= totalPages" @click="page++">Siguiente <ArrowRight :size="14" /></button>
    </div>
  </div>
</template>
