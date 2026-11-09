<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { BookOpen, GraduationCap, Pencil, Plus, Trash2, Users, X } from '@lucide/vue'
import BaseButton from '../components/BaseButton.vue'
import DataTable from '../components/DataTable.vue'
import FormField from '../components/FormField.vue'
import SearchFilterBar from '../components/SearchFilterBar.vue'
import StatusBadge from '../components/StatusBadge.vue'
import { describeError } from '../lib/errors'
import { formatDate } from '../lib/format'
import {
  createAssignment,
  createCourse,
  deleteAssignment,
  deleteCourse,
  enrollStudent,
  fetchAssignments,
  fetchCourses,
  fetchEnrollments,
  fetchStudents,
  fetchTeachers,
  fetchUsers,
  finalizeEnrollment,
  setUserStatus,
  updateCourse,
} from '../services/school'
import { session } from '../stores/auth'
import { notify } from '../stores/toast'

const props = defineProps({ section: { type: String, required: true } })
const isCourses = computed(() => props.section === 'cursos')
const isUsers = computed(() => props.section === 'usuarios')
const isEnrollments = computed(() => props.section === 'inscripciones')
const title = computed(() => isCourses.value ? 'Cursos y materias' : isUsers.value ? 'Usuarios y roles' : 'Inscripciones')
const subtitle = computed(() => isCourses.value ? 'Organizá los cursos, materias y asignaciones docentes.' : isUsers.value ? 'Consultá y administrá los perfiles de acceso al sistema.' : 'Inscribí alumnos en los cursos del ciclo lectivo.')
const tab = ref('cursos')
const search = ref('')
const showForm = ref(false)
const loading = ref(true)
const saving = ref(false)
const error = ref('')
const formError = ref('')
const editingCourseId = ref(null)
const courses = ref([])
const assignments = ref([])
const enrollments = ref([])
const users = ref([])
const students = ref([])
const teachers = ref([])
const enrollment = reactive({ studentId: '', courseId: '' })
const form = reactive({
  anio: 3,
  division: '',
  turno: 'mañana',
  materia: '',
  courseId: '',
  teacherId: '',
  year: new Date().getFullYear(),
  descripcion: '',
})
const errors = reactive({})
const currentYear = new Date().getFullYear()

const filteredCourses = computed(() => courses.value.filter((course) => `${course.label} ${course.anio} ${course.division} ${course.turno}`.toLocaleLowerCase('es').includes(search.value.toLocaleLowerCase('es'))))
const filteredAssignments = computed(() => assignments.value.filter((item) => `${item.subject} ${item.teacher} ${item.course} ${item.year}`.toLocaleLowerCase('es').includes(search.value.toLocaleLowerCase('es'))))
const filteredEnrollments = computed(() => enrollments.value.filter((item) => `${item.student} ${item.course} ${item.status}`.toLocaleLowerCase('es').includes(search.value.toLocaleLowerCase('es'))))
const filteredUsers = computed(() => users.value.filter((user) => `${user.fullName} ${user.email} ${user.roleLabel}`.toLocaleLowerCase('es').includes(search.value.toLocaleLowerCase('es'))))
const availableStudents = computed(() => students.value.filter((student) => student.estado === 'activo'))
const columns = computed(() => isUsers.value
  ? [{ key: 'name', label: 'Nombre' }, { key: 'email', label: 'Correo electrónico' }, { key: 'roleLabel', label: 'Rol' }, { key: 'status', label: 'Estado' }, { key: 'actions', label: '' }]
  : isCourses.value
    ? tab.value === 'cursos'
      ? [{ key: 'label', label: 'Curso' }, { key: 'turno', label: 'Turno' }, { key: 'students', label: 'Alumnos' }, { key: 'actions', label: '' }]
      : [{ key: 'subject', label: 'Materia' }, { key: 'teacher', label: 'Docente' }, { key: 'course', label: 'Curso' }, { key: 'year', label: 'Ciclo' }, { key: 'actions', label: '' }]
    : [{ key: 'student', label: 'Alumno' }, { key: 'course', label: 'Curso' }, { key: 'date', label: 'Fecha de inscripción' }, { key: 'status', label: 'Estado' }, { key: 'actions', label: '' }])
const rows = computed(() => isUsers.value
  ? filteredUsers.value
  : isEnrollments.value
    ? filteredEnrollments.value
    : tab.value === 'cursos' ? filteredCourses.value : filteredAssignments.value)

async function loadAll() {
  loading.value = true
  error.value = ''
  try {
    const [courseRows, assignmentRows, enrollmentRows, userRows, studentRows, teacherRows] = await Promise.all([
      fetchCourses(),
      fetchAssignments(),
      fetchEnrollments(),
      fetchUsers(),
      fetchStudents(),
      fetchTeachers(),
    ])
    courses.value = courseRows
    assignments.value = assignmentRows
    enrollments.value = enrollmentRows
    users.value = userRows
    students.value = studentRows
    teachers.value = teacherRows
  } catch (caught) {
    error.value = describeError(caught)
    notify(error.value, 'error')
  } finally {
    loading.value = false
  }
}

onMounted(loadAll)

watch(() => props.section, () => {
  tab.value = 'cursos'
  search.value = ''
  showForm.value = false
  editingCourseId.value = null
  Object.assign(enrollment, { studentId: '', courseId: '' })
})

function resetForm() {
  Object.keys(errors).forEach((key) => delete errors[key])
  formError.value = ''
  Object.assign(form, {
    anio: 3,
    division: '',
    turno: 'mañana',
    materia: '',
    courseId: courses.value[0]?.id ?? '',
    teacherId: teachers.value[0]?.id ?? '',
    year: currentYear,
    descripcion: '',
  })
}

function openForm() {
  editingCourseId.value = null
  resetForm()
  showForm.value = true
}

function editCourse(course) {
  Object.keys(errors).forEach((key) => delete errors[key])
  formError.value = ''
  editingCourseId.value = course.id
  Object.assign(form, {
    anio: course.anio,
    division: course.division,
    turno: course.turnoRaw ?? 'mañana',
    materia: '',
    courseId: '',
    teacherId: '',
    year: currentYear,
    descripcion: '',
  })
  showForm.value = true
}

async function saveCatalogItem() {
  if (saving.value) return
  Object.keys(errors).forEach((key) => delete errors[key])
  formError.value = ''
  if (tab.value === 'cursos') {
    if (!Number(form.anio) || Number(form.anio) < 1 || Number(form.anio) > 12) errors.anio = 'Ingresá un año entre 1 y 12.'
    if (!form.division.trim()) errors.division = 'La división es obligatoria.'
  } else {
    if (!form.materia.trim()) errors.materia = 'El nombre de la materia es obligatorio.'
    if (!form.courseId) errors.courseId = 'Seleccioná un curso.'
    if (!form.teacherId) errors.teacherId = 'Seleccioná un profesor.'
    if (!Number(form.year) || Number(form.year) < 2000 || Number(form.year) > 2100) errors.year = 'Ingresá un ciclo lectivo válido.'
  }
  if (Object.keys(errors).length) return

  saving.value = true
  try {
    if (tab.value === 'cursos') {
      const payload = { anio: Number(form.anio), division: form.division.trim().toUpperCase(), turno: form.turno }
      if (editingCourseId.value) {
        await updateCourse(editingCourseId.value, payload)
        notify('El curso se actualizó correctamente.')
      } else {
        await createCourse(payload)
        notify('El curso se creó correctamente.')
      }
    } else {
      await createAssignment({
        materia: form.materia,
        courseId: form.courseId,
        teacherId: form.teacherId,
        year: form.year,
        descripcion: form.descripcion,
      })
      notify('La asignación docente se creó correctamente.')
    }
    showForm.value = false
    editingCourseId.value = null
    await loadAll()
  } catch (caught) {
    formError.value = describeError(caught)
    notify(formError.value, 'error')
  } finally {
    saving.value = false
  }
}

async function deleteRow(row) {
  if (saving.value) return
  const label = isCourses.value ? (tab.value === 'cursos' ? row.label : row.subject) : isUsers.value ? row.fullName : row.student
  if (!window.confirm(`¿Eliminar «${label}»? Esta acción se guarda en Supabase.`)) return
  saving.value = true
  try {
    if (isCourses.value && tab.value === 'cursos') {
      await deleteCourse(row.id)
      notify('El curso se eliminó.')
    } else if (isCourses.value) {
      await deleteAssignment(row.id)
      notify('La asignación se eliminó.')
    } else if (isEnrollments.value) {
      await finalizeEnrollment(row.id)
      notify('La inscripción se finalizó.')
    }
    await loadAll()
  } catch (caught) {
    notify(describeError(caught), 'error')
  } finally {
    saving.value = false
  }
}

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

async function toggleUserStatus(user) {
  if (saving.value || user.id === session.user?.id) return
  const next = user.estado === 'activo' ? 'inactivo' : 'activo'
  const action = next === 'activo' ? 'reactivar' : 'desactivar'
  if (!window.confirm(`¿Querés ${action} la cuenta de ${user.fullName}?`)) return
  saving.value = true
  try {
    await setUserStatus(user.id, next)
    notify(`La cuenta de ${user.fullName} quedó ${next === 'activo' ? 'activa' : 'inactiva'}.`)
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
    <div class="page-heading"><div><div class="breadcrumb">Gestión escolar <span>/</span> <b>{{ title }}</b></div><h1>{{ title }}</h1><p>{{ subtitle }}</p></div>
      <BaseButton v-if="isCourses" @click="openForm"><Plus :size="17" /> {{ tab === 'cursos' ? 'Nuevo curso' : 'Nueva materia' }}</BaseButton>
    </div>
    <div v-if="isCourses" class="catalog-tabs" role="tablist" aria-label="Tipo de registro">
      <button type="button" role="tab" :aria-selected="tab === 'cursos'" :class="{ 'catalog-tab--active': tab === 'cursos' }" @click="tab = 'cursos'; search = ''; showForm = false; editingCourseId = null"><GraduationCap :size="17" /> Cursos <span>{{ courses.length }}</span></button>
      <button type="button" role="tab" :aria-selected="tab === 'materias'" :class="{ 'catalog-tab--active': tab === 'materias' }" @click="tab = 'materias'; search = ''; showForm = false; editingCourseId = null"><BookOpen :size="17" /> Materias <span>{{ assignments.length }}</span></button>
    </div>
    <form v-if="showForm" class="panel catalog-form" novalidate @submit.prevent="saveCatalogItem">
      <div class="panel-heading"><div><h2>{{ tab === 'cursos' ? (editingCourseId ? 'Editar curso' : 'Crear un curso') : 'Crear una materia' }}</h2><p>Los datos se guardan directamente en Supabase.</p></div><button type="button" class="icon-button" aria-label="Cerrar formulario" @click="showForm = false; editingCourseId = null"><X :size="18" /></button></div>
      <div class="form-grid">
        <template v-if="tab === 'cursos'">
          <FormField id="catalog-year" label="Año / grado" :error="errors.anio" required><template #default="{ id }"><input :id="id" v-model.number="form.anio" type="number" min="1" max="12" placeholder="Ej. 3" /></template></FormField>
          <FormField id="catalog-division" label="División" :error="errors.division" required><template #default="{ id }"><input :id="id" v-model="form.division" placeholder="Ej. A" maxlength="10" /></template></FormField>
          <FormField id="catalog-shift" label="Turno"><template #default="{ id }"><select :id="id" v-model="form.turno"><option value="mañana">Mañana</option><option value="tarde">Tarde</option><option value="noche">Noche</option></select></template></FormField>
        </template>
        <template v-else>
          <FormField id="catalog-name" label="Nombre de la materia" :error="errors.materia" required><template #default="{ id }"><input :id="id" v-model="form.materia" placeholder="Ej. Geografía" /></template></FormField>
          <FormField id="catalog-course" label="Curso" :error="errors.courseId" required><template #default="{ id }"><select :id="id" v-model="form.courseId"><option disabled value="">Seleccioná un curso</option><option v-for="course in courses" :key="course.id" :value="course.id">{{ course.label }} · {{ course.turno }}</option></select></template></FormField>
          <FormField id="catalog-teacher" label="Docente asignado" :error="errors.teacherId" required><template #default="{ id }"><select :id="id" v-model="form.teacherId"><option disabled value="">Seleccioná un profesor</option><option v-for="teacher in teachers" :key="teacher.id" :value="teacher.id">{{ teacher.fullName }}</option></select></template></FormField>
          <FormField id="catalog-lectivo" label="Ciclo lectivo" :error="errors.year" required><template #default="{ id }"><input :id="id" v-model.number="form.year" type="number" min="2000" max="2100" /></template></FormField>
          <FormField id="catalog-description" label="Descripción"><template #default="{ id }"><input :id="id" v-model="form.descripcion" placeholder="Opcional" /></template></FormField>
        </template>
      </div>
      <div v-if="formError" class="form-note form-note--error"><span>!</span><p>{{ formError }}</p></div>
      <div v-if="tab === 'materias' && !teachers.length" class="form-note"><span>i</span><p>No hay profesores activos. Activá un docente desde la sección Usuarios para poder crear asignaciones.</p></div>
      <div class="form-actions"><BaseButton variant="outline" @click="showForm = false; editingCourseId = null">Cancelar</BaseButton><BaseButton type="submit" :disabled="saving"><Plus :size="16" /> {{ saving ? 'Guardando…' : editingCourseId ? 'Guardar cambios' : 'Crear' }}</BaseButton></div>
    </form>
    <section v-if="isEnrollments" class="panel enrollment-form">
      <div class="panel-heading"><div><h2>Nueva inscripción</h2><p>Asigná un alumno a un curso del ciclo lectivo. Si ya tenía una inscripción activa, se finalizará automáticamente.</p></div></div>
      <div class="enrollment-fields">
        <FormField id="enroll-student" label="Alumno" required><template #default="{ id }"><select :id="id" v-model="enrollment.studentId"><option disabled value="">Seleccioná un alumno</option><option v-for="student in availableStudents" :key="student.id" :value="student.id">{{ student.surname }}, {{ student.name }} (DNI {{ student.dniDisplay }})</option></select></template></FormField>
        <FormField id="enroll-course" label="Curso" required><template #default="{ id }"><select :id="id" v-model="enrollment.courseId"><option disabled value="">Seleccioná un curso</option><option v-for="course in courses" :key="course.id" :value="course.id">{{ course.label }} · {{ course.turno }}</option></select></template></FormField>
        <BaseButton :disabled="saving" @click="enrollStudentToCourse"><Plus :size="16" /> Inscribir alumno</BaseButton>
      </div>
    </section>
    <section class="panel list-panel">
      <div class="list-panel__top"><div><h2>{{ isUsers ? 'Usuarios registrados' : isCourses ? `Listado de ${tab}` : 'Inscripciones registradas' }}</h2><p>{{ rows.length }} {{ rows.length === 1 ? 'registro' : 'registros' }}</p></div><span class="read-only-label"><Users :size="15" /> Datos en Supabase</span></div>
      <SearchFilterBar v-model="search" :placeholder="isUsers ? 'Buscar usuario...' : 'Buscar en los registros...'" />
      <DataTable :columns="columns" :rows="rows" :empty-title="loading ? 'Cargando registros...' : 'No hay registros para mostrar'" :empty-text="loading ? 'Estamos consultando la base de datos.' : 'Probá ajustar la búsqueda o creá un nuevo registro.'">
        <template #cell="{ row, column }">
          <span v-if="column.key === 'name' && isUsers" class="user-name-cell"><span class="avatar avatar--table">{{ row.initials }}</span><strong>{{ row.name }}</strong></span>
          <StatusBadge v-else-if="column.key === 'status'" :status="row.status" />
          <span v-else-if="column.key === 'date'">{{ formatDate(row.date) }}</span>
          <span v-else-if="column.key === 'students'">{{ row.students }} estudiantes</span>
          <span v-else-if="column.key === 'turno'" class="capitalize">{{ row.turno }}</span>
          <div v-else-if="column.key === 'actions'" class="table-actions">
            <template v-if="isUsers">
              <button v-if="row.id !== session.user?.id" type="button" class="icon-button icon-button--small" :disabled="saving" :aria-label="`${row.estado === 'activo' ? 'Desactivar' : 'Reactivar'} a ${row.fullName}`" @click="toggleUserStatus(row)"><X :size="16" /></button>
            </template>
            <template v-else-if="isCourses && tab === 'cursos'">
              <button type="button" class="icon-button icon-button--small" :aria-label="`Editar ${row.label}`" @click="editCourse(row)"><Pencil :size="16" /></button>
              <button type="button" class="icon-button icon-button--small icon-button--danger" :disabled="saving" :aria-label="`Eliminar ${row.label}`" @click="deleteRow(row)"><Trash2 :size="16" /></button>
            </template>
            <template v-else-if="isCourses">
              <button type="button" class="icon-button icon-button--small icon-button--danger" :disabled="saving" :aria-label="`Eliminar ${row.subject}`" @click="deleteRow(row)"><Trash2 :size="16" /></button>
            </template>
            <template v-else-if="isEnrollments && row.estado === 'activa'">
              <button type="button" class="icon-button icon-button--small icon-button--danger" :disabled="saving" :aria-label="`Finalizar inscripción de ${row.student}`" @click="deleteRow(row)"><X :size="16" /></button>
            </template>
          </div>
          <span v-else>{{ row[column.key] }}</span>
        </template>
      </DataTable>
    </section>
  </div>
</template>
