<script setup>
import { computed, reactive, ref } from 'vue'
import { CalendarCheck, Check, Save } from '@lucide/vue'
import BaseButton from '../components/BaseButton.vue'
import DataTable from '../components/DataTable.vue'
import FormField from '../components/FormField.vue'
import StatusBadge from '../components/StatusBadge.vue'
import { notify, school } from '../data/demoStore'

const course = ref('3.º A')
const subject = ref('Matemática')
const date = ref('2026-11-05')
const saved = ref(true)
const statuses = ['Presente', 'Ausente', 'Tardanza', 'Justificada']
const drafts = reactive({})
const courseOptions = computed(() => [...new Set(school.students.map((student) => student.course))])
const students = computed(() => school.students.filter((student) => student.course === course.value))
const summary = computed(() => statuses.reduce((result, status) => {
  result[status] = students.value.filter((student) => drafts[student.id] === status).length
  return result
}, {}))
const columns = [
  { key: 'student', label: 'Alumno' },
  { key: 'dni', label: 'DNI' },
  { key: 'attendance', label: 'Asistencia de hoy' },
]

function currentStatus(studentId) {
  if (!(studentId in drafts)) {
    const record = school.attendance.find((item) => item.studentId === studentId && item.date === date.value && item.course === course.value)
    drafts[studentId] = record?.status ?? ''
  }
  return drafts[studentId]
}

function setStatus(studentId, status) {
  drafts[studentId] = status
  saved.value = false
}

function saveAttendance() {
  const unmarked = students.value.filter((student) => !currentStatus(student.id))
  if (unmarked.length) {
    notify(`Todavía falta marcar a ${unmarked.length} ${unmarked.length === 1 ? 'alumno' : 'alumnos'}.`, 'error')
    return
  }
  for (const student of students.value) {
    const previous = school.attendance.find((item) => item.studentId === student.id && item.date === date.value && item.course === course.value && item.subject === subject.value)
    if (previous) previous.status = drafts[student.id]
    else school.attendance.push({ id: `as-${Date.now()}-${student.id}`, studentId: student.id, date: date.value, course: course.value, subject: subject.value, status: drafts[student.id] })
  }
  saved.value = true
  notify('La asistencia se guardó en los datos de esta sesión.')
}
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <div><div class="breadcrumb">Mi espacio docente <span>/</span> <b>Asistencia</b></div><h1>Registro de asistencia</h1><p>Tomá asistencia para tu curso y materia.</p></div>
      <div class="attendance-date"><CalendarCheck :size="17" /><span>Jueves, 5 de noviembre</span></div>
    </div>
    <section class="attendance-filters panel">
      <FormField id="attendance-course" label="Curso"><template #default="{ id }"><select :id="id" v-model="course" @change="saved = false"><option v-for="item in courseOptions" :key="item">{{ item }}</option></select></template></FormField>
      <FormField id="attendance-subject" label="Materia"><template #default="{ id }"><select :id="id" v-model="subject" @change="saved = false"><option>Matemática</option><option>Lengua y Literatura</option><option>Ciencias Naturales</option><option>Historia</option></select></template></FormField>
      <FormField id="attendance-date" label="Fecha"><template #default="{ id }"><input :id="id" v-model="date" type="date" @change="saved = false" /></template></FormField>
    </section>
    <section class="attendance-summary">
      <div v-for="status in statuses" :key="status" class="attendance-summary__item" :class="`attendance-summary__item--${status.toLowerCase()}`"><span>{{ summary[status] ?? 0 }}</span><small>{{ status }}</small></div>
    </section>
    <section class="panel list-panel">
      <div class="list-panel__top"><div><h2>Alumnos del curso</h2><p>{{ students.length }} estudiantes · Seleccioná el estado de cada uno</p></div><BaseButton v-if="!saved" variant="outline" @click="notify('Tenés cambios sin guardar en la asistencia.', 'error')">Cambios sin guardar</BaseButton><span v-else class="saved-label"><Check :size="15" /> Guardado</span></div>
      <DataTable :columns="columns" :rows="students" empty-title="No hay alumnos inscriptos" empty-text="Elegí otro curso para tomar asistencia.">
        <template #cell="{ row, column }">
          <div v-if="column.key === 'student'" class="student-cell"><span class="avatar avatar--table">{{ row.name.charAt(0) }}{{ row.surname.charAt(0) }}</span><span><strong>{{ row.surname }}, {{ row.name }}</strong><small>Estudiante</small></span></div>
          <div v-else-if="column.key === 'attendance'" class="attendance-options">
            <button v-for="status in statuses" :key="status" type="button" class="attendance-option" :class="[{ 'attendance-option--selected': currentStatus(row.id) === status }, `attendance-option--${status.toLowerCase()}`]" :aria-pressed="currentStatus(row.id) === status" @click="setStatus(row.id, status)">{{ status }}</button>
          </div>
          <span v-else>{{ row[column.key] }}</span>
        </template>
      </DataTable>
      <div class="form-actions form-actions--table"><span class="table-helper">Los cambios se conservan solo durante esta sesión.</span><BaseButton @click="saveAttendance"><Save :size="16" /> Guardar asistencia</BaseButton></div>
    </section>
  </div>
</template>
