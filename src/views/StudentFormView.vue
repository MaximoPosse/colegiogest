<script setup>
import { computed, reactive, watch } from 'vue'
import { ArrowLeft, Save } from '@lucide/vue'
import { useRoute, useRouter } from 'vue-router'
import BaseButton from '../components/BaseButton.vue'
import FormField from '../components/FormField.vue'
import { notify, school } from '../data/demoStore'

const route = useRoute()
const router = useRouter()
const student = computed(() => school.students.find((item) => item.id === route.params.id))
const isEditing = computed(() => Boolean(route.params.id))
const form = reactive({ name: '', surname: '', dni: '', email: '', course: '', status: 'Activo' })
const errors = reactive({})

watch(student, (value) => {
  Object.assign(form, value ?? { name: '', surname: '', dni: '', email: '', course: '', status: 'Activo' })
}, { immediate: true })

function validate() {
  Object.keys(errors).forEach((key) => delete errors[key])
  if (!form.name.trim()) errors.name = 'El nombre es obligatorio.'
  if (!form.surname.trim()) errors.surname = 'El apellido es obligatorio.'
  if (!form.dni.trim()) errors.dni = 'El DNI es obligatorio.'
  else if (!/^[\d.]{7,12}$/.test(form.dni.trim())) errors.dni = 'Ingresá un DNI válido.'
  if (!form.email.trim()) errors.email = 'El correo es obligatorio.'
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email.trim())) errors.email = 'Ingresá un correo válido.'
  if (!form.course) errors.course = 'Seleccioná un curso.'
  const duplicate = school.students.some((item) => item.email.toLowerCase() === form.email.trim().toLowerCase() && item.id !== route.params.id)
  if (duplicate) errors.email = 'Ya existe un alumno con este correo.'
  return Object.keys(errors).length === 0
}

function saveStudent() {
  if (!validate()) return
  const data = { ...form, name: form.name.trim(), surname: form.surname.trim(), dni: form.dni.trim(), email: form.email.trim() }
  if (isEditing.value) {
    const index = school.students.findIndex((item) => item.id === route.params.id)
    if (index >= 0) school.students[index] = { ...school.students[index], ...data }
    notify('Los datos del alumno se actualizaron en esta sesión.')
  } else {
    school.students.unshift({ ...data, id: `a-${Date.now()}` })
    notify('El alumno se agregó correctamente a esta sesión de prueba.')
  }
  router.push('/app/alumnos')
}
</script>

<template>
  <div class="page page--narrow">
    <div class="page-heading">
      <div><div class="breadcrumb"><RouterLink to="/app/alumnos">Alumnos</RouterLink> <span>/</span> <b>{{ isEditing ? 'Editar alumno' : 'Nuevo alumno' }}</b></div><h1>{{ isEditing ? 'Editar alumno' : 'Nuevo alumno' }}</h1><p>Completá la información del estudiante. Los campos con * son obligatorios.</p></div>
    </div>
    <form class="panel student-form" novalidate @submit.prevent="saveStudent">
      <div class="panel-heading panel-heading--form"><div><h2>Datos personales</h2><p>Información de contacto y escolar</p></div><span class="form-step">01 <i>/ 01</i></span></div>
      <div class="form-grid">
        <FormField id="student-name" label="Nombre" :error="errors.name" required><template #default="{ id }"><input :id="id" v-model="form.name" type="text" placeholder="Ej. Lucía" autocomplete="given-name" /></template></FormField>
        <FormField id="student-surname" label="Apellido" :error="errors.surname" required><template #default="{ id }"><input :id="id" v-model="form.surname" type="text" placeholder="Ej. Fernández" autocomplete="family-name" /></template></FormField>
        <FormField id="student-dni" label="DNI" :error="errors.dni" required hint="Ingresá solo números o separalos con puntos."><template #default="{ id }"><input :id="id" v-model="form.dni" type="text" inputmode="numeric" placeholder="Ej. 45.231.890" /></template></FormField>
        <FormField id="student-email" label="Correo electrónico" :error="errors.email" required><template #default="{ id }"><input :id="id" v-model="form.email" type="email" placeholder="nombre@email.com" autocomplete="email" /></template></FormField>
        <FormField id="student-course" label="Curso" :error="errors.course" required><template #default="{ id }"><select :id="id" v-model="form.course"><option disabled value="">Seleccioná un curso</option><option v-for="course in school.courses" :key="course.id" :value="`${course.name.replace(' año', 'º') } ${course.division}`">{{ course.name.replace(' año', 'º') }} {{ course.division }} · Turno {{ course.shift.toLowerCase() }}</option></select></template></FormField>
        <FormField id="student-status" label="Estado" required><template #default="{ id }"><select :id="id" v-model="form.status"><option>Activo</option><option>Inactivo</option></select></template></FormField>
      </div>
      <div class="form-note"><span>i</span><p>Los datos se guardan temporalmente en esta sesión. La integración con Supabase se realizará en una etapa posterior.</p></div>
      <div class="form-actions"><RouterLink to="/app/alumnos"><BaseButton variant="outline"><ArrowLeft :size="16" /> Cancelar</BaseButton></RouterLink><BaseButton type="submit"><Save :size="16" /> {{ isEditing ? 'Guardar cambios' : 'Guardar alumno' }}</BaseButton></div>
    </form>
  </div>
</template>
