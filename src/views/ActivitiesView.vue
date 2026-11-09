<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { CalendarDays, ClipboardCheck, Plus, Send, Trash2, X } from '@lucide/vue'
import BaseButton from '../components/BaseButton.vue'
import FormField from '../components/FormField.vue'
import StatusBadge from '../components/StatusBadge.vue'
import { describeError } from '../lib/errors'
import { formatDate, todayIso } from '../lib/format'
import {
  createActivity,
  deleteActivity,
  fetchActivities,
  fetchAssignments,
  fetchDeliveries,
  markActivityDelivered,
} from '../services/school'
import { session } from '../stores/auth'
import { notify } from '../stores/toast'

const isStudent = computed(() => session.user?.role === 'alumno')
const isTeacher = computed(() => session.user?.role === 'profesor')
const showForm = ref(false)
const loading = ref(true)
const saving = ref(false)
const error = ref('')
const formError = ref('')
const errors = reactive({})
const activities = ref([])
const deliveries = ref([])
const assignments = ref([])
const form = reactive({ assignmentId: '', title: '', dueDate: '', description: '' })
const myCourse = computed(() => session.user?.curso ? `${session.user.curso.anio}.º ${session.user.curso.division}` : 'Sin curso')
const deliveredIds = computed(() => new Set(deliveries.value.filter((item) => item.status === 'Entregada').map((item) => item.activityId)))
const decoratedActivities = computed(() => [...activities.value]
  .map((activity) => ({
    ...activity,
    status: isStudent.value ? (deliveredIds.value.has(activity.id) ? 'Entregada' : 'Pendiente') : 'Pendiente',
  }))
  .sort((a, b) => String(a.dueDate).localeCompare(String(b.dueDate))))
const selectedAssignment = computed(() => assignments.value.find((item) => item.id === form.assignmentId) ?? null)

function deliveryCount(activityId) {
  return deliveries.value.filter((item) => item.activityId === activityId && item.status === 'Entregada').length
}

async function loadAll() {
  loading.value = true
  error.value = ''
  try {
    const [activityRows, deliveryRows, assignmentRows] = await Promise.all([
      fetchActivities(),
      fetchDeliveries(),
      isTeacher.value ? fetchAssignments({ teacherId: session.user?.profesorId }) : Promise.resolve([]),
    ])
    activities.value = activityRows
    deliveries.value = deliveryRows
    assignments.value = assignmentRows
  } catch (caught) {
    error.value = describeError(caught)
    notify(error.value, 'error')
  } finally {
    loading.value = false
  }
}

onMounted(loadAll)

function openForm() {
  Object.keys(errors).forEach((key) => delete errors[key])
  formError.value = ''
  Object.assign(form, {
    assignmentId: assignments.value[0]?.id ?? '',
    title: '',
    dueDate: todayIso(),
    description: '',
  })
  showForm.value = true
}

async function publishActivity() {
  if (saving.value) return
  Object.keys(errors).forEach((key) => delete errors[key])
  formError.value = ''
  if (!form.title.trim()) errors.title = 'El título es obligatorio.'
  if (!form.assignmentId) errors.assignmentId = 'Seleccioná una materia y curso.'
  if (!form.dueDate) errors.dueDate = 'Elegí una fecha de entrega.'
  if (!form.description.trim()) errors.description = 'Agregá una descripción para la actividad.'
  if (Object.keys(errors).length) return
  const assignment = selectedAssignment.value
  saving.value = true
  try {
    await createActivity({
      titulo: form.title,
      descripcion: form.description,
      fechaEntrega: form.dueDate,
      materiaId: assignment.subjectId,
      cursoId: assignment.courseId,
      profesorId: assignment.teacherId,
    })
    notify('La actividad se publicó correctamente.')
    showForm.value = false
    await loadAll()
  } catch (caught) {
    formError.value = describeError(caught)
    notify(formError.value, 'error')
  } finally {
    saving.value = false
  }
}

async function removeActivity(activity) {
  if (saving.value) return
  if (!window.confirm(`¿Eliminar la actividad «${activity.title}»? También se eliminarán sus entregas.`)) return
  saving.value = true
  try {
    await deleteActivity(activity.id)
    notify('La actividad se eliminó.')
    await loadAll()
  } catch (caught) {
    notify(describeError(caught), 'error')
  } finally {
    saving.value = false
  }
}

async function markDelivered(activity) {
  if (saving.value) return
  if (!session.user?.alumnoId) {
    notify('No encontramos tu perfil de alumno.', 'error')
    return
  }
  saving.value = true
  try {
    await markActivityDelivered(activity.id, session.user.alumnoId)
    notify('La actividad quedó marcada como entregada.')
    deliveries.value = await fetchDeliveries()
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
      <div><div class="breadcrumb">{{ isStudent ? 'Mi espacio escolar' : 'Mi espacio docente' }} <span>/</span> <b>Actividades</b></div><h1>{{ isStudent ? 'Mis actividades' : 'Actividades' }}</h1><p>{{ isStudent ? 'Organizá tus próximas entregas y revisá lo que ya completaste.' : 'Compartí actividades y acompañá el trabajo de tus cursos.' }}</p></div>
      <BaseButton v-if="isTeacher" @click="showForm = !showForm"><Plus :size="17" /> Nueva actividad</BaseButton>
      <span v-else class="read-only-label"><ClipboardCheck :size="16" /> {{ isStudent ? `Mi curso · ${myCourse}` : 'Solo consulta' }}</span>
    </div>
    <form v-if="showForm && isTeacher" class="panel activity-form" novalidate @submit.prevent="publishActivity">
      <div class="panel-heading"><div><h2>Nueva actividad</h2><p>El curso va a poder consultar la actividad publicada.</p></div><button type="button" class="icon-button" aria-label="Cerrar formulario" @click="showForm = false"><X :size="18" /></button></div>
      <div class="form-grid">
        <FormField id="activity-title" label="Título" :error="errors.title" required><template #default="{ id }"><input :id="id" v-model="form.title" placeholder="Ej. Trabajo práctico integrador" /></template></FormField>
        <FormField id="activity-assignment" label="Materia y curso" :error="errors.assignmentId" required><template #default="{ id }"><select :id="id" v-model="form.assignmentId"><option disabled value="">Seleccioná una asignación</option><option v-for="item in assignments" :key="item.id" :value="item.id">{{ item.subject }} · {{ item.course }}</option></select></template></FormField>
        <FormField id="activity-due" label="Fecha de entrega" :error="errors.dueDate" required><template #default="{ id }"><input :id="id" v-model="form.dueDate" type="date" /></template></FormField>
        <FormField id="activity-description" label="Consigna" :error="errors.description" required><template #default="{ id }"><textarea :id="id" v-model="form.description" rows="3" placeholder="Indicaciones para el curso..."></textarea></template></FormField>
      </div>
      <div v-if="formError" class="form-note form-note--error"><span>!</span><p>{{ formError }}</p></div>
      <div v-if="!assignments.length" class="form-note"><span>i</span><p>No tenés materias asignadas. Contactá a la administración para poder publicar actividades.</p></div>
      <div class="form-actions"><BaseButton variant="outline" @click="showForm = false">Cancelar</BaseButton><BaseButton type="submit" :disabled="saving"><Send :size="16" /> {{ saving ? 'Publicando…' : 'Publicar actividad' }}</BaseButton></div>
    </form>
    <div class="activity-card-grid">
      <article v-for="activity in decoratedActivities" :key="activity.id" class="panel activity-card">
        <div class="activity-card__top"><span class="activity-card__icon"><CalendarDays :size="18" /></span><StatusBadge :status="activity.status" /><button v-if="isTeacher" type="button" class="icon-button icon-button--small icon-button--danger" :disabled="saving" :aria-label="`Eliminar ${activity.title}`" @click="removeActivity(activity)"><Trash2 :size="16" /></button></div>
        <span class="activity-card__subject">{{ activity.subject }} · {{ activity.course }}</span><h2>{{ activity.title }}</h2><p>{{ activity.description }}</p>
        <div class="activity-card__footer"><span><CalendarDays :size="15" /> Entrega {{ formatDate(activity.dueDate) }}</span><button v-if="isStudent && activity.status === 'Pendiente'" type="button" class="text-link" :disabled="saving" @click="markDelivered(activity)">Marcar entregada</button></div>
        <div v-if="!isStudent" class="activity-card__footer"><span>{{ activity.teacher }}</span><span>{{ deliveryCount(activity.id) }} {{ deliveryCount(activity.id) === 1 ? 'entrega' : 'entregas' }}</span></div>
      </article>
      <div v-if="!decoratedActivities.length" class="panel empty-state"><h3>{{ loading ? 'Cargando actividades...' : 'No hay actividades' }}</h3><p>{{ loading ? 'Estamos consultando la base de datos.' : 'Cuando se publiquen actividades, van a aparecer acá.' }}</p></div>
    </div>
  </div>
</template>
