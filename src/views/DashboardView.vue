<script setup>
import { computed } from 'vue'
import {
  ArrowRight, Bell, BookOpen, CalendarCheck, CalendarClock, CalendarDays, ClipboardCheck,
  ClipboardList, GraduationCap, Megaphone, Plus, TrendingUp, Users,
} from '@lucide/vue'
import StatCard from '../components/StatCard.vue'
import StatusBadge from '../components/StatusBadge.vue'
import BaseButton from '../components/BaseButton.vue'
import { school, session } from '../data/demoStore'

const user = computed(() => session.user)
const role = computed(() => user.value?.role)
const title = computed(() => role.value === 'administrador' ? 'Panel principal' : role.value === 'profesor' ? 'Mi espacio docente' : 'Mi espacio escolar')
const greeting = computed(() => role.value === 'alumno' ? '¡Hola' : '¡Buen día')
const stats = computed(() => {
  if (role.value === 'administrador') return [
    { label: 'Alumnos activos', value: school.students.filter((student) => student.status === 'Activo').length, detail: '+12 desde el último ciclo', icon: Users, tone: 'blue' },
    { label: 'Cursos', value: school.courses.length, detail: 'En ambos turnos', icon: BookOpen, tone: 'green' },
    { label: 'Profesores', value: '18', detail: 'En actividad', icon: GraduationCap, tone: 'rose' },
    { label: 'Avisos publicados', value: school.notices.length, detail: 'Este mes', icon: Megaphone, tone: 'amber' },
  ]
  if (role.value === 'profesor') return [
    { label: 'Mis cursos', value: '3', detail: 'Este ciclo lectivo', icon: BookOpen, tone: 'blue' },
    { label: 'Alumnos', value: '78', detail: 'En cursos asignados', icon: Users, tone: 'green' },
    { label: 'Presentes hoy', value: '24 / 27', detail: '3.º año · División A', icon: CalendarCheck, tone: 'rose' },
    { label: 'Por corregir', value: '6', detail: 'Trabajos prácticos', icon: ClipboardList, tone: 'amber' },
  ]
  return [
    { label: 'Mis materias', value: '8', detail: 'En 3.º año · División A', icon: BookOpen, tone: 'blue' },
    { label: 'Promedio general', value: '8,6', detail: '¡Seguí así!', icon: TrendingUp, tone: 'green' },
    { label: 'Asistencia', value: '94%', detail: 'Este trimestre', icon: CalendarCheck, tone: 'rose' },
    { label: 'Actividades', value: '2', detail: 'Próximas entregas', icon: ClipboardList, tone: 'amber' },
  ]
})

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

const recentNotices = computed(() => school.notices.slice(0, 3))
const nextActivities = computed(() => school.activities.filter((item) => item.status === 'Pendiente').slice(0, 3))
const today = new Intl.DateTimeFormat('es-AR', { weekday: 'long', day: 'numeric', month: 'long' }).format(new Date(2026, 10, 5))
</script>

<template>
  <div class="page">
    <div class="page-heading page-heading--dashboard">
      <div><div class="breadcrumb">Inicio <span>/</span> <b>{{ title }}</b></div><h1>{{ title }}</h1><p>{{ greeting }}, {{ user?.name }}. Este es el resumen de hoy, {{ today }}.</p></div>
      <RouterLink v-if="role === 'administrador'" to="/app/alumnos/nuevo"><BaseButton><Plus :size="17" /> Nuevo alumno</BaseButton></RouterLink>
    </div>
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
          <article v-for="activity in nextActivities" :key="activity.id" class="activity-preview"><span class="activity-preview__date"><CalendarDays :size="17" /></span><div><strong>{{ activity.title }}</strong><small>{{ activity.subject }} · Entrega {{ activity.dueDate }}</small></div><StatusBadge :status="activity.status" /></article>
          <p v-if="!nextActivities.length" class="muted-empty">No tenés actividades pendientes.</p>
        </div>
        <div v-else class="notice-preview-list">
          <article v-for="notice in recentNotices" :key="notice.id" class="notice-preview"><span class="notice-preview__icon"><Bell :size="17" /></span><div><strong>{{ notice.title }}</strong><small>{{ notice.audience }} · {{ notice.date }}</small></div><ArrowRight :size="16" /></article>
        </div>
      </section>
      <section class="panel today-panel">
        <div class="today-panel__top"><span><CalendarClock :size="17" /></span><span>JUEVES · 5 NOV</span></div>
        <h2>{{ role === 'alumno' ? 'Tu día de clases' : role === 'profesor' ? 'Tu agenda de hoy' : 'La escuela en números' }}</h2>
        <p>{{ role === 'administrador' ? 'La comunidad sigue en movimiento.' : 'Un vistazo a lo que viene.' }}</p>
        <div v-if="role !== 'administrador'" class="agenda-list">
          <div class="agenda-item"><time>08:00</time><i class="agenda-line"></i><div><b>{{ role === 'alumno' ? 'Matemática' : '3.º A · Matemática' }}</b><small>Aula 12 · Primer piso</small></div></div>
          <div class="agenda-item"><time>10:15</time><i class="agenda-line agenda-line--rose"></i><div><b>{{ role === 'alumno' ? 'Lengua y Literatura' : '3.º B · Matemática' }}</b><small>Aula 8 · Segundo piso</small></div></div>
          <div class="agenda-item"><time>12:00</time><i class="agenda-line agenda-line--green"></i><div><b>{{ role === 'alumno' ? 'Ciencias Naturales' : 'Reunión de departamento' }}</b><small>{{ role === 'alumno' ? 'Laboratorio' : 'Sala de profesores' }}</small></div></div>
        </div>
        <div v-else class="school-overview"><div><span class="overview-dot overview-dot--green"></span><strong>{{ school.students.length }} alumnos</strong><small>en la institución</small></div><div><span class="overview-dot overview-dot--blue"></span><strong>{{ school.courses.length }} cursos</strong><small>en dos turnos</small></div></div>
        <RouterLink class="today-panel__link" :to="role === 'alumno' ? '/app/mis-cursos' : role === 'profesor' ? '/app/mis-cursos' : '/app/avisos'">{{ role === 'administrador' ? 'Ir a los avisos' : 'Ver mi agenda' }} <ArrowRight :size="15" /></RouterLink>
      </section>
    </div>
  </div>
</template>
