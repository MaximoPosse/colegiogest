<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import {
  BookOpen, CalendarCheck, CalendarDays, ClipboardList, GraduationCap,
  LayoutDashboard, Megaphone, Settings2, UserRound, Users, X,
} from '@lucide/vue'
import { session } from '../data/demoStore'

defineProps({ open: { type: Boolean, default: false } })
const emit = defineEmits(['close'])
const route = useRoute()
const role = computed(() => session.user?.role ?? 'administrador')

const menus = {
  administrador: [
    { label: 'General', items: [{ label: 'Panel principal', to: '/app', icon: LayoutDashboard }] },
    { label: 'Gestión escolar', items: [
      { label: 'Alumnos', to: '/app/alumnos', icon: Users },
      { label: 'Usuarios y roles', to: '/app/usuarios', icon: UserRound },
      { label: 'Cursos y materias', to: '/app/cursos', icon: BookOpen },
      { label: 'Inscripciones', to: '/app/inscripciones', icon: GraduationCap },
    ] },
    { label: 'Comunidad', items: [
      { label: 'Calificaciones', to: '/app/calificaciones', icon: ClipboardList },
      { label: 'Actividades', to: '/app/actividades', icon: CalendarDays },
      { label: 'Avisos', to: '/app/avisos', icon: Megaphone },
    ] },
  ],
  profesor: [
    { label: 'Mi espacio', items: [
      { label: 'Panel principal', to: '/app', icon: LayoutDashboard },
      { label: 'Mis cursos', to: '/app/mis-cursos', icon: BookOpen },
      { label: 'Asistencia', to: '/app/asistencia', icon: CalendarCheck },
      { label: 'Calificaciones', to: '/app/calificaciones', icon: ClipboardList },
      { label: 'Actividades', to: '/app/actividades', icon: CalendarDays },
      { label: 'Avisos', to: '/app/avisos', icon: Megaphone },
    ] },
  ],
  alumno: [
    { label: 'Mi espacio', items: [
      { label: 'Panel principal', to: '/app', icon: LayoutDashboard },
      { label: 'Mis datos y materias', to: '/app/perfil', icon: UserRound },
      { label: 'Mis calificaciones', to: '/app/mis-calificaciones', icon: ClipboardList },
      { label: 'Mis actividades', to: '/app/mis-actividades', icon: CalendarDays },
      { label: 'Avisos', to: '/app/avisos', icon: Megaphone },
    ] },
  ],
}

const sections = computed(() => menus[role.value] ?? menus.administrador)
function isActive(path) {
  return path === '/app' ? route.path === path : route.path === path || route.path.startsWith(`${path}/`)
}
</script>

<template>
  <div v-if="open" class="sidebar-scrim" @click="emit('close')"></div>
  <aside class="side-menu" :class="{ 'side-menu--open': open }" aria-label="Navegación principal">
    <div class="side-menu__mobile-head">
      <span>Menú</span><button type="button" aria-label="Cerrar menú" @click="emit('close')"><X :size="19" /></button>
    </div>
    <nav>
      <div v-for="section in sections" :key="section.label" class="menu-section">
        <p class="menu-section__title">{{ section.label }}</p>
        <RouterLink
          v-for="item in section.items"
          :key="item.to"
          :to="item.to"
          class="menu-link"
          :class="{ 'menu-link--active': isActive(item.to) }"
          @click="emit('close')"
        >
          <component :is="item.icon" :size="18" :stroke-width="1.8" />
          <span>{{ item.label }}</span>
        </RouterLink>
      </div>
    </nav>
    <div class="side-menu__footer">
      <div class="side-menu__help"><Settings2 :size="17" /><span>Entorno de demostración</span></div>
      <span>© 2026 ColegioGest</span>
    </div>
  </aside>
</template>
