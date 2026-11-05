<script setup>
import { computed, reactive, ref } from 'vue'
import { BookOpen, GraduationCap, Plus, Trash2, Users, X } from '@lucide/vue'
import BaseButton from '../components/BaseButton.vue'
import DataTable from '../components/DataTable.vue'
import FormField from '../components/FormField.vue'
import SearchFilterBar from '../components/SearchFilterBar.vue'
import StatusBadge from '../components/StatusBadge.vue'
import { demoUsers } from '../data/mockData'
import { notify, school } from '../data/demoStore'

const props = defineProps({ section: { type: String, required: true } })
const isCourses = computed(() => props.section === 'cursos')
const isUsers = computed(() => props.section === 'usuarios')
const title = computed(() => isCourses.value ? 'Cursos y materias' : isUsers.value ? 'Usuarios y roles' : 'Inscripciones')
const subtitle = computed(() => isCourses.value ? 'Organizá los cursos, materias y asignaciones docentes.' : isUsers.value ? 'Consultá los perfiles de acceso al sistema.' : 'Inscribí alumnos en los cursos del ciclo lectivo.')
const tab = ref('cursos')
const search = ref('')
const showForm = ref(false)
const enrollment = reactive({ studentId: '', course: '' })
const form = reactive({ name: '', division: '', shift: 'Mañana', course: '', teacher: '' })
const errors = reactive({})
const filteredCourses = computed(() => school.courses.filter((course) => `${course.name} ${course.division} ${course.shift}`.toLowerCase().includes(search.value.toLowerCase())))
const filteredSubjects = computed(() => school.subjects.filter((subject) => `${subject.name} ${subject.teacher} ${subject.course}`.toLowerCase().includes(search.value.toLowerCase())))
const filteredEnrollments = computed(() => school.enrollments.filter((item) => `${item.student} ${item.course}`.toLowerCase().includes(search.value.toLowerCase())))
const availableStudents = computed(() => school.students.filter((student) => !school.enrollments.some((item) => item.studentId === student.id && item.course === enrollment.course)))
const columns = computed(() => isUsers.value
  ? [{ key: 'name', label: 'Nombre' }, { key: 'email', label: 'Correo electrónico' }, { key: 'role', label: 'Rol' }, { key: 'status', label: 'Estado' }]
  : isCourses.value
    ? tab.value === 'cursos'
      ? [{ key: 'name', label: 'Curso' }, { key: 'shift', label: 'Turno' }, { key: 'students', label: 'Alumnos' }, { key: 'actions', label: '' }]
      : [{ key: 'name', label: 'Materia' }, { key: 'teacher', label: 'Docente' }, { key: 'course', label: 'Curso' }, { key: 'actions', label: '' }]
    : [{ key: 'student', label: 'Alumno' }, { key: 'course', label: 'Curso' }, { key: 'date', label: 'Fecha de inscripción' }, { key: 'actions', label: '' }])
const rows = computed(() => isUsers.value
  ? demoUsers.filter((user) => `${user.name} ${user.surname} ${user.email}`.toLowerCase().includes(search.value.toLowerCase())).map((user) => ({ ...user, name: `${user.surname}, ${user.name}`, status: 'Activo' }))
  : isCourses.value ? tab.value === 'cursos' ? filteredCourses.value : filteredSubjects.value : filteredEnrollments.value)

function openForm() {
  Object.keys(errors).forEach((key) => delete errors[key])
  Object.assign(form, { name: '', division: '', shift: 'Mañana', course: school.courses[0] ? `${school.courses[0].name.replace(' año', 'º')} ${school.courses[0].division}` : '', teacher: '' })
  showForm.value = true
}

function saveCatalogItem() {
  Object.keys(errors).forEach((key) => delete errors[key])
  if (!form.name.trim()) errors.name = isCourses.value && tab.value === 'cursos' ? 'El nombre del curso es obligatorio.' : 'El nombre es obligatorio.'
  if (isCourses.value && tab.value === 'cursos' && !form.division.trim()) errors.division = 'La división es obligatoria.'
  if (isCourses.value && tab.value === 'materias' && !form.teacher.trim()) errors.teacher = 'El docente es obligatorio.'
  if (Object.keys(errors).length) return
  if (tab.value === 'cursos') {
    school.courses.push({ id: `c-${Date.now()}`, name: form.name.trim(), division: form.division.trim().toUpperCase(), shift: form.shift, students: 0 })
    notify('El curso se agregó a esta sesión de prueba.')
  } else {
    school.subjects.push({ id: `m-${Date.now()}`, name: form.name.trim(), teacher: form.teacher.trim(), course: form.course, schedule: 'Horario a definir' })
    notify('La materia se agregó a esta sesión de prueba.')
  }
  showForm.value = false
}

function deleteRow(row) {
  if (!window.confirm(`¿Eliminar «${row.name ?? row.student}» de los datos de esta sesión?`)) return
  if (isCourses.value && tab.value === 'cursos') school.courses = school.courses.filter((item) => item.id !== row.id)
  else if (isCourses.value) school.subjects = school.subjects.filter((item) => item.id !== row.id)
  else school.enrollments = school.enrollments.filter((item) => item.id !== row.id)
  notify('El registro se eliminó de esta sesión.')
}

function enrollStudent() {
  if (!enrollment.studentId || !enrollment.course) {
    notify('Seleccioná un alumno y un curso antes de continuar.', 'error')
    return
  }
  if (school.enrollments.some((item) => item.studentId === enrollment.studentId && item.course === enrollment.course)) {
    notify('El alumno ya está inscripto en ese curso.', 'error')
    return
  }
  const student = school.students.find((item) => item.id === enrollment.studentId)
  school.enrollments.unshift({ id: `ins-${Date.now()}`, studentId: student.id, student: `${student.name} ${student.surname}`, course: enrollment.course, date: new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Argentina/Buenos_Aires' }).format(new Date()) })
  notify(`${student.name} fue inscripto en ${enrollment.course}.`)
  Object.assign(enrollment, { studentId: '', course: '' })
}
</script>

<template>
  <div class="page">
    <div class="page-heading"><div><div class="breadcrumb">Gestión escolar <span>/</span> <b>{{ title }}</b></div><h1>{{ title }}</h1><p>{{ subtitle }}</p></div>
      <BaseButton v-if="isCourses" @click="openForm"><Plus :size="17" /> {{ tab === 'cursos' ? 'Nuevo curso' : 'Nueva materia' }}</BaseButton>
    </div>
    <div v-if="isCourses" class="catalog-tabs" role="tablist" aria-label="Tipo de registro">
      <button type="button" role="tab" :aria-selected="tab === 'cursos'" :class="{ 'catalog-tab--active': tab === 'cursos' }" @click="tab = 'cursos'; search = ''"><GraduationCap :size="17" /> Cursos <span>{{ school.courses.length }}</span></button>
      <button type="button" role="tab" :aria-selected="tab === 'materias'" :class="{ 'catalog-tab--active': tab === 'materias' }" @click="tab = 'materias'; search = ''"><BookOpen :size="17" /> Materias <span>{{ school.subjects.length }}</span></button>
    </div>
    <form v-if="showForm" class="panel catalog-form" novalidate @submit.prevent="saveCatalogItem">
      <div class="panel-heading"><div><h2>{{ tab === 'cursos' ? 'Crear un curso' : 'Crear una materia' }}</h2><p>El registro estará disponible durante esta sesión.</p></div><button type="button" class="icon-button" aria-label="Cerrar formulario" @click="showForm = false"><X :size="18" /></button></div>
      <div class="form-grid">
        <FormField id="catalog-name" :label="tab === 'cursos' ? 'Nombre del curso' : 'Nombre de la materia'" :error="errors.name" required><template #default="{ id }"><input :id="id" v-model="form.name" :placeholder="tab === 'cursos' ? 'Ej. 5.º año' : 'Ej. Geografía'" /></template></FormField>
        <template v-if="tab === 'cursos'">
          <FormField id="catalog-division" label="División" :error="errors.division" required><template #default="{ id }"><input :id="id" v-model="form.division" placeholder="Ej. A" maxlength="2" /></template></FormField>
          <FormField id="catalog-shift" label="Turno"><template #default="{ id }"><select :id="id" v-model="form.shift"><option>Mañana</option><option>Tarde</option><option>Noche</option></select></template></FormField>
        </template>
        <template v-else>
          <FormField id="catalog-teacher" label="Docente asignado" :error="errors.teacher" required><template #default="{ id }"><input :id="id" v-model="form.teacher" placeholder="Nombre y apellido" /></template></FormField>
          <FormField id="catalog-course" label="Curso"><template #default="{ id }"><select :id="id" v-model="form.course"><option v-for="course in school.courses" :key="course.id" :value="`${course.name.replace(' año', 'º')} ${course.division}`">{{ course.name.replace(' año', 'º') }} {{ course.division }}</option></select></template></FormField>
        </template>
      </div>
      <div class="form-actions"><BaseButton variant="outline" @click="showForm = false">Cancelar</BaseButton><BaseButton type="submit"><Plus :size="16" /> Crear</BaseButton></div>
    </form>
    <section v-if="section === 'inscripciones'" class="panel enrollment-form">
      <div class="panel-heading"><div><h2>Nueva inscripción</h2><p>Asigná un alumno a un curso del ciclo lectivo.</p></div></div>
      <div class="enrollment-fields">
        <FormField id="enroll-student" label="Alumno" required><template #default="{ id }"><select :id="id" v-model="enrollment.studentId"><option disabled value="">Seleccioná un alumno</option><option v-for="student in availableStudents" :key="student.id" :value="student.id">{{ student.surname }}, {{ student.name }}</option></select></template></FormField>
        <FormField id="enroll-course" label="Curso" required><template #default="{ id }"><select :id="id" v-model="enrollment.course"><option disabled value="">Seleccioná un curso</option><option v-for="course in school.courses" :key="course.id" :value="`${course.name.replace(' año', 'º')} ${course.division}`">{{ course.name.replace(' año', 'º') }} {{ course.division }} · {{ course.shift }}</option></select></template></FormField>
        <BaseButton @click="enrollStudent"><Plus :size="16" /> Inscribir alumno</BaseButton>
      </div>
    </section>
    <section class="panel list-panel">
      <div class="list-panel__top"><div><h2>{{ isUsers ? 'Usuarios registrados' : isCourses ? `Listado de ${tab}` : 'Inscripciones registradas' }}</h2><p>{{ rows.length }} {{ rows.length === 1 ? 'registro' : 'registros' }}</p></div><span class="read-only-label"><Users :size="15" /> Datos de demostración</span></div>
      <SearchFilterBar v-model="search" :placeholder="isUsers ? 'Buscar usuario...' : 'Buscar en los registros...'" />
      <DataTable :columns="columns" :rows="rows" empty-title="No hay registros para mostrar">
        <template #cell="{ row, column }">
          <span v-if="column.key === 'name' && isUsers" class="user-name-cell"><span class="avatar avatar--table">{{ row.initials }}</span><strong>{{ row.name }}</strong></span>
          <StatusBadge v-else-if="column.key === 'status'" :status="row.status" />
          <span v-else-if="column.key === 'date'">{{ new Date(`${row.date}T12:00:00`).toLocaleDateString('es-AR') }}</span>
          <span v-else-if="column.key === 'students'">{{ row.students }} estudiantes</span>
          <button v-else-if="column.key === 'actions' && !isUsers" type="button" class="icon-button icon-button--small icon-button--danger" aria-label="Eliminar registro" @click="deleteRow(row)"><Trash2 :size="16" /></button>
          <span v-else>{{ row[column.key] }}</span>
        </template>
      </DataTable>
    </section>
  </div>
</template>
