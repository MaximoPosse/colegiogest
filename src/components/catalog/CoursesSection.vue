<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { BookOpen, ClipboardList, GraduationCap, Pencil, Plus, Trash2, Users, X } from '@lucide/vue'
import BaseButton from '../BaseButton.vue'
import DataTable from '../DataTable.vue'
import FormField from '../FormField.vue'
import SearchFilterBar from '../SearchFilterBar.vue'
import { describeError, isDuplicateError } from '../../lib/errors'
import {
  createAssignment,
  createCourse,
  createSubject,
  deleteAssignment,
  deleteCourse,
  deleteSubject,
  fetchAssignments,
  fetchCourses,
  fetchSubjects,
  fetchTeachers,
  updateAssignment,
  updateCourse,
  updateSubject,
} from '../../services/school'
import { notify } from '../../stores/toast'

const currentYear = new Date().getFullYear()
const tab = ref('cursos')
const search = ref('')
const loading = ref(true)
const saving = ref(false)
const error = ref('')
const formError = ref('')
const courses = ref([])
const assignments = ref([])
const subjects = ref([])
const teachers = ref([])

const showCourseForm = ref(false)
const editingCourseId = ref(null)
const courseForm = reactive({ anio: 3, division: '', turno: 'mañana' })

const showSubjectForm = ref(false)
const editingSubjectId = ref(null)
const subjectForm = reactive({ nombre: '', descripcion: '' })

const showAssignmentForm = ref(false)
const editingAssignmentId = ref(null)
const assignmentForm = reactive({
  subjectId: '',
  courseId: '',
  teacherId: '',
  year: currentYear,
  descripcion: '',
})

const errors = reactive({})

const tabCounts = computed(() => ({
  cursos: courses.value.length,
  materias: subjects.value.length,
  asignaciones: assignments.value.length,
}))

const title = computed(() => ({
  cursos: 'Cursos',
  materias: 'Materias',
  asignaciones: 'Asignaciones docentes',
}[tab.value]))

const newButtonLabel = computed(() => ({
  cursos: 'Nuevo curso',
  materias: 'Nueva materia',
  asignaciones: 'Nueva asignación',
}[tab.value]))

const columns = computed(() => {
  if (tab.value === 'cursos') {
    return [
      { key: 'label', label: 'Curso' },
      { key: 'turno', label: 'Turno' },
      { key: 'students', label: 'Alumnos' },
      { key: 'actions', label: '' },
    ]
  }
  if (tab.value === 'materias') {
    return [
      { key: 'name', label: 'Materia' },
      { key: 'description', label: 'Descripción' },
      { key: 'assignmentCount', label: 'Asignaciones' },
      { key: 'actions', label: '' },
    ]
  }
  return [
    { key: 'subject', label: 'Materia' },
    { key: 'teacher', label: 'Docente' },
    { key: 'course', label: 'Curso' },
    { key: 'year', label: 'Ciclo' },
    { key: 'actions', label: '' },
  ]
})

const subjectOptions = computed(() => subjects.value.map((subject) => ({
  ...subject,
  assignmentCount: assignments.value.filter((item) => item.subjectId === subject.id).length,
})))

const rows = computed(() => {
  const term = search.value.trim().toLocaleLowerCase('es')
  if (tab.value === 'cursos') {
    return courses.value.filter((course) => !term
      || `${course.label} ${course.anio} ${course.division} ${course.turno}`.toLocaleLowerCase('es').includes(term))
  }
  if (tab.value === 'materias') {
    return subjectOptions.value.filter((subject) => !term
      || `${subject.name} ${subject.description}`.toLocaleLowerCase('es').includes(term))
  }
  return assignments.value.filter((item) => !term
    || `${item.subject} ${item.teacher} ${item.course} ${item.year}`.toLocaleLowerCase('es').includes(term))
})

function resetErrors() {
  Object.keys(errors).forEach((key) => delete errors[key])
  formError.value = ''
}

function resetCourseForm() {
  Object.assign(courseForm, { anio: 3, division: '', turno: 'mañana' })
}

function resetSubjectForm() {
  Object.assign(subjectForm, { nombre: '', descripcion: '' })
}

function resetAssignmentForm() {
  Object.assign(assignmentForm, {
    subjectId: subjects.value[0]?.id ?? '',
    courseId: courses.value[0]?.id ?? '',
    teacherId: teachers.value[0]?.id ?? '',
    year: currentYear,
    descripcion: '',
  })
}

function closeForms() {
  showCourseForm.value = false
  showSubjectForm.value = false
  showAssignmentForm.value = false
  editingCourseId.value = null
  editingSubjectId.value = null
  editingAssignmentId.value = null
  resetErrors()
}

function switchTab(next) {
  tab.value = next
  search.value = ''
  closeForms()
}

async function loadAll() {
  loading.value = true
  error.value = ''
  try {
    const [courseRows, assignmentRows, subjectRows, teacherRows] = await Promise.all([
      fetchCourses(),
      fetchAssignments(),
      fetchSubjects(),
      fetchTeachers(),
    ])
    courses.value = courseRows
    assignments.value = assignmentRows
    subjects.value = subjectRows
    teachers.value = teacherRows
  } catch (caught) {
    error.value = describeError(caught)
    notify(error.value, 'error')
  } finally {
    loading.value = false
  }
}

onMounted(loadAll)

function openNew() {
  resetErrors()
  if (tab.value === 'cursos') {
    editingCourseId.value = null
    resetCourseForm()
    showCourseForm.value = true
  } else if (tab.value === 'materias') {
    editingSubjectId.value = null
    resetSubjectForm()
    showSubjectForm.value = true
  } else {
    editingAssignmentId.value = null
    resetAssignmentForm()
    showAssignmentForm.value = true
  }
}

function editCourse(course) {
  resetErrors()
  editingCourseId.value = course.id
  Object.assign(courseForm, {
    anio: course.anio,
    division: course.division,
    turno: course.turnoRaw ?? 'mañana',
  })
  showCourseForm.value = true
}

function editSubject(subject) {
  resetErrors()
  editingSubjectId.value = subject.id
  Object.assign(subjectForm, {
    nombre: subject.name,
    descripcion: subject.description,
  })
  showSubjectForm.value = true
}

function editAssignment(assignment) {
  resetErrors()
  editingAssignmentId.value = assignment.id
  Object.assign(assignmentForm, {
    subjectId: assignment.subjectId,
    courseId: assignment.courseId,
    teacherId: assignment.teacherId,
    year: assignment.year,
    descripcion: '',
  })
  showAssignmentForm.value = true
}

async function saveCourse() {
  resetErrors()
  if (!Number(courseForm.anio) || Number(courseForm.anio) < 1 || Number(courseForm.anio) > 12) {
    errors.anio = 'Ingresá un año entre 1 y 12.'
  }
  if (!courseForm.division.trim()) errors.division = 'La división es obligatoria.'
  if (Object.keys(errors).length) return

  saving.value = true
  try {
    const payload = {
      anio: Number(courseForm.anio),
      division: courseForm.division.trim().toUpperCase(),
      turno: courseForm.turno,
    }
    if (editingCourseId.value) {
      await updateCourse(editingCourseId.value, payload)
      notify('El curso se actualizó correctamente.')
    } else {
      await createCourse(payload)
      notify('El curso se creó correctamente.')
    }
    showCourseForm.value = false
    editingCourseId.value = null
    await loadAll()
  } catch (caught) {
    formError.value = describeError(caught)
    notify(formError.value, 'error')
  } finally {
    saving.value = false
  }
}

async function saveSubject() {
  resetErrors()
  if (!subjectForm.nombre.trim()) errors.nombre = 'El nombre de la materia es obligatorio.'
  if (subjectForm.nombre.trim().length > 120) errors.nombre = 'Máximo 120 caracteres.'
  if (Object.keys(errors).length) return

  saving.value = true
  try {
    if (editingSubjectId.value) {
      await updateSubject(editingSubjectId.value, {
        nombre: subjectForm.nombre,
        descripcion: subjectForm.descripcion,
      })
      notify('La materia se actualizó correctamente.')
    } else {
      await createSubject({
        nombre: subjectForm.nombre,
        descripcion: subjectForm.descripcion,
      })
      notify('La materia se creó correctamente.')
    }
    showSubjectForm.value = false
    editingSubjectId.value = null
    await loadAll()
  } catch (caught) {
    if (isDuplicateError(caught, 'subject')) errors.nombre = 'Ya existe una materia con ese nombre.'
    else formError.value = describeError(caught)
    notify(describeError(caught), 'error')
  } finally {
    saving.value = false
  }
}

async function saveAssignment() {
  resetErrors()
  if (!editingAssignmentId.value && !assignmentForm.subjectId) {
    errors.subjectId = 'Seleccioná una materia.'
  }
  if (!editingAssignmentId.value && !assignmentForm.courseId) {
    errors.courseId = 'Seleccioná un curso.'
  }
  if (!assignmentForm.teacherId) errors.teacherId = 'Seleccioná un docente.'
  if (!Number(assignmentForm.year) || Number(assignmentForm.year) < 2000 || Number(assignmentForm.year) > 2100) {
    errors.year = 'Ingresá un ciclo lectivo válido.'
  }
  if (Object.keys(errors).length) return

  saving.value = true
  try {
    if (editingAssignmentId.value) {
      await updateAssignment(editingAssignmentId.value, {
        teacherId: assignmentForm.teacherId,
        year: assignmentForm.year,
      })
      notify('La asignación se actualizó correctamente.')
    } else {
      const subject = subjects.value.find((item) => item.id === assignmentForm.subjectId)
      await createAssignment({
        materia: subject?.name ?? '',
        courseId: assignmentForm.courseId,
        teacherId: assignmentForm.teacherId,
        year: assignmentForm.year,
        descripcion: assignmentForm.descripcion,
      })
      notify('La asignación docente se creó correctamente.')
    }
    showAssignmentForm.value = false
    editingAssignmentId.value = null
    await loadAll()
  } catch (caught) {
    formError.value = describeError(caught)
    notify(formError.value, 'error')
  } finally {
    saving.value = false
  }
}

async function deleteCourseRow(course) {
  if (saving.value) return
  if (!window.confirm(`¿Eliminar el curso «${course.label}»? Esta acción se guarda en Supabase.`)) return
  saving.value = true
  try {
    await deleteCourse(course.id)
    notify('El curso se eliminó.')
    await loadAll()
  } catch (caught) {
    notify(describeError(caught), 'error')
  } finally {
    saving.value = false
  }
}

async function deleteSubjectRow(subject) {
  if (saving.value) return
  if (!window.confirm(`¿Eliminar la materia «${subject.name}»?`)) return
  saving.value = true
  try {
    await deleteSubject(subject.id)
    notify('La materia se eliminó.')
    await loadAll()
  } catch (caught) {
    notify(describeError(caught), 'error')
  } finally {
    saving.value = false
  }
}

async function deleteAssignmentRow(assignment) {
  if (saving.value) return
  if (!window.confirm(`¿Eliminar la asignación de «${assignment.subject}» en ${assignment.course}?`)) return
  saving.value = true
  try {
    await deleteAssignment(assignment.id)
    notify('La asignación se eliminó.')
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
        <div class="breadcrumb">Gestión escolar <span>/</span> <b>Cursos y materias</b></div>
        <h1>Cursos y materias</h1>
        <p>Organizá los cursos, el catálogo de materias y las asignaciones docentes.</p>
      </div>
      <BaseButton @click="openNew"><Plus :size="17" /> {{ newButtonLabel }}</BaseButton>
    </div>

    <div class="catalog-tabs" role="tablist" aria-label="Tipo de registro">
      <button type="button" role="tab" :aria-selected="tab === 'cursos'" :class="{ 'catalog-tab--active': tab === 'cursos' }" @click="switchTab('cursos')">
        <GraduationCap :size="17" /> Cursos <span>{{ tabCounts.cursos }}</span>
      </button>
      <button type="button" role="tab" :aria-selected="tab === 'materias'" :class="{ 'catalog-tab--active': tab === 'materias' }" @click="switchTab('materias')">
        <BookOpen :size="17" /> Materias <span>{{ tabCounts.materias }}</span>
      </button>
      <button type="button" role="tab" :aria-selected="tab === 'asignaciones'" :class="{ 'catalog-tab--active': tab === 'asignaciones' }" @click="switchTab('asignaciones')">
        <ClipboardList :size="17" /> Asignaciones <span>{{ tabCounts.asignaciones }}</span>
      </button>
    </div>

    <form v-if="showCourseForm" class="panel catalog-form" novalidate @submit.prevent="saveCourse">
      <div class="panel-heading">
        <div><h2>{{ editingCourseId ? 'Editar curso' : 'Crear un curso' }}</h2><p>Los datos se guardan directamente en Supabase.</p></div>
        <button type="button" class="icon-button" aria-label="Cerrar formulario" @click="closeForms"><X :size="18" /></button>
      </div>
      <div class="form-grid">
        <FormField id="catalog-year" label="Año / grado" :error="errors.anio" required>
          <template #default="{ id }"><input :id="id" v-model.number="courseForm.anio" type="number" min="1" max="12" placeholder="Ej. 3" /></template>
        </FormField>
        <FormField id="catalog-division" label="División" :error="errors.division" required>
          <template #default="{ id }"><input :id="id" v-model="courseForm.division" placeholder="Ej. A" maxlength="10" /></template>
        </FormField>
        <FormField id="catalog-shift" label="Turno">
          <template #default="{ id }">
            <select :id="id" v-model="courseForm.turno">
              <option value="mañana">Mañana</option>
              <option value="tarde">Tarde</option>
              <option value="noche">Noche</option>
            </select>
          </template>
        </FormField>
      </div>
      <div v-if="formError" class="form-note form-note--error"><span>!</span><p>{{ formError }}</p></div>
      <div class="form-actions">
        <BaseButton variant="outline" @click="closeForms">Cancelar</BaseButton>
        <BaseButton type="submit" :disabled="saving"><Plus :size="16" /> {{ saving ? 'Guardando…' : editingCourseId ? 'Guardar cambios' : 'Crear curso' }}</BaseButton>
      </div>
    </form>

    <form v-if="showSubjectForm" class="panel catalog-form" novalidate @submit.prevent="saveSubject">
      <div class="panel-heading">
        <div><h2>{{ editingSubjectId ? 'Editar materia' : 'Crear una materia' }}</h2><p>Las materias se comparten entre cursos y asignaciones.</p></div>
        <button type="button" class="icon-button" aria-label="Cerrar formulario" @click="closeForms"><X :size="18" /></button>
      </div>
      <div class="form-grid">
        <FormField id="subject-name" label="Nombre de la materia" :error="errors.nombre" required>
          <template #default="{ id }"><input :id="id" v-model="subjectForm.nombre" placeholder="Ej. Geografía" maxlength="120" /></template>
        </FormField>
        <FormField id="subject-description" label="Descripción">
          <template #default="{ id }"><input :id="id" v-model="subjectForm.descripcion" placeholder="Opcional" maxlength="500" /></template>
        </FormField>
      </div>
      <div v-if="formError" class="form-note form-note--error"><span>!</span><p>{{ formError }}</p></div>
      <div class="form-actions">
        <BaseButton variant="outline" @click="closeForms">Cancelar</BaseButton>
        <BaseButton type="submit" :disabled="saving"><Plus :size="16" /> {{ saving ? 'Guardando…' : editingSubjectId ? 'Guardar cambios' : 'Crear materia' }}</BaseButton>
      </div>
    </form>

    <form v-if="showAssignmentForm" class="panel catalog-form" novalidate @submit.prevent="saveAssignment">
      <div class="panel-heading">
        <div>
          <h2>{{ editingAssignmentId ? 'Editar asignación' : 'Crear una asignación' }}</h2>
          <p>{{ editingAssignmentId ? 'Podés cambiar el docente y el ciclo lectivo.' : 'Relacioná una materia con un curso y un docente.' }}</p>
        </div>
        <button type="button" class="icon-button" aria-label="Cerrar formulario" @click="closeForms"><X :size="18" /></button>
      </div>
      <div class="form-grid">
        <FormField id="assignment-subject" label="Materia" :error="errors.subjectId" required>
          <template #default="{ id }">
            <select :id="id" v-model="assignmentForm.subjectId" :disabled="Boolean(editingAssignmentId)">
              <option disabled value="">Seleccioná una materia</option>
              <option v-for="subject in subjects" :key="subject.id" :value="subject.id">{{ subject.name }}</option>
            </select>
          </template>
        </FormField>
        <FormField id="assignment-course" label="Curso" :error="errors.courseId" required>
          <template #default="{ id }">
            <select :id="id" v-model="assignmentForm.courseId" :disabled="Boolean(editingAssignmentId)">
              <option disabled value="">Seleccioná un curso</option>
              <option v-for="course in courses" :key="course.id" :value="course.id">{{ course.label }} · {{ course.turno }}</option>
            </select>
          </template>
        </FormField>
        <FormField id="assignment-teacher" label="Docente asignado" :error="errors.teacherId" required>
          <template #default="{ id }">
            <select :id="id" v-model="assignmentForm.teacherId">
              <option disabled value="">Seleccioná un profesor</option>
              <option v-for="teacher in teachers" :key="teacher.id" :value="teacher.id">{{ teacher.fullName }}</option>
            </select>
          </template>
        </FormField>
        <FormField id="assignment-year" label="Ciclo lectivo" :error="errors.year" required>
          <template #default="{ id }"><input :id="id" v-model.number="assignmentForm.year" type="number" min="2000" max="2100" /></template>
        </FormField>
        <FormField v-if="!editingAssignmentId" id="assignment-description" label="Descripción">
          <template #default="{ id }"><input :id="id" v-model="assignmentForm.descripcion" placeholder="Opcional" /></template>
        </FormField>
      </div>
      <div v-if="formError" class="form-note form-note--error"><span>!</span><p>{{ formError }}</p></div>
      <div v-if="!subjects.length" class="form-note"><span>i</span><p>Creá primero una materia en la pestaña Materias para poder asignarla.</p></div>
      <div v-if="!teachers.length" class="form-note"><span>i</span><p>No hay profesores activos. Creá o reactivá un docente desde la sección Profesores.</p></div>
      <div class="form-actions">
        <BaseButton variant="outline" @click="closeForms">Cancelar</BaseButton>
        <BaseButton type="submit" :disabled="saving"><Plus :size="16" /> {{ saving ? 'Guardando…' : editingAssignmentId ? 'Guardar cambios' : 'Crear asignación' }}</BaseButton>
      </div>
    </form>

    <section class="panel list-panel">
      <div class="list-panel__top">
        <div><h2>{{ title }}</h2><p>{{ rows.length }} {{ rows.length === 1 ? 'registro' : 'registros' }}</p></div>
        <span class="read-only-label"><Users :size="15" /> Datos en Supabase</span>
      </div>
      <SearchFilterBar v-model="search" placeholder="Buscar en los registros..." />
      <DataTable
        :columns="columns"
        :rows="rows"
        paginated
        :page-size="10"
        :empty-title="loading ? 'Cargando registros...' : 'No hay registros para mostrar'"
        :empty-text="loading ? 'Estamos consultando la base de datos.' : 'Probá ajustar la búsqueda o creá un nuevo registro.'"
      >
        <template #cell="{ row, column }">
          <span v-if="column.key === 'turno'" class="capitalize">{{ row.turno }}</span>
          <span v-else-if="column.key === 'students'">{{ row.students }} estudiantes</span>
          <span v-else-if="column.key === 'description'">{{ row.description || '—' }}</span>
          <span v-else-if="column.key === 'assignmentCount'">{{ row.assignmentCount }}</span>
          <div v-else-if="column.key === 'actions'" class="table-actions">
            <template v-if="tab === 'cursos'">
              <button type="button" class="icon-button icon-button--small" :aria-label="`Editar ${row.label}`" @click="editCourse(row)"><Pencil :size="16" /></button>
              <button type="button" class="icon-button icon-button--small icon-button--danger" :disabled="saving" :aria-label="`Eliminar ${row.label}`" @click="deleteCourseRow(row)"><Trash2 :size="16" /></button>
            </template>
            <template v-else-if="tab === 'materias'">
              <button type="button" class="icon-button icon-button--small" :aria-label="`Editar ${row.name}`" @click="editSubject(row)"><Pencil :size="16" /></button>
              <button type="button" class="icon-button icon-button--small icon-button--danger" :disabled="saving" :aria-label="`Eliminar ${row.name}`" @click="deleteSubjectRow(row)"><Trash2 :size="16" /></button>
            </template>
            <template v-else>
              <button type="button" class="icon-button icon-button--small" :aria-label="`Editar asignación de ${row.subject}`" @click="editAssignment(row)"><Pencil :size="16" /></button>
              <button type="button" class="icon-button icon-button--small icon-button--danger" :disabled="saving" :aria-label="`Eliminar asignación de ${row.subject}`" @click="deleteAssignmentRow(row)"><Trash2 :size="16" /></button>
            </template>
          </div>
          <span v-else>{{ row[column.key] }}</span>
        </template>
      </DataTable>
    </section>
  </div>
</template>
