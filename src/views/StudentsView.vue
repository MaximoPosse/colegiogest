<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { ArrowDownToLine, ArrowRight, MoreHorizontal, Trash2, UserRoundPlus } from '@lucide/vue'
import { useRouter } from 'vue-router'
import BaseButton from '../components/BaseButton.vue'
import DataTable from '../components/DataTable.vue'
import SearchFilterBar from '../components/SearchFilterBar.vue'
import StatusBadge from '../components/StatusBadge.vue'
import { describeError } from '../lib/errors'
import { deactivateStudent, fetchCourses, fetchStudents, fetchStudentsPage } from '../services/school'
import { notify } from '../stores/toast'

const router = useRouter()
const search = ref('')
const courseFilter = ref('')
const selectedForDelete = ref(null)
const page = ref(1)
const pageSize = 10
const total = ref(0)
const students = ref([])
const courses = ref([])
const loading = ref(true)
const error = ref('')
const saving = ref(false)
let searchTimer = null

const filters = computed(() => [
  {
    key: 'course',
    label: 'Filtrar por curso',
    value: courseFilter.value,
    options: [
      { label: 'Todos los cursos', value: '' },
      ...courses.value.map((course) => ({ label: course.label, value: course.id })),
    ],
  },
])
const columns = [
  { key: 'student', label: 'Alumno' },
  { key: 'dni', label: 'DNI' },
  { key: 'course', label: 'Curso' },
  { key: 'email', label: 'Correo electrónico' },
  { key: 'status', label: 'Estado' },
  { key: 'actions', label: '' },
]

function scheduleLoad() {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(loadStudents, 250)
}

watch([search, courseFilter], () => {
  if (page.value !== 1) {
    page.value = 1
    return
  }
  scheduleLoad()
})

watch(page, () => {
  loadStudents()
})

async function loadStudents() {
  loading.value = true
  error.value = ''
  try {
    const { rows, total: count } = await fetchStudentsPage({
      courseId: courseFilter.value || undefined,
      search: search.value,
      page: page.value,
      pageSize,
    })
    const lastPage = Math.max(1, Math.ceil(count / pageSize))
    if (page.value > lastPage) {
      page.value = lastPage
      return
    }
    students.value = rows
    total.value = count
  } catch (caught) {
    error.value = describeError(caught)
    notify(error.value, 'error')
  } finally {
    loading.value = false
  }
}

async function loadCourses() {
  try {
    courses.value = await fetchCourses()
  } catch (caught) {
    notify(describeError(caught), 'error')
  }
}

onMounted(() => {
  loadCourses()
  loadStudents()
})

function setFilter({ key, value }) {
  if (key === 'course') courseFilter.value = value
  page.value = 1
}

async function deleteStudent() {
  if (!selectedForDelete.value || saving.value) return
  saving.value = true
  try {
    await deactivateStudent(selectedForDelete.value.id)
    notify(`${selectedForDelete.value.name} ${selectedForDelete.value.surname} fue dado de baja.`)
    selectedForDelete.value = null
    await loadStudents()
  } catch (caught) {
    notify(describeError(caught), 'error')
  } finally {
    saving.value = false
  }
}

async function exportCsv() {
  try {
    const allStudents = await fetchStudents({
      courseId: courseFilter.value || undefined,
      search: search.value,
    })
    const rows = [
      ['Nombre', 'Apellido', 'DNI', 'Correo', 'Curso', 'Estado'],
      ...allStudents.map((student) => [student.name, student.surname, student.dni, student.email, student.course, student.status]),
    ]
    const csv = rows.map((row) => row.map((field) => `"${String(field).replaceAll('"', '""')}"`).join(';')).join('\r\n')
    const link = document.createElement('a')
    link.href = URL.createObjectURL(new Blob(['\uFEFF', csv], { type: 'text/csv;charset=utf-8' }))
    link.download = 'alumnos-colegiogest.csv'
    link.click()
    URL.revokeObjectURL(link.href)
    notify('La lista de alumnos se descargó correctamente.')
  } catch (caught) {
    notify(describeError(caught), 'error')
  }
}
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <div><div class="breadcrumb">Gestión escolar <span>/</span> <b>Alumnos</b></div><h1>Alumnos</h1><p>Administrá la información y el estado de los estudiantes.</p></div>
      <RouterLink to="/app/alumnos/nuevo"><BaseButton><UserRoundPlus :size="17" /> Nuevo alumno</BaseButton></RouterLink>
    </div>
    <section class="panel list-panel">
      <div class="list-panel__top">
        <div><h2>Listado de alumnos</h2><p>{{ total }} {{ total === 1 ? 'estudiante' : 'estudiantes' }} encontrados</p></div>
        <BaseButton variant="outline" :disabled="!total" @click="exportCsv"><ArrowDownToLine :size="16" /> Exportar</BaseButton>
      </div>
      <SearchFilterBar v-model="search" placeholder="Buscar por nombre, DNI o correo..." :filters="filters" @filter="setFilter" />
      <DataTable :columns="columns" :rows="students" :empty-title="loading ? 'Cargando alumnos...' : 'No encontramos alumnos'" :empty-text="loading ? 'Estamos consultando la base de datos.' : 'Probá con otro nombre, DNI o curso.'">
        <template #cell="{ row, column }">
          <template v-if="column.key === 'student'">
            <button type="button" class="student-cell" @click="router.push(`/app/alumnos/${row.id}/editar`)"><span class="avatar avatar--table">{{ row.name.charAt(0) }}{{ row.surname.charAt(0) }}</span><span><strong>{{ row.surname }}, {{ row.name }}</strong><small>Estudiante</small></span></button>
          </template>
          <StatusBadge v-else-if="column.key === 'status'" :status="row.status" />
          <div v-else-if="column.key === 'actions'" class="table-actions">
            <button type="button" class="icon-button icon-button--small" :aria-label="`Editar ${row.name} ${row.surname}`" @click="router.push(`/app/alumnos/${row.id}/editar`)"><MoreHorizontal :size="17" /></button>
            <button type="button" class="icon-button icon-button--small icon-button--danger" :disabled="row.estado === 'inactivo'" :aria-label="`Dar de baja a ${row.name} ${row.surname}`" @click="selectedForDelete = row"><Trash2 :size="16" /></button>
          </div>
          <span v-else>{{ row[column.key] }}</span>
        </template>
      </DataTable>
      <div v-if="total" class="table-footer">
        <span>Mostrando {{ (page - 1) * pageSize + 1 }}–{{ Math.min(page * pageSize, total) }} de {{ total }}</span>
        <div class="pagination"><button type="button" :disabled="page === 1" @click="page--">Anterior</button><button type="button" :disabled="page * pageSize >= total" @click="page++">Siguiente <ArrowRight :size="14" /></button></div>
      </div>
    </section>
    <div v-if="selectedForDelete" class="modal-backdrop" @click.self="selectedForDelete = null">
      <section class="confirm-dialog" role="dialog" aria-modal="true" aria-labelledby="delete-title">
        <span class="confirm-dialog__icon confirm-dialog__icon--danger"><Trash2 :size="20" /></span>
        <h2 id="delete-title">¿Dar de baja a este alumno?</h2>
        <p>{{ selectedForDelete.name }} {{ selectedForDelete.surname }} quedará inactivo, se cerrará su inscripción actual y no podrá volver a iniciar sesión hasta que un administrador reactive la cuenta.</p>
        <div class="confirm-dialog__actions"><BaseButton variant="outline" :disabled="saving" @click="selectedForDelete = null">Cancelar</BaseButton><BaseButton variant="danger" :disabled="saving" @click="deleteStudent">{{ saving ? 'Procesando…' : 'Confirmar baja' }}</BaseButton></div>
      </section>
    </div>
  </div>
</template>
