<script setup>
import { computed } from 'vue'
import { ArrowRight, BookOpen, CalendarCheck, Mail, ShieldCheck, UserRound } from '@lucide/vue'
import StatusBadge from '../components/StatusBadge.vue'
import { school, session } from '../data/demoStore'

const user = computed(() => session.user)
const student = computed(() => school.students.find((item) => item.id === 'a-01'))
const subjects = computed(() => school.subjects.filter((item) => item.course === '3.º A'))
const attendanceCount = computed(() => school.attendance.filter((item) => item.studentId === 'a-01' && item.status === 'Presente').length)
</script>

<template>
  <div class="page page--narrow">
    <div class="page-heading"><div><div class="breadcrumb">Mi espacio <span>/</span> <b>Perfil</b></div><h1>Mi perfil</h1><p>Consultá tus datos personales y la información de tu cuenta.</p></div></div>
    <section class="panel profile-card">
      <div class="profile-card__cover"></div>
      <div class="profile-card__identity"><span class="avatar avatar--profile">{{ user?.initials }}</span><div><h2>{{ user?.name }} {{ user?.surname }}</h2><p>{{ user?.title }}</p></div><StatusBadge status="Activo" /></div>
      <div class="profile-details">
        <div><span class="profile-detail-icon"><Mail :size="17" /></span><span><small>Correo electrónico</small><strong>{{ user?.email }}</strong></span></div>
        <div><span class="profile-detail-icon"><UserRound :size="17" /></span><span><small>Rol en ColegioGest</small><strong class="capitalize">{{ user?.role }}</strong></span></div>
        <div v-if="user?.role === 'alumno'"><span class="profile-detail-icon"><BookOpen :size="17" /></span><span><small>Curso actual</small><strong>3.º año · División A</strong></span></div>
        <div v-else-if="user?.role === 'profesor'"><span class="profile-detail-icon"><BookOpen :size="17" /></span><span><small>Materia asignada</small><strong>Matemática</strong></span></div>
        <div v-else><span class="profile-detail-icon"><ShieldCheck :size="17" /></span><span><small>Permisos</small><strong>Administración general</strong></span></div>
      </div>
      <div v-if="user?.role === 'alumno'" class="profile-extra"><h3>Mi información escolar</h3><div class="profile-extra__stats"><span><BookOpen :size="17" /><b>{{ subjects.length }}</b><small>Materias</small></span><span><CalendarCheck :size="17" /><b>94%</b><small>Asistencia</small></span><span><span class="profile-extra__grade">8.6</span><b>8,6</b><small>Promedio</small></span></div><p>{{ student?.name }} participa actualmente en el ciclo lectivo 2026.</p></div>
      <div class="form-note"><span>i</span><p>La edición de datos personales se habilitará cuando se integre el sistema con Supabase.</p></div>
    </section>
    <RouterLink class="profile-link-card" to="/app/avisos"><span><span class="profile-link-card__icon"><BookOpen :size="18" /></span><span><strong>Volver a mi espacio</strong><small>Consultá el panel y las novedades del colegio</small></span></span><ArrowRight :size="17" /></RouterLink>
  </div>
</template>
