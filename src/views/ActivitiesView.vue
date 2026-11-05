<script setup>
import { computed, reactive, ref } from 'vue'
import { CalendarDays, ClipboardCheck, Plus, Send, Trash2 } from '@lucide/vue'
import BaseButton from '../components/BaseButton.vue'
import FormField from '../components/FormField.vue'
import StatusBadge from '../components/StatusBadge.vue'
import { notify, school, session } from '../data/demoStore'

const isStudent = computed(() => session.user?.role === 'alumno')
const isTeacher = computed(() => session.user?.role === 'profesor')
const showForm = ref(false)
const errors = reactive({})
const form = reactive({ title: '', subject: '', course: '3.º A', dueDate: '', description: '' })
const activities = computed(() => [...school.activities].sort((a, b) => a.dueDate.localeCompare(b.dueDate)))

function publishActivity() {
  Object.keys(errors).forEach((key) => delete errors[key])
  if (!form.title.trim()) errors.title = 'El título es obligatorio.'
  if (!form.subject) errors.subject = 'Seleccioná una materia.'
  if (!form.dueDate) errors.dueDate = 'Elegí una fecha de entrega.'
  if (!form.description.trim()) errors.description = 'Agregá una descripción para la actividad.'
  if (Object.keys(errors).length) return
  school.activities.unshift({ ...form, id: `act-${Date.now()}`, status: 'Pendiente' })
  notify('La actividad se publicó en esta sesión de prueba.')
  Object.assign(form, { title: '', subject: '', course: '3.º A', dueDate: '', description: '' })
  showForm.value = false
}

function removeActivity(activity) {
  if (!window.confirm(`¿Eliminar la actividad «${activity.title}»? Esta acción solo afecta la sesión actual.`)) return
  school.activities = school.activities.filter((item) => item.id !== activity.id)
  notify('La actividad se eliminó de esta sesión.')
}

function markDelivered(activity) {
  activity.status = 'Entregada'
  notify('La actividad quedó marcada como entregada.')
}
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <div><div class="breadcrumb">{{ isStudent ? 'Mi espacio escolar' : 'Mi espacio docente' }} <span>/</span> <b>Actividades</b></div><h1>{{ isStudent ? 'Mis actividades' : 'Actividades' }}</h1><p>{{ isStudent ? 'Organizá tus próximas entregas y revisá lo que ya completaste.' : 'Compartí actividades y acompañá el trabajo de tus cursos.' }}</p></div>
      <BaseButton v-if="isTeacher" @click="showForm = !showForm"><Plus :size="17" /> Nueva actividad</BaseButton>
      <span v-else class="read-only-label"><ClipboardCheck :size="16" /> {{ isStudent ? 'Mi curso · 3.º A' : 'Solo consulta' }}</span>
    </div>
    <form v-if="showForm && isTeacher" class="panel activity-form" novalidate @submit.prevent="publishActivity">
      <div class="panel-heading"><div><h2>Nueva actividad</h2><p>El curso va a poder consultar la actividad publicada.</p></div></div>
      <div class="form-grid">
        <FormField id="activity-title" label="Título" :error="errors.title" required><template #default="{ id }"><input :id="id" v-model="form.title" placeholder="Ej. Trabajo práctico integrador" /></template></FormField>
        <FormField id="activity-subject" label="Materia" :error="errors.subject" required><template #default="{ id }"><select :id="id" v-model="form.subject"><option disabled value="">Seleccioná una materia</option><option>Matemática</option><option>Lengua y Literatura</option><option>Ciencias Naturales</option><option>Historia</option></select></template></FormField>
        <FormField id="activity-course" label="Curso"><template #default="{ id }"><select :id="id" v-model="form.course"><option>3.º A</option><option>3.º B</option><option>2.º A</option><option>2.º B</option></select></template></FormField>
        <FormField id="activity-due" label="Fecha de entrega" :error="errors.dueDate" required><template #default="{ id }"><input :id="id" v-model="form.dueDate" type="date" /></template></FormField>
        <FormField id="activity-description" label="Consigna" :error="errors.description" required><template #default="{ id }"><textarea :id="id" v-model="form.description" rows="3" placeholder="Indicaciones para el curso..."></textarea></template></FormField>
      </div>
      <div class="form-actions"><BaseButton variant="outline" @click="showForm = false">Cancelar</BaseButton><BaseButton type="submit"><Send :size="16" /> Publicar actividad</BaseButton></div>
    </form>
    <div class="activity-card-grid">
      <article v-for="activity in activities" :key="activity.id" class="panel activity-card">
        <div class="activity-card__top"><span class="activity-card__icon"><CalendarDays :size="18" /></span><StatusBadge :status="activity.status" /><button v-if="isTeacher" type="button" class="icon-button icon-button--small icon-button--danger" :aria-label="`Eliminar ${activity.title}`" @click="removeActivity(activity)"><Trash2 :size="16" /></button></div>
        <span class="activity-card__subject">{{ activity.subject }} · {{ activity.course }}</span><h2>{{ activity.title }}</h2><p>{{ activity.description }}</p>
        <div class="activity-card__footer"><span><CalendarDays :size="15" /> Entrega {{ new Date(`${activity.dueDate}T12:00:00`).toLocaleDateString('es-AR', { day: 'numeric', month: 'long' }) }}</span><button v-if="isStudent && activity.status === 'Pendiente'" type="button" class="text-link" @click="markDelivered(activity)">Marcar entregada</button></div>
      </article>
      <div v-if="!activities.length" class="panel empty-state"><h3>No hay actividades</h3><p>Cuando se publiquen actividades, van a aparecer acá.</p></div>
    </div>
  </div>
</template>
