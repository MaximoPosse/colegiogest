<script setup>
import { computed } from 'vue'
import { BookOpen, Clock3, GraduationCap, MapPin, UserRound } from '@lucide/vue'
import { school, session } from '../data/demoStore'

const isStudent = computed(() => session.user?.role === 'alumno')
const subjects = computed(() => isStudent.value
  ? school.subjects.filter((subject) => subject.course === '3.º A')
  : school.subjects.filter((subject) => subject.teacher === `${session.user?.name} ${session.user?.surname}`))
</script>

<template>
  <div class="page">
    <div class="page-heading"><div><div class="breadcrumb">Mi espacio <span>/</span> <b>Mis cursos</b></div><h1>{{ isStudent ? 'Mis materias' : 'Mis cursos y alumnos' }}</h1><p>{{ isStudent ? 'Consultá las materias y los horarios de tu curso.' : 'Una vista rápida de las materias que tenés asignadas.' }}</p></div><span class="read-only-label"><BookOpen :size="16" /> {{ isStudent ? '3.º año · División A' : 'Ciclo lectivo 2026' }}</span></div>
    <div class="course-card-grid">
      <article v-for="(subject, index) in subjects" :key="subject.id" class="panel course-card">
        <div class="course-card__cover" :class="`course-card__cover--${index % 4}`"><span>{{ subject.name.slice(0, 1) }}</span><div class="course-card__cover-icon"><BookOpen :size="20" /></div></div>
        <div class="course-card__body"><span class="course-card__eyebrow">{{ subject.course }} · Ciclo 2026</span><h2>{{ subject.name }}</h2><div class="course-card__details"><span><UserRound :size="15" /> {{ subject.teacher }}</span><span><Clock3 :size="15" /> {{ subject.schedule }}</span><span><MapPin :size="15" /> Aula {{ 8 + index }}</span></div><div v-if="!isStudent" class="course-card__footer"><span><GraduationCap :size="15" /> {{ 24 + index }} alumnos</span><RouterLink to="/app/asistencia">Ir a asistencia <span>→</span></RouterLink></div></div>
      </article>
      <div v-if="!subjects.length" class="panel empty-state"><h3>No hay materias asignadas</h3><p>Cuando se registren asignaciones para tu perfil, las vas a encontrar acá.</p></div>
    </div>
  </div>
</template>
