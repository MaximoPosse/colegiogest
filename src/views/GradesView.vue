<script setup>
import { computed, reactive, ref } from 'vue'
import { Award, BookOpen, Check, ClipboardList, Save, TrendingUp } from '@lucide/vue'
import BaseButton from '../components/BaseButton.vue'
import DataTable from '../components/DataTable.vue'
import SearchFilterBar from '../components/SearchFilterBar.vue'
import StatCard from '../components/StatCard.vue'
import { notify, school, session } from '../data/demoStore'

const role = computed(() => session.user?.role)
const isStudent = computed(() => role.value === 'alumno')
const isTeacher = computed(() => role.value === 'profesor')
const search = ref('')
const subjectFilter = ref('')
const drafts = reactive({})
const subjects = computed(() => [...new Set(school.grades.map((grade) => grade.subject))])
const studentGrades = computed(() => school.grades.filter((grade) => grade.studentId === 'a-01'))
const visibleGrades = computed(() => {
  const source = isStudent.value ? studentGrades.value : school.grades
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
  ...(!isStudent.value ? [{ key: 'teacher', label: 'Docente' }] : []),
])
const filters = computed(() => [{ key: 'subject', label: 'Filtrar por materia', value: subjectFilter.value, options: [{ label: 'Todas las materias', value: '' }, ...subjects.value.map((subject) => ({ label: subject, value: subject }))] }])

function updateFilter({ key, value }) {
  if (key === 'subject') subjectFilter.value = value
}

function saveGrades() {
  let changed = 0
  for (const grade of school.grades) {
    if (drafts[grade.id] !== undefined && drafts[grade.id] !== '') {
      const value = Number(drafts[grade.id])
      if (value >= 1 && value <= 10) {
        grade.grade = value
        changed++
      }
    }
  }
  if (!changed) {
    notify('No hay calificaciones válidas para guardar (la nota debe ser de 1 a 10).', 'error')
    return
  }
  notify(`${changed} ${changed === 1 ? 'calificación actualizada' : 'calificaciones actualizadas'} en esta sesión.`)
  Object.keys(drafts).forEach((key) => delete drafts[key])
}
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <div><div class="breadcrumb">{{ isStudent ? 'Mi espacio escolar' : 'Mi espacio docente' }} <span>/</span> <b>Calificaciones</b></div><h1>{{ isStudent ? 'Mis calificaciones' : 'Calificaciones' }}</h1><p>{{ isStudent ? 'Consultá tus notas y seguí tu progreso en cada materia.' : isTeacher ? 'Cargá y actualizá las calificaciones de tus alumnos.' : 'Consulta de calificaciones de los cursos.' }}</p></div>
      <span v-if="isStudent" class="read-only-label"><BookOpen :size="16" /> Solo lectura</span>
    </div>
    <section v-if="isStudent" class="stats-grid stats-grid--grades">
      <StatCard label="Promedio general" :value="average" detail="Sobre 10 puntos" :icon="TrendingUp" tone="blue" />
      <StatCard label="Materias con nota" :value="subjects.length" detail="Este trimestre" :icon="BookOpen" tone="green" />
      <StatCard label="Calificaciones" :value="studentGrades.length" detail="Registradas hasta hoy" :icon="Award" tone="rose" />
    </section>
    <section class="panel list-panel">
      <div class="list-panel__top"><div><h2>{{ isStudent ? 'Detalle por materia' : 'Registro de calificaciones' }}</h2><p>{{ visibleGrades.length }} registros encontrados</p></div><span v-if="isTeacher" class="table-helper">Ingresá notas entre 1 y 10</span></div>
      <SearchFilterBar v-model="search" :placeholder="isStudent ? 'Buscar por materia o instancia...' : 'Buscar por alumno, materia o instancia...'" :filters="filters" @filter="updateFilter" />
      <DataTable :columns="columns" :rows="visibleGrades" empty-title="Todavía no hay calificaciones" empty-text="Cuando se registren notas, las vas a encontrar acá.">
        <template #cell="{ row, column }">
          <strong v-if="column.key === 'grade'" class="grade-mark" :class="{ 'grade-mark--pass': row.grade >= 6 }">
            <template v-if="isTeacher"><input v-model="drafts[row.id]" class="grade-input" type="number" min="1" max="10" :aria-label="`Nota de ${row.student} en ${row.subject}`" :placeholder="String(row.grade)" /><span>/ 10</span></template>
            <template v-else>{{ row.grade }}<span>/ 10</span></template>
          </strong>
          <span v-else-if="column.key === 'date'">{{ new Date(`${row.date}T12:00:00`).toLocaleDateString('es-AR', { day: '2-digit', month: 'short', year: 'numeric' }) }}</span>
          <span v-else>{{ row[column.key] }}</span>
        </template>
      </DataTable>
      <div v-if="isTeacher" class="form-actions form-actions--table"><span class="table-helper"><Check :size="14" /> Las notas solo se guardan en esta sesión</span><BaseButton @click="saveGrades"><Save :size="16" /> Guardar cambios</BaseButton></div>
    </section>
  </div>
</template>
