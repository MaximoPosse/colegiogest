<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { CalendarCheck, Check, Save } from '@lucide/vue'
import BaseButton from '../components/BaseButton.vue'
import DataTable from '../components/DataTable.vue'
import FormField from '../components/FormField.vue'
import { describeError } from '../lib/errors'
import { todayIso, todayLongLabel } from '../lib/format'
import { fetchAssignments, fetchAttendance, fetchStudents, saveAttendance } from '../services/school'
import { session } from '../stores/auth'
import { notify } from '../stores/toast'

const statuses = [
  { value: 'presente', label: 'Presente' },
  { value: 'ausente', label: 'Ausente' },
  { value: 'tardanza', label: 'Tardanza' },
  { value: 'justificada', label: 'Justificada' },
]
const assignments = ref([])
const students = ref([])
const selectedCourseId = ref('')
const selectedSubjectId = ref('')
const date = ref(todayIso())
const drafts = reactive({})
const loading = ref(true)
const loadingRows = ref(false)
const saving = ref(false)
const saved = ref(false)
const error = ref('')

const courseOptions = computed(() => {
  const map = new Map()
  for (const item of assignments.value) {
    if (!map.has(item.courseId)) map.set(item.courseId, { id: item.courseId, label: item.course })
  }
  return [...map.values()]
})
const subjectOptions = computed(() => assignments.value.filter((item) => item.courseId === selectedCourseId.value))
const assignment = computed(() => assignments.value.find((item) => item.courseId === selectedCourseId.value && item.subjectId === selectedSubjectId.value) ?? null)
const summary = computed(() => statuses.reduce((result, status) => {
  result[status.value] = students.value.filter((student) => drafts[student.id] === status.value).length
  return result
}, {}))
const marked = computed(() => students.value.filter((student) => Boolean(drafts[student.id])).length)
const columns = [
  { key: 'student', label: 'Alumno' },
  { key: 'dni', label: 'DNI' },
  { key: 'attendance', label: 'Asistencia de hoy' },
]

function clearDrafts() {
  Object.keys(drafts).forEach((key) => delete drafts[key])
}

async function loadRows() {
  if (!assignment.value) {
    students.value = []
    clearDrafts()
    return
  }
  loadingRows.value = true
  error.value = ''
  try {
    const [studentRows, attendanceRows] = await Promise.all([
      fetchStudents({ courseId: selectedCourseId.value }),
      fetchAttendance({
        courseId: selectedCourseId.value,
        subjectId: selectedSubjectId.value,
        date: date.value,
      }),
    ])
    students.value = studentRows.filter((student) => student.estado === 'activo')
    clearDrafts()
    const existing = new Map(attendanceRows.map((row) => [row.studentId, row.estado]))
    for (const student of students.value) drafts[student.id] = existing.get(student.id) ?? ''
    saved.value = students.value.length > 0 && students.value.every((student) => drafts[student.id])
  } catch (caught) {
    error.value = describeError(caught)
    notify(error.value, 'error')
  } finally {
    loadingRows.value = false
  }
}

onMounted(async () => {
  loading.value = true
  try {
    assignments.value = await fetchAssignments({ teacherId: session.user?.profesorId })
    const first = assignments.value[0]
    if (first) {
      selectedCourseId.value = first.courseId
      selectedSubjectId.value = first.subjectId
      await loadRows()
    }
  } catch (caught) {
    error.value = describeError(caught)
    notify(error.value, 'error')
  } finally {
    loading.value = false
  }
})

watch([selectedCourseId, selectedSubjectId, date], () => {
  if (assignment.value) loadRows()
})

function changeCourse() {
  const first = subjectOptions.value[0]
  selectedSubjectId.value = first?.subjectId ?? ''
  saved.value = false
}

function setStatus(studentId, status) {
  drafts[studentId] = status
  saved.value = false
}

async function saveRecords() {
  if (!assignment.value || saving.value) return
  const unmarked = students.value.filter((student) => !drafts[student.id])
  if (unmarked.length) {
    notify(`Todavía falta marcar a ${unmarked.length} ${unmarked.length === 1 ? 'alumno' : 'alumnos'}.`, 'error')
    return
  }
  saving.value = true
  try {
    const records = students.value.map((student) => ({
      id_alumno: student.id,
      id_curso: assignment.value.courseId,
      id_materia: assignment.value.subjectId,
      id_profesor: session.user.profesorId,
      fecha: date.value,
      estado: drafts[student.id],
    }))
    await saveAttendance(records)
    saved.value = true
    notify('La asistencia se guardó correctamente en Supabase.')
  } catch (caught) {
    notify(describeError(caught), 'error')
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <div><div class="breadcrumb">Mi espacio docente <span>/</span> <b>Asistencia</b></div><h1>Registro de asistencia</h1><p>Tomá asistencia para tus cursos y materias asignadas.</p></div>
      <div class="attendance-date"><CalendarCheck :size="17" /><span class="capitalize">{{ todayLongLabel() }}</span></div>
    </div>
    <div v-if="loading" class="panel empty-state"><h3>Cargando asignaciones...</h3><p>Estamos consultando tus cursos y materias.</p></div>
    <div v-else-if="!assignments.length" class="panel empty-state"><h3>No tenés asignaciones docentes</h3><p>Cuando la administración te asigne materias y cursos, vas a poder tomar asistencia desde acá.</p></div>
    <template v-else>
      <section class="attendance-filters panel">
        <FormField id="attendance-course" label="Curso"><template #default="{ id }"><select :id="id" v-model="selectedCourseId" @change="changeCourse"><option v-for="item in courseOptions" :key="item.id" :value="item.id">{{ item.label }}</option></select></template></FormField>
        <FormField id="attendance-subject" label="Materia"><template #default="{ id }"><select :id="id" v-model="selectedSubjectId"><option v-for="item in subjectOptions" :key="item.id" :value="item.subjectId">{{ item.subject }}</option></select></template></FormField>
        <FormField id="attendance-date" label="Fecha"><template #default="{ id }"><input :id="id" v-model="date" type="date" @change="saved = false" /></template></FormField>
      </section>
      <section class="attendance-summary">
        <div v-for="status in statuses" :key="status.value" class="attendance-summary__item" :class="`attendance-summary__item--${status.value}`"><span>{{ summary[status.value] ?? 0 }}</span><small>{{ status.label }}</small></div>
      </section>
      <section class="panel list-panel">
        <div class="list-panel__top"><div><h2>Alumnos del curso</h2><p>{{ students.length }} estudiantes · {{ marked }} marcados</p></div><BaseButton v-if="!saved" variant="outline" @click="notify('Tenés cambios sin guardar en la asistencia.', 'error')">Cambios sin guardar</BaseButton><span v-else class="saved-label"><Check :size="15" /> Guardado</span></div>
        <DataTable :columns="columns" :rows="students" :empty-title="loadingRows ? 'Cargando alumnos...' : 'No hay alumnos inscriptos'" empty-text="Elegí otro curso para tomar asistencia.">
          <template #cell="{ row, column }">
            <div v-if="column.key === 'student'" class="student-cell"><span class="avatar avatar--table">{{ row.name.charAt(0) }}{{ row.surname.charAt(0) }}</span><span><strong>{{ row.surname }}, {{ row.name }}</strong><small>Estudiante</small></span></div>
            <div v-else-if="column.key === 'attendance'" class="attendance-options">
              <button v-for="status in statuses" :key="status.value" type="button" class="attendance-option" :class="[{ 'attendance-option--selected': drafts[row.id] === status.value }, `attendance-option--${status.value}`]" :aria-pressed="drafts[row.id] === status.value" @click="setStatus(row.id, status.value)">{{ status.label }}</button>
            </div>
            <span v-else>{{ row[column.key] }}</span>
          </template>
        </DataTable>
        <div class="form-actions form-actions--table"><span class="table-helper">La asistencia se guarda por alumno, curso, materia y fecha.</span><BaseButton :disabled="saving || !students.length" @click="saveRecords"><Save :size="16" /> {{ saving ? 'Guardando…' : 'Guardar asistencia' }}</BaseButton></div>
      </section>
    </template>
  </div>
</template>
