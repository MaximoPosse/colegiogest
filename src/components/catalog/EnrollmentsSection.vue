<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { GraduationCap, Plus, X } from '@lucide/vue'
import BaseButton from '../BaseButton.vue'
import DataTable from '../DataTable.vue'
import FormField from '../FormField.vue'
import SearchFilterBar from '../SearchFilterBar.vue'
import StatusBadge from '../StatusBadge.vue'
import { describeError } from '../../lib/errors'
import { formatDate } from '../../lib/format'
import {
  enrollStudent,
  fetchCourses,
  fetchEnrollments,
  fetchStudents,
  finalizeEnrollment,
} from '../../services/school'
import { notify } from '../../stores/toast'

const loading = ref(true)
const saving = ref(false)
const error = ref('')
const search = ref('')
const enrollments = ref([])
const courses = ref([])
const students = ref([])
const enrollment = reactive({ studentId: '', courseId: '' })

const columns = [
  { key: 'student', label: 'Alumno' },
  { key: 'course', label: 'Curso' },
  { key: 'date', label: 'Fecha de inscripción' },
  { key: 'status', label: 'Estado' },
  { key: 'actions', label: '' },
]

const availableStudents = computed(() => students.value.filter((student) => student.estado === 'activo'))
const filteredEnrollments = computed(() => {
  const term = search.value.trim().toLocaleLowerCase('es')
  return enrollments.value.filter((item) => !term
    || `${item.student} ${item.course} ${item.status}`.toLocaleLowerCase('es').includes(term))
})

async function loadAll() {
  loading.value = true
  error.value = ''
  try {
    const [enrollmentRows, courseRows, studentRows] = await Promise.all([
      fetchEnrollments(),
      fetchCourses(),
      fetchStudents(),
    ])
    enrollments.value = enrollmentRows
    courses.value = courseRows
    students.value = studentRows
  } catch (caught) {
    error.value = describeError(caught)
    notify(error.value, 'error')
  } finally {
    loading.value = false
  }
}

onMounted(loadAll)

async function enrollStudentToCourse() {
  if (saving.value) return
  if (!enrollment.studentId || !enrollment.courseId) {
    notify('Seleccioná un alumno y un curso antes de continuar.', 'error')
    return
  }
  saving.value = true
  try {
    await enrollStudent(enrollment.studentId, enrollment.courseId)
    notify('El alumno fue inscripto correctamente.')
    Object.assign(enrollment, { studentId: '', courseId: '' })
    await loadAll()
  } catch (caught) {
    notify(describeError(caught), 'error')
  } finally {
    saving.value = false
  }
}

async function finalizeRow(row) {
  if (saving.value) return
  if (!window.confirm(`¿Finalizar la inscripción de ${row.student} en ${row.course}?`)) return
  saving.value = true
  try {
    await finalizeEnrollment(row.id)
    notify('La inscripción se finalizó.')
    await loadAll()
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
      <div>
        <div class="breadcrumb">Gestión escolar <span>/</span> <b>Inscripciones</b></div>
        <h1>Inscripciones</h1>
        <p>Inscribí alumnos en los cursos del ciclo lectivo.</p>
      </div>
      <span class="read-only-label"><GraduationCap :size="16" /> Ciclo lectivo actual</span>
    </div>

    <section class="panel enrollment-form">
      <div class="panel-heading">
        <div>
          <h2>Nueva inscripción</h2>
          <p>Si el alumno ya tenía una inscripción activa, se finalizará automáticamente.</p>
        </div>
      </div>
      <div class="enrollment-fields">
        <FormField id="enroll-student" label="Alumno" required>
          <template #default="{ id }">
            <select :id="id" v-model="enrollment.studentId">
              <option disabled value="">Seleccioná un alumno</option>
              <option v-for="student in availableStudents" :key="student.id" :value="student.id">
                {{ student.surname }}, {{ student.name }} (DNI {{ student.dniDisplay }})
              </option>
            </select>
          </template>
        </FormField>
        <FormField id="enroll-course" label="Curso" required>
          <template #default="{ id }">
            <select :id="id" v-model="enrollment.courseId">
              <option disabled value="">Seleccioná un curso</option>
              <option v-for="course in courses" :key="course.id" :value="course.id">{{ course.label }} · {{ course.turno }}</option>
            </select>
          </template>
        </FormField>
        <BaseButton :disabled="saving" @click="enrollStudentToCourse"><Plus :size="16" /> Inscribir alumno</BaseButton>
      </div>
    </section>

    <section class="panel list-panel">
      <div class="list-panel__top">
        <div><h2>Inscripciones registradas</h2><p>{{ filteredEnrollments.length }} {{ filteredEnrollments.length === 1 ? 'registro' : 'registros' }}</p></div>
        <span class="read-only-label"><GraduationCap :size="15" /> Datos en Supabase</span>
      </div>
      <SearchFilterBar v-model="search" placeholder="Buscar por alumno, curso o estado..." />
      <DataTable
        :columns="columns"
        :rows="filteredEnrollments"
        paginated
        :page-size="10"
        :empty-title="loading ? 'Cargando inscripciones...' : 'No hay inscripciones para mostrar'"
        :empty-text="loading ? 'Estamos consultando la base de datos.' : 'Probá ajustar la búsqueda o inscribí un alumno.'"
      >
        <template #cell="{ row, column }">
          <StatusBadge v-if="column.key === 'status'" :status="row.status" />
          <span v-else-if="column.key === 'date'">{{ formatDate(row.date) }}</span>
          <div v-else-if="column.key === 'actions'" class="table-actions">
            <button
              v-if="row.estado === 'activa'"
              type="button"
              class="icon-button icon-button--small icon-button--danger"
              :disabled="saving"
              :aria-label="`Finalizar inscripción de ${row.student}`"
              @click="finalizeRow(row)"
            >
              <X :size="16" />
            </button>
          </div>
          <span v-else>{{ row[column.key] }}</span>
        </template>
      </DataTable>
    </section>
  </div>
</template>
