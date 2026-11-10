import { createRouter, createWebHistory } from 'vue-router'
import AppLayout from '../layouts/AppLayout.vue'
import HomeView from '../views/HomeView.vue'
import LoginView from '../views/LoginView.vue'
import RecoverView from '../views/RecoverView.vue'
import ResetPasswordView from '../views/ResetPasswordView.vue'
import DashboardView from '../views/DashboardView.vue'
import StudentsView from '../views/StudentsView.vue'
import StudentFormView from '../views/StudentFormView.vue'
import TeachersView from '../views/TeachersView.vue'
import AttendanceView from '../views/AttendanceView.vue'
import MyAttendanceView from '../views/MyAttendanceView.vue'
import GradesView from '../views/GradesView.vue'
import ActivitiesView from '../views/ActivitiesView.vue'
import NoticesView from '../views/NoticesView.vue'
import ProfileView from '../views/ProfileView.vue'
import CatalogView from '../views/CatalogView.vue'
import CoursesView from '../views/CoursesView.vue'
import AccessDeniedView from '../views/AccessDeniedView.vue'
import NotFoundView from '../views/NotFoundView.vue'
import { initAuth, session } from '../stores/auth'

const routes = [
  { path: '/', name: 'home', component: HomeView, meta: { public: true } },
  { path: '/login', name: 'login', component: LoginView, meta: { public: true } },
  { path: '/recuperar', name: 'recover', component: RecoverView, meta: { public: true } },
  { path: '/restablecer', name: 'reset-password', component: ResetPasswordView, meta: { public: true } },
  {
    path: '/app',
    component: AppLayout,
    children: [
      { path: '', name: 'dashboard', component: DashboardView, meta: { roles: ['administrador', 'profesor', 'alumno'] } },
      { path: 'alumnos', name: 'students', component: StudentsView, meta: { roles: ['administrador'] } },
      { path: 'alumnos/nuevo', name: 'student-new', component: StudentFormView, meta: { roles: ['administrador'] } },
      { path: 'alumnos/:id/editar', name: 'student-edit', component: StudentFormView, meta: { roles: ['administrador'] } },
      { path: 'profesores', name: 'teachers', component: TeachersView, meta: { roles: ['administrador'] } },
      { path: 'usuarios', name: 'users', component: CatalogView, props: { section: 'usuarios' }, meta: { roles: ['administrador'] } },
      { path: 'cursos', name: 'catalog', component: CatalogView, props: { section: 'cursos' }, meta: { roles: ['administrador'] } },
      { path: 'inscripciones', name: 'enrollments', component: CatalogView, props: { section: 'inscripciones' }, meta: { roles: ['administrador'] } },
      { path: 'mis-cursos', name: 'courses', component: CoursesView, meta: { roles: ['profesor', 'alumno'] } },
      { path: 'asistencia', name: 'attendance', component: AttendanceView, meta: { roles: ['profesor'] } },
      { path: 'mis-asistencias', name: 'my-attendance', component: MyAttendanceView, meta: { roles: ['alumno'] } },
      { path: 'calificaciones', name: 'grades', component: GradesView, meta: { roles: ['administrador', 'profesor'] } },
      { path: 'mis-calificaciones', name: 'my-grades', component: GradesView, meta: { roles: ['alumno'] } },
      { path: 'actividades', name: 'activities', component: ActivitiesView, meta: { roles: ['administrador', 'profesor'] } },
      { path: 'mis-actividades', name: 'my-activities', component: ActivitiesView, meta: { roles: ['alumno'] } },
      { path: 'avisos', name: 'notices', component: NoticesView, meta: { roles: ['administrador', 'profesor', 'alumno'] } },
      { path: 'perfil', name: 'profile', component: ProfileView, meta: { roles: ['administrador', 'profesor', 'alumno'] } },
    ],
  },
  { path: '/sin-permiso', name: 'access-denied', component: AccessDeniedView, meta: { public: true } },
  { path: '/:pathMatch(.*)*', name: 'not-found', component: NotFoundView, meta: { public: true } },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior: () => ({ top: 0 }),
})

router.beforeEach(async (to) => {
  await initAuth()

  if (to.meta.public) {
    if (session.user && (to.name === 'login' || to.name === 'home')) {
      return '/app'
    }
    return true
  }

  if (!session.user) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }

  if (to.meta.roles && !to.meta.roles.includes(session.user.role)) {
    return { name: 'access-denied' }
  }

  return true
})

export default router
