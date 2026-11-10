<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { GraduationCap, Pencil, Plus, RotateCcw, Trash2, X } from '@lucide/vue'
import BaseButton from '../components/BaseButton.vue'
import DataTable from '../components/DataTable.vue'
import FormField from '../components/FormField.vue'
import SearchFilterBar from '../components/SearchFilterBar.vue'
import StatusBadge from '../components/StatusBadge.vue'
import { describeError, isDuplicateError } from '../lib/errors'
import { normalizeDni } from '../lib/format'
import {
  createTeacher,
  deactivateTeacher,
  fetchTeacherList,
  updateTeacher,
} from '../services/school'
import { notify } from '../stores/toast'

const teachers = ref([])
const search = ref('')
const statusFilter = ref('')
const showForm = ref(false)
const editingId = ref(null)
const selectedForDelete = ref(null)
const loading = ref(true)
const saving = ref(false)
const error = ref('')
const formError = ref('')
const errors = reactive({})
const form = reactive({
  name: '',
  surname: '',
  dni: '',
  email: '',
  password: '',
  status: 'activo',
})

const columns = [
  { key: 'name', label: 'Docente' },
  { key: 'dniDisplay', label: 'DNI' },
  { key: 'email', label: 'Correo electrónico' },
  { key: 'status', label: 'Estado' },
  { key: 'actions', label: '' },
]

const filters = computed(() => [
  {
    key: 'status',
    label: 'Filtrar por estado',
    value: statusFilter.value,
    options: [
      { label: 'Todos los estados', value: '' },
      { label: 'Activos', value: 'activo' },
      { label: 'Inactivos', value: 'inactivo' },
    ],
  },
])

const filteredTeachers = computed(() => teachers.value.filter((teacher) => {
  const term = search.value.trim().toLocaleLowerCase('es')
  const matchesSearch = !term
    || `${teacher.fullName} ${teacher.dni} ${teacher.email}`.toLocaleLowerCase('es').includes(term)
  const matchesStatus = !statusFilter.value || teacher.estado === statusFilter.value
  return matchesSearch && matchesStatus
}))

function setFilter({ key, value }) {
  if (key === 'status') statusFilter.value = value
}

function resetErrors() {
  Object.keys(errors).forEach((key) => delete errors[key])
  formError.value = ''
}

function resetForm() {
  resetErrors()
  Object.assign(form, {
    name: '',
    surname: '',
    dni: '',
    email: '',
    password: '',
    status: 'activo',
  })
}

function openForm() {
  editingId.value = null
  resetForm()
  showForm.value = true
}

function editTeacher(teacher) {
  resetErrors()
  editingId.value = teacher.id
  Object.assign(form, {
    name: teacher.name,
    surname: teacher.surname,
    dni: teacher.dni,
    email: teacher.email,
    password: '',
    status: teacher.estado,
  })
  showForm.value = true
}

function validate() {
  resetErrors()
  if (!form.name.trim()) errors.name = 'El nombre es obligatorio.'
  if (!form.surname.trim()) errors.surname = 'El apellido es obligatorio.'
  if (!/^\d{7,9}$/.test(form.dni)) errors.dni = 'El DNI debe tener entre 7 y 9 dígitos.'
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(form.email.trim())) {
    errors.email = 'Ingresá un correo electrónico válido.'
  }
  if (!editingId.value && form.password && form.password.length < 6) {
    errors.password = 'La contraseña inicial debe tener al menos 6 caracteres.'
  }
  return Object.keys(errors).length === 0
}

async function loadTeachers() {
  loading.value = true
  error.value = ''
  try {
    teachers.value = await fetchTeacherList()
  } catch (caught) {
    error.value = describeError(caught)
    notify(error.value, 'error')
  } finally {
    loading.value = false
  }
}

onMounted(loadTeachers)

async function saveTeacher() {
  if (saving.value || !validate()) return
  saving.value = true
  try {
    if (editingId.value) {
      await updateTeacher(editingId.value, {
        nombre: form.name,
        apellido: form.surname,
        dni: form.dni,
        correo: form.email,
        estado: form.status,
      })
      notify('El profesor se actualizó correctamente.')
    } else {
      await createTeacher({
        nombre: form.name,
        apellido: form.surname,
        dni: form.dni,
        correo: form.email,
        password: form.password,
      })
      notify('El profesor se creó correctamente.')
    }
    showForm.value = false
    editingId.value = null
    await loadTeachers()
  } catch (caught) {
    if (isDuplicateError(caught, 'email')) errors.email = 'Ya existe un usuario con ese correo.'
    else if (isDuplicateError(caught, 'dni')) errors.dni = 'Ya existe un usuario con ese DNI.'
    else formError.value = describeError(caught)
    notify(describeError(caught), 'error')
  } finally {
    saving.value = false
  }
}

async function reactivateTeacher(teacher) {
  if (saving.value) return
  if (!window.confirm(`¿Reactivar la cuenta de ${teacher.fullName}?`)) return
  saving.value = true
  try {
    await updateTeacher(teacher.id, {
      nombre: teacher.name,
      apellido: teacher.surname,
      dni: teacher.dni,
      correo: teacher.email,
      estado: 'activo',
    })
    notify(`La cuenta de ${teacher.fullName} quedó activa.`)
    await loadTeachers()
  } catch (caught) {
    notify(describeError(caught), 'error')
  } finally {
    saving.value = false
  }
}

async function confirmDeactivate() {
  if (!selectedForDelete.value || saving.value) return
  saving.value = true
  try {
    await deactivateTeacher(selectedForDelete.value.id)
    notify(`${selectedForDelete.value.fullName} fue dado de baja.`)
    selectedForDelete.value = null
    await loadTeachers()
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
      <div>
        <div class="breadcrumb">Gestión escolar <span>/</span> <b>Profesores</b></div>
        <h1>Profesores</h1>
        <p>Administrá las cuentas docentes, sus datos y su estado de acceso.</p>
      </div>
      <BaseButton @click="showForm ? (showForm = false) : openForm()">
        <Plus :size="17" /> Nuevo profesor
      </BaseButton>
    </div>

    <form v-if="showForm" class="panel catalog-form" novalidate @submit.prevent="saveTeacher">
      <div class="panel-heading">
        <div>
          <h2>{{ editingId ? 'Editar profesor' : 'Crear un profesor' }}</h2>
          <p>Los datos se guardan directamente en Supabase.</p>
        </div>
        <button type="button" class="icon-button" aria-label="Cerrar formulario" @click="showForm = false; editingId = null">
          <X :size="18" />
        </button>
      </div>
      <div class="form-grid">
        <FormField id="teacher-name" label="Nombre" :error="errors.name" required>
          <template #default="{ id }"><input :id="id" v-model="form.name" placeholder="Ej. Santiago" maxlength="80" /></template>
        </FormField>
        <FormField id="teacher-surname" label="Apellido" :error="errors.surname" required>
          <template #default="{ id }"><input :id="id" v-model="form.surname" placeholder="Ej. López" maxlength="80" /></template>
        </FormField>
        <FormField id="teacher-dni" label="DNI" :error="errors.dni" required>
          <template #default="{ id }"><input :id="id" :value="form.dni" inputmode="numeric" placeholder="Sin puntos" @input="form.dni = normalizeDni($event.target.value)" /></template>
        </FormField>
        <FormField id="teacher-email" label="Correo electrónico" :error="errors.email" required>
          <template #default="{ id }"><input :id="id" v-model="form.email" type="email" placeholder="docente@colegiogest.edu.ar" /></template>
        </FormField>
        <FormField v-if="!editingId" id="teacher-password" label="Contraseña inicial" :error="errors.password" hint="Si se deja vacía se usa demo123.">
          <template #default="{ id }"><input :id="id" v-model="form.password" type="password" placeholder="Mínimo 6 caracteres" /></template>
        </FormField>
      </div>
      <div v-if="formError" class="form-note form-note--error"><span>!</span><p>{{ formError }}</p></div>
      <div class="form-actions">
        <BaseButton variant="outline" @click="showForm = false; editingId = null">Cancelar</BaseButton>
        <BaseButton type="submit" :disabled="saving">
          <Plus :size="16" /> {{ saving ? 'Guardando…' : editingId ? 'Guardar cambios' : 'Crear profesor' }}
        </BaseButton>
      </div>
    </form>

    <section class="panel list-panel">
      <div class="list-panel__top">
        <div>
          <h2>Plantel docente</h2>
          <p>{{ filteredTeachers.length }} {{ filteredTeachers.length === 1 ? 'profesor' : 'profesores' }}</p>
        </div>
        <span class="read-only-label"><GraduationCap :size="15" /> Datos en Supabase</span>
      </div>
      <SearchFilterBar v-model="search" placeholder="Buscar por nombre, DNI o correo..." :filters="filters" @filter="setFilter" />
      <DataTable
        :columns="columns"
        :rows="filteredTeachers"
        paginated
        :page-size="10"
        :empty-title="loading ? 'Cargando profesores...' : 'No hay profesores para mostrar'"
        :empty-text="loading ? 'Estamos consultando la base de datos.' : 'Probá ajustar la búsqueda o creá un nuevo profesor.'"
      >
        <template #cell="{ row, column }">
          <template v-if="column.key === 'name'">
            <span class="user-name-cell">
              <span class="avatar avatar--table">{{ row.name.charAt(0) }}{{ row.surname.charAt(0) }}</span>
              <strong>{{ row.surname }}, {{ row.name }}</strong>
            </span>
          </template>
          <StatusBadge v-else-if="column.key === 'status'" :status="row.status" />
          <div v-else-if="column.key === 'actions'" class="table-actions">
            <button type="button" class="icon-button icon-button--small" :aria-label="`Editar ${row.fullName}`" @click="editTeacher(row)">
              <Pencil :size="16" />
            </button>
            <button
              v-if="row.estado === 'activo'"
              type="button"
              class="icon-button icon-button--small icon-button--danger"
              :disabled="saving"
              :aria-label="`Dar de baja a ${row.fullName}`"
              @click="selectedForDelete = row"
            >
              <Trash2 :size="16" />
            </button>
            <button
              v-else
              type="button"
              class="icon-button icon-button--small"
              :disabled="saving"
              :aria-label="`Reactivar a ${row.fullName}`"
              @click="reactivateTeacher(row)"
            >
              <RotateCcw :size="16" />
            </button>
          </div>
          <span v-else>{{ row[column.key] }}</span>
        </template>
      </DataTable>
    </section>

    <div v-if="selectedForDelete" class="modal-backdrop" @click.self="selectedForDelete = null">
      <section class="confirm-dialog" role="dialog" aria-modal="true" aria-labelledby="teacher-delete-title">
        <span class="confirm-dialog__icon confirm-dialog__icon--danger"><Trash2 :size="20" /></span>
        <h2 id="teacher-delete-title">¿Dar de baja a este profesor?</h2>
        <p>
          {{ selectedForDelete.fullName }} quedará inactivo y no podrá iniciar sesión. Si tiene
          asignaciones del ciclo lectivo actual, primero tenés que reasignarlas o eliminarlas.
        </p>
        <div class="confirm-dialog__actions">
          <BaseButton variant="outline" :disabled="saving" @click="selectedForDelete = null">Cancelar</BaseButton>
          <BaseButton variant="danger" :disabled="saving" @click="confirmDeactivate">
            {{ saving ? 'Procesando…' : 'Confirmar baja' }}
          </BaseButton>
        </div>
      </section>
    </div>
  </div>
</template>
