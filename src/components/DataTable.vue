<script setup>
defineProps({
  columns: { type: Array, required: true },
  rows: { type: Array, required: true },
  rowKey: { type: String, default: 'id' },
  emptyTitle: { type: String, default: 'No hay registros para mostrar' },
  emptyText: { type: String, default: 'Probá ajustar la búsqueda o los filtros.' },
})
</script>

<template>
  <div class="table-wrap">
    <table v-if="rows.length">
      <thead>
        <tr><th v-for="column in columns" :key="column.key" :class="{ 'text-right': column.align === 'right' }">{{ column.label }}</th></tr>
      </thead>
      <tbody>
        <tr v-for="row in rows" :key="row[rowKey]">
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
</template>
