<script setup>
import { computed, reactive, ref, watch } from 'vue'
import { ArrowLeft, Save } from '@lucide/vue'
import { useRoute, useRouter } from 'vue-router'
import BaseButton from '../components/BaseButton.vue'
import FormField from '../components/FormField.vue'
import { describeError, isDuplicateError } from '../lib/errors'
import { normalizeDni } from '../lib/format'
import { createStudent, fetchCourses, fetchStudent, updateStudent } from '../services/school'
import { notify } from '../stores/toast'

const route = useRoute()
const router = useRouter()
const isEditing = computed(() => Boolean(route.params.id))
const courses = ref([])
const loading = ref(true)
const saving = ref(false)
const loadError = ref('')
const formError = ref('')
const form = reactive({
  name: '',
  surname: '',
  dni: '',
  email: '',
  courseId: '',
  status: 'activo',
  fechaNacimiento: '',
  telefono: '',
  password: '',
})
const errors = reactive({})

function resetForm() {
  Object.assign(form, {
    name: '',
    surname: '',
    dni: '',
    email: '',
    courseId: '',
    status: 'activo',
    fechaNacimiento: '',
    telefono: '',
    password: '',
  })
}

async function load() {
  loading.value = true
  loadError.value = ''
  Object.keys(errors).forEach((key) => delete errors[key])
  try {
    courses.value = await fetchCourses()
    if (isEditing.value) {
      const student = await fetchStudent(route.params.id)
      if (!student) {
        loadError.value = 'No encontramos el alumno solicitado.'
        return
      }
      Object.assign(form, {
        name: student.name,
        surname: student.surname,
        dni: student.dni,
        email: student.email,
        courseId: student.courseId ?? '',
        status: student.estado ?? 'activo',
        fechaNacimiento: student.fechaNacimiento ?? '',
        telefono: student.telefono ?? '',
        password: '',
      })
    } else {
      resetForm()
    }
  } catch (caught) {
    loadError.value = describeError(caught)
  } finally {
    loading.value = false
  }
}

watch(() => route.params.id, load, { immediate: true })

function validate() {
  Object.keys(errors).forEach((key) => delete errors[key])
  formError.value = ''
  if (!form.name.trim()) errors.name = 'El nombre es obligatorio.'
  if (!form.surname.trim()) errors.surname = 'El apellido es obligatorio.'
  const dni = normalizeDni(form.dni)
  if (!dni) errors.dni = 'El DNI es obligatorio.'
  else if (dni.length < 7 || dni.length > 9) errors.dni = 'Ingresá un DNI de 7 a 9 dígitos.'
  if (!form.email.trim()) errors.email = 'El correo es obligatorio.'
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email.trim())) errors.email = 'Ingresá un correo válido.'
  if (!isEditing.value && !form.courseId) errors.courseId = 'Seleccioná un curso.'
  if (!isEditing.value && form.password.length < 6) errors.password = 'La contraseña inicial debe tener al menos 6 caracteres.'
  if (form.telefono && (form.telefono.trim().length < 6 || form.telefono.trim().length > 30)) {
    errors.telefono = 'Ingresá un teléfono válido.'
  }
  return Object.keys(errors).length === 0
}

async function saveStudent() {
  if (saving.value || !validate()) return
  saving.value = true
  const payload = {
    nombre: form.name.trim(),
    apellido: form.surname.trim(),
    dni: normalizeDni(form.dni),
    correo: form.email.trim().toLowerCase(),
    idCurso: form.courseId || null,
    estado: form.status,
    fechaNacimiento: form.fechaNacimiento || null,
    telefono: form.telefono.trim() || null,
    password: form.password,
  }
  try {
    if (isEditing.value) {
      await updateStudent(route.params.id, payload)
      notify('Los datos del alumno se actualizaron correctamente.')
    } else {
      await createStudent(payload)
      notify('El alumno se creó correctamente y ya puede iniciar sesión.')
    }
    router.push('/app/alumnos')
  } catch (caught) {
    if (isDuplicateError(caught, 'email')) errors.email = 'Ya existe un usuario con este correo.'
    else if (isDuplicateError(caught, 'dni')) errors.dni = 'Ya existe un usuario con este DNI.'
    else formError.value = describeError(caught)
    notify(formError.value || 'Revisá los datos marcados.', 'error')
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="page page--narrow">
    <div class="page-heading">
      <div><div class="breadcrumb"><RouterLink to="/app/alumnos">Alumnos</RouterLink> <span>/</span> <b>{{ isEditing ? 'Editar alumno' : 'Nuevo alumno' }}</b></div><h1>{{ isEditing ? 'Editar alumno' : 'Nuevo alumno' }}</h1><p>Completá la información del estudiante. Los campos con * son obligatorios.</p></div>
    </div>
    <div v-if="loading" class="panel empty-state"><h3>Cargando datos...</h3><p>Estamos consultando la información del alumno.</p></div>
    <div v-else-if="loadError" class="panel empty-state"><h3>No pudimos cargar el formulario</h3><p>{{ loadError }}</p><BaseButton variant="outline" @click="router.push('/app/alumnos')"><ArrowLeft :size="16" /> Volver al listado</BaseButton></div>
    <form v-else class="panel student-form" novalidate @submit.prevent="saveStudent">
      <div class="panel-heading panel-heading--form"><div><h2>Datos personales</h2><p>Información de contacto y escolar</p></div><span class="form-step">01 <i>/ 01</i></span></div>
      <div class="form-grid">
        <FormField id="student-name" label="Nombre" :error="errors.name" required><template #default="{ id }"><input :id="id" v-model="form.name" type="text" placeholder="Ej. Lucía" autocomplete="given-name" /></template></FormField>
        <FormField id="student-surname" label="Apellido" :error="errors.surname" required><template #default="{ id }"><input :id="id" v-model="form.surname" type="text" placeholder="Ej. Fernández" autocomplete="family-name" /></template></FormField>
        <FormField id="student-dni" label="DNI" :error="errors.dni" required hint="Ingresá solo números o separalos con puntos."><template #default="{ id }"><input :id="id" v-model="form.dni" type="text" inputmode="numeric" placeholder="Ej. 45.231.890" autocomplete="off" /></template></FormField>
        <FormField id="student-email" label="Correo electrónico" :error="errors.email" required><template #default="{ id }"><input :id="id" v-model="form.email" type="email" placeholder="nombre@email.com" autocomplete="email" /></template></FormField>
        <FormField id="student-course" label="Curso" :error="errors.courseId" :required="!isEditing"><template #default="{ id }"><select :id="id" v-model="form.courseId"><option value="">{{ isEditing ? 'Sin curso asignado' : 'Seleccioná un curso' }}</option><option v-for="course in courses" :key="course.id" :value="course.id">{{ course.label }} · Turno {{ course.turno.toLowerCase() }}</option></select></template></FormField>
        <FormField id="student-status" label="Estado" required><template #default="{ id }"><select :id="id" v-model="form.status"><option value="activo">Activo</option><option value="inactivo">Inactivo</option></select></template></FormField>
        <FormField id="student-birthdate" label="Fecha de nacimiento"><template #default="{ id }"><input :id="id" v-model="form.fechaNacimiento" type="date" /></template></FormField>
        <FormField id="student-phone" label="Teléfono" :error="errors.telefono" hint="Opcional. Mínimo 6 caracteres."><template #default="{ id }"><input :id="id" v-model="form.telefono" type="tel" placeholder="Ej. 11 5555 1234" autocomplete="tel" /></template></FormField>
        <FormField v-if="!isEditing" id="student-password" label="Contraseña inicial" :error="errors.password" required hint="Mínimo 6 caracteres. El alumno podrá cambiarla desde el inicio de sesión."><template #default="{ id }"><input :id="id" v-model="form.password" type="password" placeholder="••••••" autocomplete="new-password" /></template></FormField>
      </div>
      <div v-if="formError" class="form-note form-note--error"><span>!</span><p>{{ formError }}</p></div>
      <div class="form-note"><span>i</span><p>{{ isEditing ? 'Los cambios se guardan en Supabase. Si cambiás el curso, se finaliza la inscripción anterior y se crea una nueva.' : 'Se creará la cuenta de acceso y el perfil del alumno en Supabase con la contraseña indicada.' }}</p></div>
      <div class="form-actions"><RouterLink to="/app/alumnos"><BaseButton variant="outline"><ArrowLeft :size="16" /> Cancelar</BaseButton></RouterLink><BaseButton type="submit" :disabled="saving"><Save :size="16" /> {{ saving ? 'Guardando…' : isEditing ? 'Guardar cambios' : 'Guardar alumno' }}</BaseButton></div>
    </form>
  </div>
</template>
