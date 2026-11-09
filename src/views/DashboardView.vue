<script setup>
import { computed, onMounted, ref } from 'vue'
import {
  ArrowRight, Bell, BookOpen, CalendarCheck, CalendarClock, CalendarDays, ClipboardCheck,
  ClipboardList, GraduationCap, Megaphone, Plus, TrendingUp, Users,
} from '@lucide/vue'
import StatCard from '../components/StatCard.vue'
import StatusBadge from '../components/StatusBadge.vue'
import BaseButton from '../components/BaseButton.vue'
import { describeError } from '../lib/errors'
import { formatDate, todayLongLabel } from '../lib/format'
import { fetchDashboard } from '../services/dashboard'
import { session } from '../stores/auth'

const user = computed(() => session.user)
const role = computed(() => user.value?.role)
const title = computed(() => role.value === 'administrador' ? 'Panel principal' : role.value === 'profesor' ? 'Mi espacio docente' : 'Mi espacio escolar')
const greeting = computed(() => role.value === 'alumno' ? '¡Hola' : '¡Buen día')
const loading = ref(true)
const error = ref('')
const data = ref(null)
const iconMap = { Users, BookOpen, GraduationCap, Megaphone, TrendingUp, CalendarCheck, ClipboardList }
const stats = computed(() => (data.value?.stats ?? []).map((item) => ({ ...item, icon: iconMap[item.icon] ?? ClipboardList })))
const recentNotices = computed(() => data.value?.notices ?? [])
const nextActivities = computed(() => data.value?.upcoming ?? [])
const agenda = computed(() => data.value?.agenda ?? [])
const today = computed(() => todayLongLabel())
const todayBadge = computed(() => new Intl.DateTimeFormat('es-AR', { weekday: 'long', day: 'numeric', month: 'short' }).format(new Date()).toUpperCase())
const adminStudents = computed(() => stats.value.find((item) => item.label === 'Alumnos activos')?.value ?? 0)
const adminCourses = computed(() => stats.value.find((item) => item.label === 'Cursos')?.value ?? 0)

const shortcuts = computed(() => {
  if (role.value === 'administrador') return [
    { label: 'Alumnos', description: 'Administrá el registro escolar', to: '/app/alumnos', icon: Users, tone: 'blue' },
    { label: 'Cursos y materias', description: 'Organizá la propuesta académica', to: '/app/cursos', icon: BookOpen, tone: 'green' },
    { label: 'Inscripciones', description: 'Gestioná las inscripciones', to: '/app/inscripciones', icon: GraduationCap, tone: 'rose' },
  ]
  if (role.value === 'profesor') return [
    { label: 'Tomar asistencia', description: 'Registrá la asistencia del curso', to: '/app/asistencia', icon: CalendarCheck, tone: 'blue' },
    { label: 'Calificaciones', description: 'Cargá y consultá las notas', to: '/app/calificaciones', icon: ClipboardList, tone: 'green' },
    { label: 'Actividades', description: 'Compartí actividades con tus cursos', to: '/app/actividades', icon: CalendarDays, tone: 'rose' },
  ]
  return [
    { label: 'Mis calificaciones', description: 'Consultá tu progreso académico', to: '/app/mis-calificaciones', icon: ClipboardCheck, tone: 'blue' },
    { label: 'Mis actividades', description: 'Revisá tus próximas entregas', to: '/app/mis-actividades', icon: CalendarDays, tone: 'green' },
    { label: 'Mis materias', description: 'Conocé tus materias y horarios', to: '/app/mis-cursos', icon: BookOpen, tone: 'rose' },
  ]
})

onMounted(async () => {
  loading.value = true
  error.value = ''
  try {
    data.value = await fetchDashboard(user.value)
  } catch (caught) {
    error.value = describeError(caught)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="page">
    <div class="page-heading page-heading--dashboard">
      <div><div class="breadcrumb">Inicio <span>/</span> <b>{{ title }}</b></div><h1>{{ title }}</h1><p>{{ greeting }}, {{ user?.name }}. Este es el resumen de hoy, {{ today }}.</p></div>
      <RouterLink v-if="role === 'administrador'" to="/app/alumnos/nuevo"><BaseButton><Plus :size="17" /> Nuevo alumno</BaseButton></RouterLink>
    </div>
    <div v-if="loading" class="panel empty-state"><h3>Cargando el panel...</h3><p>Estamos consultando la información de tu cuenta.</p></div>
    <div v-else-if="error" class="panel empty-state"><h3>No pudimos cargar el panel</h3><p>{{ error }}</p></div>
    <template v-else>
      <section class="stats-grid" aria-label="Resumen de actividad">
        <StatCard v-for="item in stats" :key="item.label" v-bind="item" />
      </section>
      <section class="dashboard-shortcuts">
        <div class="section-heading"><div><h2>Accesos rápidos</h2><p>Lo que necesitás, a un clic</p></div></div>
        <div class="shortcut-grid">
          <RouterLink v-for="item in shortcuts" :key="item.label" :to="item.to" class="shortcut-card">
            <span class="shortcut-card__icon" :class="`shortcut-card__icon--${item.tone}`"><component :is="item.icon" :size="20" /></span>
            <span class="shortcut-card__copy"><strong>{{ item.label }}</strong><small>{{ item.description }}</small></span><ArrowRight :size="17" class="shortcut-card__arrow" />
          </RouterLink>
        </div>
      </section>
      <div class="dashboard-columns">
        <section class="panel dashboard-panel">
          <div class="panel-heading"><div><h2>{{ role === 'alumno' ? 'Próximas actividades' : 'Últimos avisos' }}</h2><p>{{ role === 'alumno' ? 'Tus próximos desafíos' : 'Novedades de la comunidad' }}</p></div><RouterLink :to="role === 'alumno' ? '/app/mis-actividades' : '/app/avisos'" class="text-link">Ver todos <ArrowRight :size="15" /></RouterLink></div>
          <div v-if="role === 'alumno'" class="activity-preview-list">
            <article v-for="activity in nextActivities" :key="activity.id" class="activity-preview"><span class="activity-preview__date"><CalendarDays :size="17" /></span><div><strong>{{ activity.title }}</strong><small>{{ activity.subject }} · Entrega {{ formatDate(activity.dueDate) }}</small></div><StatusBadge :status="activity.status" /></article>
            <p v-if="!nextActivities.length" class="muted-empty">No tenés actividades pendientes.</p>
          </div>
          <div v-else class="notice-preview-list">
            <article v-for="notice in recentNotices" :key="notice.id" class="notice-preview"><span class="notice-preview__icon"><Bell :size="17" /></span><div><strong>{{ notice.title }}</strong><small>{{ notice.audience }} · {{ formatDate(notice.date) }}</small></div><ArrowRight :size="16" /></article>
            <p v-if="!recentNotices.length" class="muted-empty">Todavía no hay avisos publicados.</p>
          </div>
        </section>
        <section class="panel today-panel">
          <div class="today-panel__top"><span><CalendarClock :size="17" /></span><span>{{ todayBadge }}</span></div>
          <h2>{{ role === 'alumno' ? 'Tu día de clases' : role === 'profesor' ? 'Tu agenda de hoy' : 'La escuela en números' }}</h2>
          <p>{{ role === 'administrador' ? 'La comunidad sigue en movimiento.' : 'Un vistazo a lo que viene.' }}</p>
          <div v-if="role !== 'administrador'" class="agenda-list">
            <div v-for="(item, index) in agenda" :key="`${item.title}-${index}`" class="agenda-item"><time>{{ item.time || '—' }}</time><i class="agenda-line" :class="{ 'agenda-line--rose': index % 2 === 1, 'agenda-line--green': index % 3 === 2 }"></i><div><b>{{ item.title }}</b><small>{{ item.detail }}</small></div></div>
            <p v-if="!agenda.length" class="muted-empty">No hay información de agenda disponible.</p>
          </div>
          <div v-else class="school-overview"><div><span class="overview-dot overview-dot--green"></span><strong>{{ adminStudents }} alumnos</strong><small>activos en la institución</small></div><div><span class="overview-dot overview-dot--blue"></span><strong>{{ adminCourses }} cursos</strong><small>registrados en Supabase</small></div></div>
          <RouterLink class="today-panel__link" :to="role === 'alumno' ? '/app/mis-cursos' : role === 'profesor' ? '/app/mis-cursos' : '/app/avisos'">{{ role === 'administrador' ? 'Ir a los avisos' : 'Ver mi agenda' }} <ArrowRight :size="15" /></RouterLink>
        </section>
      </div>
    </template>
  </div>
</template>
