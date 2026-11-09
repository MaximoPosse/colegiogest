<script setup>
import { computed, onMounted, ref } from 'vue'
import { ArrowRight, BookOpen, CalendarCheck, Mail, ShieldCheck, UserRound } from '@lucide/vue'
import StatusBadge from '../components/StatusBadge.vue'
import { describeError } from '../lib/errors'
import { fetchStudentOverview } from '../services/dashboard'
import { fetchAssignments } from '../services/school'
import { session } from '../stores/auth'

const user = computed(() => session.user)
const loading = ref(true)
const error = ref('')
const overview = ref(null)
const assignments = ref([])
const statusLabel = computed(() => user.value?.estado === 'activo' ? 'Activo' : 'Inactivo')
const subjectCount = computed(() => user.value?.role === 'alumno'
  ? overview.value?.subjects?.length ?? 0
  : user.value?.role === 'profesor' ? assignments.value.length : 0)
const courseCount = computed(() => new Set(assignments.value.map((item) => item.courseId)).size)
const averageLabel = computed(() => {
  const value = overview.value?.average
  return value == null ? '—' : Number(value).toLocaleString('es-AR', { minimumFractionDigits: 1, maximumFractionDigits: 1 })
})
const attendanceLabel = computed(() => {
  const value = overview.value?.attendanceRate
  return value == null ? '—' : `${Math.round(value)}%`
})
const courseLabel = computed(() => user.value?.curso
  ? `${user.value.curso.anio}.º año · División ${user.value.curso.division}${user.value.curso.turno ? ` · Turno ${user.value.curso.turno}` : ''}`
  : 'Sin curso activo')

onMounted(async () => {
  loading.value = true
  try {
    if (user.value?.role === 'alumno') overview.value = await fetchStudentOverview(user.value)
    else if (user.value?.role === 'profesor') assignments.value = await fetchAssignments({ teacherId: user.value.profesorId })
  } catch (caught) {
    error.value = describeError(caught)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="page page--narrow">
    <div class="page-heading"><div><div class="breadcrumb">Mi espacio <span>/</span> <b>Perfil</b></div><h1>Mi perfil</h1><p>Consultá tus datos personales y la información de tu cuenta.</p></div></div>
    <section class="panel profile-card">
      <div class="profile-card__cover"></div>
      <div class="profile-card__identity"><span class="avatar avatar--profile">{{ user?.initials }}</span><div><h2>{{ user?.name }} {{ user?.surname }}</h2><p>{{ user?.title }}</p></div><StatusBadge :status="statusLabel" /></div>
      <div class="profile-details">
        <div><span class="profile-detail-icon"><Mail :size="17" /></span><span><small>Correo electrónico</small><strong>{{ user?.email }}</strong></span></div>
        <div><span class="profile-detail-icon"><UserRound :size="17" /></span><span><small>Rol en ColegioGest</small><strong class="capitalize">{{ user?.roleLabel }}</strong></span></div>
        <div v-if="user?.role === 'alumno'"><span class="profile-detail-icon"><BookOpen :size="17" /></span><span><small>Curso actual</small><strong>{{ courseLabel }}</strong></span></div>
        <div v-else-if="user?.role === 'profesor'"><span class="profile-detail-icon"><BookOpen :size="17" /></span><span><small>Materias asignadas</small><strong>{{ subjectCount }}</strong></span></div>
        <div v-else><span class="profile-detail-icon"><ShieldCheck :size="17" /></span><span><small>Permisos</small><strong>Administración general</strong></span></div>
      </div>
      <div v-if="user?.role === 'alumno' && !loading" class="profile-extra"><h3>Mi información escolar</h3><div class="profile-extra__stats"><span><BookOpen :size="17" /><b>{{ subjectCount }}</b><small>Materias</small></span><span><CalendarCheck :size="17" /><b>{{ attendanceLabel }}</b><small>Asistencia</small></span><span><span class="profile-extra__grade">{{ averageLabel }}</span><b>{{ averageLabel }}</b><small>Promedio</small></span></div><p>{{ user?.name }} participa actualmente en {{ courseLabel }}.</p></div>
      <div v-else-if="user?.role === 'profesor' && !loading" class="profile-extra"><h3>Mi carga docente</h3><div class="profile-extra__stats"><span><BookOpen :size="17" /><b>{{ subjectCount }}</b><small>Asignaciones</small></span><span><CalendarCheck :size="17" /><b>{{ courseCount }}</b><small>Cursos</small></span></div><p>Las materias y cursos se obtienen de tus asignaciones vigentes en Supabase.</p></div>
      <div v-if="loading" class="form-note"><span>i</span><p>Cargando tu información escolar...</p></div>
      <div v-if="error" class="form-note form-note--error"><span>!</span><p>{{ error }}</p></div>
      <div class="form-note"><span>i</span><p>Para modificar tus datos personales contactá a la administración del colegio. Podés restablecer tu contraseña desde la pantalla de inicio de sesión.</p></div>
    </section>
    <RouterLink class="profile-link-card" to="/app/avisos"><span><span class="profile-link-card__icon"><BookOpen :size="18" /></span><span><strong>Volver a mi espacio</strong><small>Consultá el panel y las novedades del colegio</small></span></span><ArrowRight :size="17" /></RouterLink>
  </div>
</template>
