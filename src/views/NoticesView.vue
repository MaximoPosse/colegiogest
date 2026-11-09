<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { Bell, CalendarDays, Megaphone, Plus, Send, Trash2, X } from '@lucide/vue'
import BaseButton from '../components/BaseButton.vue'
import FormField from '../components/FormField.vue'
import StatusBadge from '../components/StatusBadge.vue'
import { describeError } from '../lib/errors'
import { formatDate } from '../lib/format'
import { createNotice, deleteNotice, fetchCourses, fetchNotices } from '../services/school'
import { session } from '../stores/auth'
import { notify } from '../stores/toast'

const canPublish = computed(() => ['administrador', 'profesor'].includes(session.user?.role))
const showForm = ref(false)
const filter = ref('todos')
const loading = ref(true)
const saving = ref(false)
const error = ref('')
const formError = ref('')
const notices = ref([])
const courses = ref([])
const errors = reactive({})
const form = reactive({ title: '', category: 'institucional', courseId: '', body: '' })
const categories = [
  { value: 'todos', label: 'Todos' },
  { value: 'institucional', label: 'Institucional' },
  { value: 'academico', label: 'Académico' },
  { value: 'evento', label: 'Evento' },
]
const visibleNotices = computed(() => notices.value
  .filter((notice) => filter.value === 'todos' || notice.categoryRaw === filter.value)
  .sort((a, b) => String(b.date).localeCompare(String(a.date))))

async function loadNotices() {
  loading.value = true
  error.value = ''
  try {
    const [noticeRows, courseRows] = await Promise.all([
      fetchNotices(),
      canPublish.value ? fetchCourses() : Promise.resolve([]),
    ])
    notices.value = noticeRows
    courses.value = courseRows
  } catch (caught) {
    error.value = describeError(caught)
    notify(error.value, 'error')
  } finally {
    loading.value = false
  }
}

onMounted(loadNotices)

function openForm() {
  Object.keys(errors).forEach((key) => delete errors[key])
  formError.value = ''
  Object.assign(form, { title: '', category: 'institucional', courseId: '', body: '' })
  showForm.value = true
}

async function publishNotice() {
  if (saving.value) return
  Object.keys(errors).forEach((key) => delete errors[key])
  formError.value = ''
  if (!form.title.trim()) errors.title = 'El título es obligatorio.'
  if (!form.body.trim()) errors.body = 'Escribí el contenido del aviso.'
  if (Object.keys(errors).length) return
  saving.value = true
  try {
    await createNotice({
      titulo: form.title,
      contenido: form.body,
      categoria: form.category,
      autorId: session.user.id,
      cursoId: form.courseId || null,
    })
    notify('El aviso se publicó correctamente.')
    showForm.value = false
    await loadNotices()
  } catch (caught) {
    formError.value = describeError(caught)
    notify(formError.value, 'error')
  } finally {
    saving.value = false
  }
}

async function removeNotice(notice) {
  if (saving.value) return
  if (!window.confirm(`¿Eliminar el aviso «${notice.title}»?`)) return
  saving.value = true
  try {
    await deleteNotice(notice.id)
    notify('El aviso se eliminó.')
    await loadNotices()
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
      <div><div class="breadcrumb">Comunidad <span>/</span> <b>Avisos</b></div><h1>Avisos escolares</h1><p>Novedades y comunicaciones importantes de la comunidad.</p></div>
      <BaseButton v-if="canPublish" @click="showForm ? showForm = false : openForm()"><Plus :size="17" /> Nuevo aviso</BaseButton>
      <span v-else class="read-only-label"><Bell :size="16" /> Solo lectura</span>
    </div>
    <form v-if="showForm && canPublish" class="panel notice-form" novalidate @submit.prevent="publishNotice">
      <div class="panel-heading"><div><h2>Publicar un aviso</h2><p>La comunidad podrá ver esta comunicación.</p></div><button type="button" class="icon-button" aria-label="Cerrar formulario" @click="showForm = false"><X :size="18" /></button></div>
      <div class="form-grid">
        <FormField id="notice-title" label="Título" :error="errors.title" required><template #default="{ id }"><input :id="id" v-model="form.title" placeholder="Ej. Reunión de familias" /></template></FormField>
        <FormField id="notice-category" label="Categoría"><template #default="{ id }"><select :id="id" v-model="form.category"><option value="institucional">Institucional</option><option value="academico">Académico</option><option value="evento">Evento</option></select></template></FormField>
        <FormField id="notice-audience" label="Destinatarios"><template #default="{ id }"><select :id="id" v-model="form.courseId"><option value="">Toda la comunidad</option><option v-for="course in courses" :key="course.id" :value="course.id">{{ course.label }}</option></select></template></FormField>
        <FormField id="notice-body" label="Mensaje" :error="errors.body" required><template #default="{ id }"><textarea :id="id" v-model="form.body" rows="3" placeholder="Escribí el contenido del aviso..."></textarea></template></FormField>
      </div>
      <div v-if="formError" class="form-note form-note--error"><span>!</span><p>{{ formError }}</p></div>
      <div class="form-actions"><BaseButton variant="outline" @click="showForm = false">Cancelar</BaseButton><BaseButton type="submit" :disabled="saving"><Send :size="16" /> {{ saving ? 'Publicando…' : 'Publicar aviso' }}</BaseButton></div>
    </form>
    <section class="panel notices-panel">
      <div class="notices-panel__top"><div><h2>Comunicaciones</h2><p>{{ visibleNotices.length }} {{ visibleNotices.length === 1 ? 'aviso publicado' : 'avisos publicados' }}</p></div><div class="notice-filters" aria-label="Filtrar avisos"><button v-for="item in categories" :key="item.value" type="button" :class="{ 'notice-filter--active': filter === item.value }" @click="filter = item.value">{{ item.label }}</button></div></div>
      <div class="notice-list">
        <article v-for="notice in visibleNotices" :key="notice.id" class="notice-card">
          <span class="notice-card__icon" :class="`notice-card__icon--${notice.category.toLowerCase()}`"><Megaphone :size="19" /></span>
          <div class="notice-card__content"><div class="notice-card__meta"><StatusBadge :status="notice.category === 'Institucional' ? 'Publicado' : notice.category" /><span><CalendarDays :size="14" /> {{ formatDate(notice.date) }}</span></div><h3>{{ notice.title }}</h3><p>{{ notice.body }}</p><div class="notice-card__footer"><span><Bell :size="14" /> {{ notice.audience }}</span><span>Publicado por {{ notice.author }}</span></div></div>
          <button v-if="canPublish" type="button" class="icon-button icon-button--small icon-button--danger notice-delete" :disabled="saving" :aria-label="`Eliminar ${notice.title}`" @click="removeNotice(notice)"><Trash2 :size="16" /></button>
        </article>
        <div v-if="!visibleNotices.length" class="empty-state"><h3>{{ loading ? 'Cargando avisos...' : 'No hay avisos en esta categoría' }}</h3><p>{{ loading ? 'Estamos consultando la base de datos.' : 'Elegí otra categoría o publicá un nuevo aviso.' }}</p></div>
      </div>
    </section>
  </div>
</template>
