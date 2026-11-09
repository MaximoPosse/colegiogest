<script setup>
import { computed, onMounted, ref } from 'vue'
import { BookOpen, Clock3, GraduationCap, MapPin, UserRound } from '@lucide/vue'
import { describeError } from '../lib/errors'
import { fetchAssignments, fetchStudents } from '../services/school'
import { session } from '../stores/auth'

const isStudent = computed(() => session.user?.role === 'alumno')
const assignments = ref([])
const students = ref([])
const loading = ref(true)
const error = ref('')
const subjects = computed(() => assignments.value)
const years = computed(() => [...new Set(assignments.value.map((item) => item.year).filter(Boolean))])
const cycleLabel = computed(() => years.value.length === 1 ? `Ciclo lectivo ${years.value[0]}` : 'Ciclos lectivos vigentes')
const courseLabel = computed(() => {
  if (!isStudent.value) return cycleLabel.value
  const curso = session.user?.curso
  return curso ? `${curso.anio}.º año · División ${curso.division}` : 'Sin curso activo'
})

function studentCount(courseId) {
  return students.value.filter((student) => student.courseId === courseId && student.estado === 'activo').length
}

onMounted(async () => {
  loading.value = true
  try {
    if (!session.user) return
    if (isStudent.value) {
      assignments.value = session.user.inscripcion?.id_curso
        ? await fetchAssignments({ courseId: session.user.inscripcion.id_curso })
        : []
    } else {
      const [assignmentRows, studentRows] = await Promise.all([
        fetchAssignments({ teacherId: session.user.profesorId }),
        fetchStudents(),
      ])
      assignments.value = assignmentRows
      students.value = studentRows
    }
  } catch (caught) {
    error.value = describeError(caught)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="page">
    <div class="page-heading"><div><div class="breadcrumb">Mi espacio <span>/</span> <b>Mis cursos</b></div><h1>{{ isStudent ? 'Mis materias' : 'Mis cursos y alumnos' }}</h1><p>{{ isStudent ? 'Consultá las materias y los horarios de tu curso.' : 'Una vista rápida de las materias que tenés asignadas.' }}</p></div><span class="read-only-label"><BookOpen :size="16" /> {{ courseLabel }}</span></div>
    <div v-if="loading" class="panel empty-state"><h3>Cargando materias...</h3><p>Estamos consultando tus asignaciones.</p></div>
    <div v-else-if="error" class="panel empty-state"><h3>No pudimos cargar tus materias</h3><p>{{ error }}</p></div>
    <div v-else class="course-card-grid">
      <article v-for="(subject, index) in subjects" :key="subject.id" class="panel course-card">
        <div class="course-card__cover" :class="`course-card__cover--${index % 4}`"><span>{{ subject.subject.slice(0, 1) }}</span><div class="course-card__cover-icon"><BookOpen :size="20" /></div></div>
        <div class="course-card__body"><span class="course-card__eyebrow">{{ subject.course }} · {{ subject.year }}</span><h2>{{ subject.subject }}</h2><div class="course-card__details"><span><UserRound :size="15" /> {{ subject.teacher }}</span><span><Clock3 :size="15" /> {{ subject.schedule }}</span><span><MapPin :size="15" /> Aula a definir</span></div><div v-if="!isStudent" class="course-card__footer"><span><GraduationCap :size="15" /> {{ studentCount(subject.courseId) }} alumnos</span><RouterLink to="/app/asistencia">Ir a asistencia <span>→</span></RouterLink></div></div>
      </article>
      <div v-if="!subjects.length" class="panel empty-state"><h3>No hay materias asignadas</h3><p>Cuando se registren asignaciones para tu perfil, las vas a encontrar acá.</p></div>
    </div>
  </div>
</template>
