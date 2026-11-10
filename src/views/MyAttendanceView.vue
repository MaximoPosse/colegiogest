<script setup>
import { computed, onMounted, ref } from 'vue'
import { CalendarCheck, CalendarX, Clock, FileCheck2 } from '@lucide/vue'
import DataTable from '../components/DataTable.vue'
import SearchFilterBar from '../components/SearchFilterBar.vue'
import StatCard from '../components/StatCard.vue'
import StatusBadge from '../components/StatusBadge.vue'
import { describeError } from '../lib/errors'
import { formatDate } from '../lib/format'
import { fetchAttendance } from '../services/school'
import { session } from '../stores/auth'
import { notify } from '../stores/toast'

const loading = ref(true)
const error = ref('')
const rows = ref([])
const search = ref('')
const statusFilter = ref('')

const columns = [
  { key: 'date', label: 'Fecha' },
  { key: 'subject', label: 'Materia' },
  { key: 'teacher', label: 'Docente' },
  { key: 'status', label: 'Estado' },
  { key: 'observation', label: 'Observación' },
]

const summary = computed(() => rows.value.reduce((result, row) => {
  result[row.estado] = (result[row.estado] ?? 0) + 1
  return result
}, {}))

const filters = computed(() => [
  {
    key: 'status',
    label: 'Filtrar por estado',
    value: statusFilter.value,
    options: [
      { label: 'Todos los estados', value: '' },
      { label: 'Presente', value: 'presente' },
      { label: 'Ausente', value: 'ausente' },
      { label: 'Tardanza', value: 'tardanza' },
      { label: 'Justificada', value: 'justificada' },
    ],
  },
])

const visibleRows = computed(() => {
  const term = search.value.trim().toLocaleLowerCase('es')
  return rows.value
    .filter((row) => !statusFilter.value || row.estado === statusFilter.value)
    .filter((row) => !term
      || `${row.subject} ${row.teacher} ${row.status} ${row.observation ?? ''}`.toLocaleLowerCase('es').includes(term))
    .sort((a, b) => String(b.date).localeCompare(String(a.date)))
})

function setFilter({ key, value }) {
  if (key === 'status') statusFilter.value = value
}

async function loadAttendance() {
  loading.value = true
  error.value = ''
  try {
    rows.value = await fetchAttendance({ studentId: session.user?.alumnoId })
  } catch (caught) {
    error.value = describeError(caught)
    notify(error.value, 'error')
  } finally {
    loading.value = false
  }
}

onMounted(loadAttendance)
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <div>
        <div class="breadcrumb">Mi espacio escolar <span>/</span> <b>Mis asistencias</b></div>
        <h1>Mis asistencias</h1>
        <p>Consultá tu historial de asistencia por materia y fecha.</p>
      </div>
      <span class="read-only-label"><CalendarCheck :size="16" /> Solo lectura</span>
    </div>

    <section class="stats-grid">
      <StatCard label="Presente" :value="summary.presente ?? 0" detail="Clases con asistencia" :icon="CalendarCheck" tone="green" />
      <StatCard label="Ausente" :value="summary.ausente ?? 0" detail="Faltas registradas" :icon="CalendarX" tone="rose" />
      <StatCard label="Tardanza" :value="summary.tardanza ?? 0" detail="Llegadas tarde" :icon="Clock" tone="amber" />
      <StatCard label="Justificada" :value="summary.justificada ?? 0" detail="Faltas justificadas" :icon="FileCheck2" tone="blue" />
    </section>

    <section class="panel list-panel">
      <div class="list-panel__top">
        <div><h2>Historial de asistencia</h2><p>{{ visibleRows.length }} {{ visibleRows.length === 1 ? 'registro' : 'registros' }}</p></div>
      </div>
      <SearchFilterBar v-model="search" placeholder="Buscar por materia, docente o estado..." :filters="filters" @filter="setFilter" />
      <DataTable
        :columns="columns"
        :rows="visibleRows"
        paginated
        :page-size="10"
        :empty-title="loading ? 'Cargando asistencias...' : 'Todavía no hay asistencias registradas'"
        :empty-text="loading ? 'Estamos consultando la base de datos.' : 'Cuando tus docentes tomen asistencia, va a aparecer acá.'"
      >
        <template #cell="{ row, column }">
          <span v-if="column.key === 'date'">{{ formatDate(row.date) }}</span>
          <StatusBadge v-else-if="column.key === 'status'" :status="row.status" />
          <span v-else-if="column.key === 'observation'">{{ row.observation || '—' }}</span>
          <span v-else>{{ row[column.key] }}</span>
        </template>
      </DataTable>
    </section>
  </div>
</template>
