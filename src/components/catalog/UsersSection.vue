<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { Plus, ShieldCheck, UserRound, X } from '@lucide/vue'
import BaseButton from '../BaseButton.vue'
import DataTable from '../DataTable.vue'
import FormField from '../FormField.vue'
import SearchFilterBar from '../SearchFilterBar.vue'
import StatusBadge from '../StatusBadge.vue'
import { describeError, isDuplicateError } from '../../lib/errors'
import { normalizeDni } from '../../lib/format'
import { changeUserRole, createAdministrator, fetchUsers, setUserStatus } from '../../services/school'
import { session } from '../../stores/auth'
import { notify } from '../../stores/toast'

const users = ref([])
const search = ref('')
const roleFilter = ref('')
const loading = ref(true)
const saving = ref(false)
const error = ref('')
const showCreateForm = ref(false)
const createFormError = ref('')
const createErrors = reactive({})
const createForm = reactive({ name: '', surname: '', dni: '', email: '', password: '' })

const roleOptions = [
  { value: 'administrador', label: 'Administrador' },
  { value: 'profesor', label: 'Profesor' },
  { value: 'alumno', label: 'Alumno' },
]

const columns = [
  { key: 'name', label: 'Nombre' },
  { key: 'email', label: 'Correo electrónico' },
  { key: 'roleLabel', label: 'Rol' },
  { key: 'status', label: 'Estado' },
  { key: 'actions', label: '' },
]

const filters = computed(() => [
  {
    key: 'role',
    label: 'Filtrar por rol',
    value: roleFilter.value,
    options: [
      { label: 'Todos los roles', value: '' },
      ...roleOptions,
    ],
  },
])

const filteredUsers = computed(() => users.value.filter((user) => {
  const term = search.value.trim().toLocaleLowerCase('es')
  const matchesSearch = !term
    || `${user.fullName} ${user.email} ${user.roleLabel}`.toLocaleLowerCase('es').includes(term)
  const matchesRole = !roleFilter.value || user.role === roleFilter.value
  return matchesSearch && matchesRole
}))

function setFilter({ key, value }) {
  if (key === 'role') roleFilter.value = value
}

async function loadUsers() {
  loading.value = true
  error.value = ''
  try {
    users.value = await fetchUsers()
  } catch (caught) {
    error.value = describeError(caught)
    notify(error.value, 'error')
  } finally {
    loading.value = false
  }
}

onMounted(loadUsers)

function openCreateForm() {
  Object.keys(createErrors).forEach((key) => delete createErrors[key])
  createFormError.value = ''
  Object.assign(createForm, { name: '', surname: '', dni: '', email: '', password: '' })
  showCreateForm.value = true
}

function validateCreateForm() {
  Object.keys(createErrors).forEach((key) => delete createErrors[key])
  createFormError.value = ''
  if (!createForm.name.trim()) createErrors.name = 'El nombre es obligatorio.'
  if (!createForm.surname.trim()) createErrors.surname = 'El apellido es obligatorio.'
  if (!/^\d{7,9}$/.test(normalizeDni(createForm.dni))) createErrors.dni = 'El DNI debe tener entre 7 y 9 dígitos.'
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(createForm.email.trim())) createErrors.email = 'Ingresá un correo válido.'
  if (!createForm.password || createForm.password.length < 6) createErrors.password = 'La contraseña debe tener al menos 6 caracteres.'
  return Object.keys(createErrors).length === 0
}

async function saveAdministrator() {
  if (saving.value || !validateCreateForm()) return
  saving.value = true
  try {
    await createAdministrator({
      nombre: createForm.name,
      apellido: createForm.surname,
      dni: normalizeDni(createForm.dni),
      correo: createForm.email,
      password: createForm.password,
    })
    showCreateForm.value = false
    notify('La cuenta de administrador se creó correctamente.')
    await loadUsers()
  } catch (caught) {
    if (isDuplicateError(caught, 'email')) createErrors.email = 'Ya existe un usuario con ese correo.'
    else if (isDuplicateError(caught, 'dni')) createErrors.dni = 'Ya existe un usuario con ese DNI.'
    else createFormError.value = describeError(caught)
    notify(describeError(caught), 'error')
  } finally {
    saving.value = false
  }
}

async function requestRoleChange(user, event) {
  const nextRole = event.target.value
  if (nextRole === user.role) return

  const nextLabel = roleOptions.find((item) => item.value === nextRole)?.label ?? nextRole
  const accepted = window.confirm(
    `¿Cambiar el rol de ${user.fullName} a ${nextLabel}?\n\n`
    + 'El cambio ajusta sus perfiles académicos y conserva el historial. '
    + 'Si el docente tiene asignaciones vigentes, primero deberás reasignarlas.',
  )
  if (!accepted) {
    event.target.value = user.role
    return
  }

  saving.value = true
  try {
    await changeUserRole(user.id, nextRole)
    notify(`El rol de ${user.fullName} se actualizó a ${nextLabel}.`)
    await loadUsers()
  } catch (caught) {
    event.target.value = user.role
    notify(describeError(caught), 'error')
  } finally {
    saving.value = false
  }
}

async function toggleUserStatus(user) {
  if (saving.value || user.id === session.user?.id) return
  const next = user.estado === 'activo' ? 'inactivo' : 'activo'
  const action = next === 'activo' ? 'reactivar' : 'desactivar'
  if (!window.confirm(`¿Querés ${action} la cuenta de ${user.fullName}?`)) return
  saving.value = true
  try {
    await setUserStatus(user.id, next)
    notify(`La cuenta de ${user.fullName} quedó ${next === 'activo' ? 'activa' : 'inactiva'}.`)
    await loadUsers()
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
        <div class="breadcrumb">Gestión escolar <span>/</span> <b>Usuarios y roles</b></div>
        <h1>Usuarios y roles</h1>
        <p>Consultá y administrá los perfiles de acceso al sistema.</p>
      </div>
      <span class="read-only-label"><ShieldCheck :size="16" /> Permisos en PostgreSQL</span>
      <BaseButton @click="showCreateForm ? (showCreateForm = false) : openCreateForm()"><Plus :size="17" /> Nuevo administrador</BaseButton>
    </div>

    <form v-if="showCreateForm" class="panel catalog-form" novalidate @submit.prevent="saveAdministrator">
      <div class="panel-heading">
        <div><h2>Crear cuenta administradora</h2><p>La nueva cuenta tendrá permisos de administración del sistema.</p></div>
        <button type="button" class="icon-button" aria-label="Cerrar formulario" @click="showCreateForm = false"><X :size="18" /></button>
      </div>
      <div class="form-grid">
        <FormField id="admin-name" label="Nombre" :error="createErrors.name" required><template #default="{ id }"><input :id="id" v-model="createForm.name" maxlength="80" autocomplete="given-name" /></template></FormField>
        <FormField id="admin-surname" label="Apellido" :error="createErrors.surname" required><template #default="{ id }"><input :id="id" v-model="createForm.surname" maxlength="80" autocomplete="family-name" /></template></FormField>
        <FormField id="admin-dni" label="DNI" :error="createErrors.dni" required><template #default="{ id }"><input :id="id" :value="createForm.dni" inputmode="numeric" @input="createForm.dni = normalizeDni($event.target.value)" /></template></FormField>
        <FormField id="admin-email" label="Correo electrónico" :error="createErrors.email" required><template #default="{ id }"><input :id="id" v-model="createForm.email" type="email" autocomplete="email" /></template></FormField>
        <FormField id="admin-password" label="Contraseña inicial" :error="createErrors.password" hint="Mínimo 6 caracteres." required><template #default="{ id }"><input :id="id" v-model="createForm.password" type="password" autocomplete="new-password" /></template></FormField>
      </div>
      <div v-if="createFormError" class="form-note form-note--error"><span>!</span><p>{{ createFormError }}</p></div>
      <div class="form-note"><span>i</span><p>Comunicá la contraseña inicial por un canal seguro. No la incluyas en documentos compartidos.</p></div>
      <div class="form-actions">
        <BaseButton variant="outline" :disabled="saving" @click="showCreateForm = false">Cancelar</BaseButton>
        <BaseButton type="submit" :disabled="saving"><Plus :size="16" /> {{ saving ? 'Creando…' : 'Crear administrador' }}</BaseButton>
      </div>
    </form>

    <section class="panel list-panel">
      <div class="list-panel__top">
        <div>
          <h2>Usuarios registrados</h2>
          <p>{{ filteredUsers.length }} {{ filteredUsers.length === 1 ? 'registro' : 'registros' }}</p>
        </div>
        <span class="read-only-label"><UserRound :size="15" /> Datos en Supabase</span>
      </div>
      <SearchFilterBar v-model="search" placeholder="Buscar usuario..." :filters="filters" @filter="setFilter" />
      <DataTable
        :columns="columns"
        :rows="filteredUsers"
        paginated
        :page-size="10"
        :empty-title="loading ? 'Cargando usuarios...' : 'No hay usuarios para mostrar'"
        :empty-text="loading ? 'Estamos consultando la base de datos.' : 'Probá ajustar la búsqueda o el rol.'"
      >
        <template #cell="{ row, column }">
          <span v-if="column.key === 'name'" class="user-name-cell">
            <span class="avatar avatar--table">{{ row.initials }}</span>
            <strong>{{ row.fullName }}</strong>
          </span>
          <div v-else-if="column.key === 'roleLabel'" class="role-cell">
            <select
              :value="row.role"
              :disabled="saving || row.id === session.user?.id"
              :aria-label="`Rol de ${row.fullName}`"
              @change="requestRoleChange(row, $event)"
            >
              <option v-for="role in roleOptions" :key="role.value" :value="role.value">{{ role.label }}</option>
            </select>
          </div>
          <StatusBadge v-else-if="column.key === 'status'" :status="row.status" />
          <div v-else-if="column.key === 'actions'" class="table-actions">
            <button
              v-if="row.id !== session.user?.id"
              type="button"
              class="icon-button icon-button--small"
              :disabled="saving"
              :aria-label="`${row.estado === 'activo' ? 'Desactivar' : 'Reactivar'} a ${row.fullName}`"
              @click="toggleUserStatus(row)"
            >
              <X :size="16" />
            </button>
          </div>
          <span v-else>{{ row[column.key] }}</span>
        </template>
      </DataTable>
    </section>
  </div>
</template>
