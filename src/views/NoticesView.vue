<script setup>
import { computed, reactive, ref } from 'vue'
import { Bell, CalendarDays, Megaphone, Plus, Send, Trash2 } from '@lucide/vue'
import BaseButton from '../components/BaseButton.vue'
import FormField from '../components/FormField.vue'
import StatusBadge from '../components/StatusBadge.vue'
import { notify, school, session } from '../data/demoStore'

const role = computed(() => session.user?.role)
const canPublish = computed(() => ['administrador', 'profesor'].includes(role.value))
const showForm = ref(false)
const filter = ref('Todos')
const errors = reactive({})
const form = reactive({ title: '', category: 'Institucional', audience: 'Toda la comunidad', body: '' })
const categories = ['Todos', 'Institucional', 'Académico', 'Evento']
const notices = computed(() => [...school.notices]
  .filter((notice) => filter.value === 'Todos' || notice.category === filter.value)
  .sort((a, b) => b.date.localeCompare(a.date)))

function publishNotice() {
  Object.keys(errors).forEach((key) => delete errors[key])
  if (!form.title.trim()) errors.title = 'El título es obligatorio.'
  if (!form.body.trim()) errors.body = 'Escribí el contenido del aviso.'
  if (Object.keys(errors).length) return
  school.notices.unshift({
    ...form, id: `av-${Date.now()}`,
    date: new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Argentina/Buenos_Aires' }).format(new Date()),
    author: `${session.user.name} ${session.user.surname}`,
  })
  notify('El aviso se publicó en esta sesión de prueba.')
  Object.assign(form, { title: '', category: 'Institucional', audience: 'Toda la comunidad', body: '' })
  showForm.value = false
}

function deleteNotice(notice) {
  if (!window.confirm(`¿Eliminar el aviso «${notice.title}»? Esta acción solo afecta la sesión actual.`)) return
  school.notices = school.notices.filter((item) => item.id !== notice.id)
  notify('El aviso se eliminó de esta sesión.')
}
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <div><div class="breadcrumb">Comunidad <span>/</span> <b>Avisos</b></div><h1>Avisos escolares</h1><p>Novedades y comunicaciones importantes de la comunidad.</p></div>
      <BaseButton v-if="canPublish" @click="showForm = !showForm"><Plus :size="17" /> Nuevo aviso</BaseButton>
      <span v-else class="read-only-label"><Bell :size="16" /> Solo lectura</span>
    </div>
    <form v-if="showForm && canPublish" class="panel notice-form" novalidate @submit.prevent="publishNotice">
      <div class="panel-heading"><div><h2>Publicar un aviso</h2><p>La comunidad podrá ver esta comunicación.</p></div></div>
      <div class="form-grid">
        <FormField id="notice-title" label="Título" :error="errors.title" required><template #default="{ id }"><input :id="id" v-model="form.title" placeholder="Ej. Reunión de familias" /></template></FormField>
        <FormField id="notice-category" label="Categoría"><template #default="{ id }"><select :id="id" v-model="form.category"><option>Institucional</option><option>Académico</option><option>Evento</option></select></template></FormField>
        <FormField id="notice-audience" label="Destinatarios"><template #default="{ id }"><select :id="id" v-model="form.audience"><option>Toda la comunidad</option><option>3.º A</option><option>3.º B</option><option>Docentes</option><option>Familias</option></select></template></FormField>
        <FormField id="notice-body" label="Mensaje" :error="errors.body" required><template #default="{ id }"><textarea :id="id" v-model="form.body" rows="3" placeholder="Escribí el contenido del aviso..."></textarea></template></FormField>
      </div>
      <div class="form-actions"><BaseButton variant="outline" @click="showForm = false">Cancelar</BaseButton><BaseButton type="submit"><Send :size="16" /> Publicar aviso</BaseButton></div>
    </form>
    <section class="panel notices-panel">
      <div class="notices-panel__top"><div><h2>Comunicaciones</h2><p>{{ notices.length }} {{ notices.length === 1 ? 'aviso publicado' : 'avisos publicados' }}</p></div><div class="notice-filters" aria-label="Filtrar avisos"><button v-for="item in categories" :key="item" type="button" :class="{ 'notice-filter--active': filter === item }" @click="filter = item">{{ item }}</button></div></div>
      <div class="notice-list">
        <article v-for="notice in notices" :key="notice.id" class="notice-card">
          <span class="notice-card__icon" :class="`notice-card__icon--${notice.category.toLowerCase()}`"><Megaphone :size="19" /></span>
          <div class="notice-card__content"><div class="notice-card__meta"><StatusBadge :status="notice.category === 'Institucional' ? 'Publicado' : notice.category" /><span><CalendarDays :size="14" /> {{ new Date(`${notice.date}T12:00:00`).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' }) }}</span></div><h3>{{ notice.title }}</h3><p>{{ notice.body }}</p><div class="notice-card__footer"><span><Bell :size="14" /> {{ notice.audience }}</span><span>Publicado por {{ notice.author }}</span></div></div>
          <button v-if="canPublish" type="button" class="icon-button icon-button--small icon-button--danger notice-delete" :aria-label="`Eliminar ${notice.title}`" @click="deleteNotice(notice)"><Trash2 :size="16" /></button>
        </article>
        <div v-if="!notices.length" class="empty-state"><h3>No hay avisos en esta categoría</h3><p>Elegí otra categoría o publicá un nuevo aviso.</p></div>
      </div>
    </section>
  </div>
</template>
