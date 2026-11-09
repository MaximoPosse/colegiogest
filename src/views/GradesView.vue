<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { Award, BookOpen, Check, Plus, Save, Trash2, TrendingUp, X } from '@lucide/vue'
import BaseButton from '../components/BaseButton.vue'
import DataTable from '../components/DataTable.vue'
import FormField from '../components/FormField.vue'
import SearchFilterBar from '../components/SearchFilterBar.vue'
import StatCard from '../components/StatCard.vue'
import { describeError } from '../lib/errors'
import { formatDate, todayIso } from '../lib/format'
import {
  createGrade,
  deleteGrade,
  fetchAssignments,
  fetchGrades,
  fetchStudents,
  updateGrade,
} from '../services/school'
import { session } from '../stores/auth'
import { notify } from '../stores/toast'

const isStudent = computed(() => session.user?.role === 'alumno')
const isTeacher = computed(() => session.user?.role === 'profesor')
const search = ref('')
const subjectFilter = ref('')
const drafts = reactive({})
const grades = ref([])
const assignments = ref([])
const students = ref([])
const loading = ref(true)
const saving = ref(false)
const showForm = ref(false)
const error = ref('')
const formError = ref('')
const form = reactive({ assignmentId: '', studentId: '', instancia: '', nota: '', fecha: todayIso() })
const errors = reactive({})

const subjects = computed(() => [...new Set(grades.value.map((grade) => grade.subject))].sort())
const studentGrades = computed(() => isStudent.value ? grades.value : [])
const visibleGrades = computed(() => {
  const source = isStudent.value ? studentGrades.value : grades.value
  const term = search.value.toLocaleLowerCase('es')
  return source.filter((grade) => (!subjectFilter.value || grade.subject === subjectFilter.value) &&
    (!term || `${grade.student} ${grade.subject} ${grade.instance}`.toLocaleLowerCase('es').includes(term)))
})
const average = computed(() => {
  if (!studentGrades.value.length) return '—'
  return (studentGrades.value.reduce((sum, item) => sum + Number(item.grade), 0) / studentGrades.value.length).toLocaleString('es-AR', { minimumFractionDigits: 1, maximumFractionDigits: 1 })
})
const columns = computed(() => [
  ...(!isStudent.value ? [{ key: 'student', label: 'Alumno' }] : []),
  { key: 'subject', label: 'Materia' },
  { key: 'instance', label: 'Instancia' },
  { key: 'date', label: 'Fecha' },
  { key: 'grade', label: 'Calificación' },
  ...(!isStudent.value ? [{ key: 'teacher', label: 'Docente' }, { key: 'actions', label: '' }] : []),
])
const filters = computed(() => [{ key: 'subject', label: 'Filtrar por materia', value: subjectFilter.value, options: [{ label: 'Todas las materias', value: '' }, ...subjects.value.map((subject) => ({ label: subject, value: subject }))] }])
const selectedAssignment = computed(() => assignments.value.find((item) => item.id === form.assignmentId) ?? null)
const studentsForForm = computed(() => {
  if (!selectedAssignment.value) return []
  return students.value.filter((student) => student.courseId === selectedAssignment.value.courseId && student.estado === 'activo')
})

async function loadGrades() {
  loading.value = true
  error.value = ''
  try {
    grades.value = await fetchGrades()
    // Mostrar la nota vigente en el campo editable (no como placeholder).
    Object.keys(drafts).forEach((key) => delete drafts[key])
    grades.value.forEach((grade) => { drafts[grade.id] = String(grade.grade) })
  } catch (caught) {
    error.value = describeError(caught)
    notify(error.value, 'error')
  } finally {
    loading.value = false
  }
}

async function loadFormData() {
  if (isStudent.value) return
  try {
    const [assignmentRows, studentRows] = await Promise.all([
      fetchAssignments(isTeacher.value ? { teacherId: session.user?.profesorId } : {}),
      fetchStudents(),
    ])
    assignments.value = assignmentRows
    students.value = studentRows
  } catch (caught) {
    notify(describeError(caught), 'error')
  }
}

onMounted(async () => {
  await Promise.all([loadGrades(), loadFormData()])
})

function updateFilter({ key, value }) {
  if (key === 'subject') subjectFilter.value = value
}

function openNewGrade() {
  Object.keys(errors).forEach((key) => delete errors[key])
  formError.value = ''
  Object.assign(form, {
    assignmentId: assignments.value[0]?.id ?? '',
    studentId: '',
    instancia: '',
    nota: '',
    fecha: todayIso(),
  })
  showForm.value = true
}

function changeAssignment() {
  form.studentId = ''
}

async function saveNewGrade() {
  if (saving.value) return
  Object.keys(errors).forEach((key) => delete errors[key])
  formError.value = ''
  if (!form.assignmentId) errors.assignmentId = 'Seleccioná una materia y curso.'
  if (!form.studentId) errors.studentId = 'Seleccioná un alumno.'
  if (!form.instancia.trim()) errors.instancia = 'Indicá el tipo de instancia.'
  if (!form.nota) errors.nota = 'Ingresá una nota.'
  else if (Number(form.nota) < 1 || Number(form.nota) > 10) errors.nota = 'La nota debe estar entre 1 y 10.'
  if (!form.fecha) errors.fecha = 'Seleccioná una fecha.'
  if (Object.keys(errors).length) return
  const assignment = selectedAssignment.value
  saving.value = true
  try {
    await createGrade({
      alumnoId: form.studentId,
      materiaId: assignment.subjectId,
      profesorId: assignment.teacherId,
      instancia: form.instancia,
      nota: form.nota,
      fecha: form.fecha,
      observacion: null,
    })
    notify('La calificación se registró correctamente.')
    showForm.value = false
    await loadGrades()
  } catch (caught) {
    formError.value = describeError(caught)
    notify(formError.value, 'error')
  } finally {
    saving.value = false
  }
}

async function saveGrades() {
  if (saving.value) return
  const updates = grades.value.filter((grade) => {
    const draft = drafts[grade.id]
    return draft !== undefined && draft !== '' && Number(draft) !== Number(grade.grade)
  })
  if (!updates.length) {
    notify('No hay calificaciones modificadas para guardar.', 'error')
    return
  }
  if (updates.some((grade) => Number(drafts[grade.id]) < 1 || Number(drafts[grade.id]) > 10)) {
    notify('Las notas deben estar entre 1 y 10.', 'error')
    return
  }
  saving.value = true
  try {
    await Promise.all(updates.map((grade) => updateGrade(grade.id, {
      instancia: grade.instance,
      nota: drafts[grade.id],
      fecha: grade.date,
      observacion: grade.observation,
    })))
    notify(`${updates.length} ${updates.length === 1 ? 'calificación actualizada' : 'calificaciones actualizadas'}.`)
    Object.keys(drafts).forEach((key) => delete drafts[key])
    await loadGrades()
  } catch (caught) {
    notify(describeError(caught), 'error')
  } finally {
    saving.value = false
  }
}

async function removeGrade(grade) {
  if (saving.value) return
  if (!window.confirm(`¿Eliminar la calificación de ${grade.student} en ${grade.subject}?`)) return
  saving.value = true
  try {
    await deleteGrade(grade.id)
    notify('La calificación se eliminó.')
    await loadGrades()
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
      <div><div class="breadcrumb">{{ isStudent ? 'Mi espacio escolar' : 'Mi espacio docente' }} <span>/</span> <b>Calificaciones</b></div><h1>{{ isStudent ? 'Mis calificaciones' : 'Calificaciones' }}</h1><p>{{ isStudent ? 'Consultá tus notas y seguí tu progreso en cada materia.' : isTeacher ? 'Cargá y actualizá las calificaciones de tus alumnos.' : 'Administrá las calificaciones de los cursos.' }}</p></div>
      <BaseButton v-if="!isStudent" @click="showForm = !showForm"><Plus :size="17" /> Nueva calificación</BaseButton>
      <span v-else class="read-only-label"><BookOpen :size="16" /> Solo lectura</span>
    </div>
    <form v-if="showForm && !isStudent" class="panel catalog-form" novalidate @submit.prevent="saveNewGrade">
      <div class="panel-heading"><div><h2>Registrar calificación</h2><p>La nota se guarda en Supabase y respeta las asignaciones vigentes.</p></div><button type="button" class="icon-button" aria-label="Cerrar formulario" @click="showForm = false"><X :size="18" /></button></div>
      <div class="form-grid">
        <FormField id="grade-assignment" label="Materia y curso" :error="errors.assignmentId" required><template #default="{ id }"><select :id="id" v-model="form.assignmentId" @change="changeAssignment"><option disabled value="">Seleccioná una asignación</option><option v-for="item in assignments" :key="item.id" :value="item.id">{{ item.subject }} · {{ item.course }} · {{ item.teacher }}</option></select></template></FormField>
        <FormField id="grade-student" label="Alumno" :error="errors.studentId" required><template #default="{ id }"><select :id="id" v-model="form.studentId"><option disabled value="">Seleccioná un alumno</option><option v-for="student in studentsForForm" :key="student.id" :value="student.id">{{ student.surname }}, {{ student.name }}</option></select></template></FormField>
        <FormField id="grade-instance" label="Instancia" :error="errors.instancia" required><template #default="{ id }"><input :id="id" v-model="form.instancia" placeholder="Ej. Trabajo práctico" /></template></FormField>
        <FormField id="grade-value" label="Nota" :error="errors.nota" required hint="Escala de 1 a 10."><template #default="{ id }"><input :id="id" v-model="form.nota" type="number" min="1" max="10" step="0.01" /></template></FormField>
        <FormField id="grade-date" label="Fecha" :error="errors.fecha" required><template #default="{ id }"><input :id="id" v-model="form.fecha" type="date" /></template></FormField>
      </div>
      <div v-if="formError" class="form-note form-note--error"><span>!</span><p>{{ formError }}</p></div>
      <div class="form-actions"><BaseButton variant="outline" @click="showForm = false">Cancelar</BaseButton><BaseButton type="submit" :disabled="saving"><Save :size="16" /> {{ saving ? 'Guardando…' : 'Guardar calificación' }}</BaseButton></div>
    </form>
    <section v-if="isStudent" class="stats-grid stats-grid--grades">
      <StatCard label="Promedio general" :value="average" detail="Sobre 10 puntos" :icon="TrendingUp" tone="blue" />
      <StatCard label="Materias con nota" :value="subjects.length" detail="Registradas" :icon="BookOpen" tone="green" />
      <StatCard label="Calificaciones" :value="studentGrades.length" detail="Registradas hasta hoy" :icon="Award" tone="rose" />
    </section>
    <section class="panel list-panel">
      <div class="list-panel__top"><div><h2>{{ isStudent ? 'Detalle por materia' : 'Registro de calificaciones' }}</h2><p>{{ visibleGrades.length }} registros encontrados</p></div><span v-if="!isStudent" class="table-helper">Ingresá notas entre 1 y 10</span></div>
      <SearchFilterBar v-model="search" :placeholder="isStudent ? 'Buscar por materia o instancia...' : 'Buscar por alumno, materia o instancia...'" :filters="filters" @filter="updateFilter" />
      <DataTable :columns="columns" :rows="visibleGrades" :empty-title="loading ? 'Cargando calificaciones...' : 'Todavía no hay calificaciones'" :empty-text="loading ? 'Estamos consultando la base de datos.' : 'Cuando se registren notas, las vas a encontrar acá.'">
        <template #cell="{ row, column }">
          <strong v-if="column.key === 'grade'" class="grade-mark" :class="{ 'grade-mark--pass': row.grade >= 6 }">
            <template v-if="!isStudent"><input v-model="drafts[row.id]" class="grade-input" type="number" min="1" max="10" :aria-label="`Nota de ${row.student} en ${row.subject}`" :placeholder="String(row.grade)" /><span>/ 10</span></template>
            <template v-else>{{ row.grade }}<span>/ 10</span></template>
          </strong>
          <span v-else-if="column.key === 'date'">{{ formatDate(row.date, { day: '2-digit', month: 'short', year: 'numeric' }) }}</span>
          <button v-else-if="column.key === 'actions'" type="button" class="icon-button icon-button--small icon-button--danger" :disabled="saving" :aria-label="`Eliminar nota de ${row.student}`" @click="removeGrade(row)"><Trash2 :size="16" /></button>
          <span v-else>{{ row[column.key] }}</span>
        </template>
      </DataTable>
      <div v-if="!isStudent" class="form-actions form-actions--table"><span class="table-helper"><Check :size="14" /> Las notas se guardan en Supabase</span><BaseButton :disabled="saving" @click="saveGrades"><Save :size="16" /> {{ saving ? 'Guardando…' : 'Guardar cambios' }}</BaseButton></div>
    </section>
  </div>
</template>
