import { reactive } from 'vue'
import {
  initialActivities,
  initialAttendance,
  initialCourses,
  initialEnrollments,
  initialGrades,
  initialNotices,
  initialStudents,
  initialSubjects,
} from './mockData'

export const session = reactive({ user: null })

export const school = reactive({
  students: initialStudents.map((student) => ({ ...student })),
  courses: initialCourses.map((course) => ({ ...course })),
  subjects: initialSubjects.map((subject) => ({ ...subject })),
  activities: initialActivities.map((activity) => ({ ...activity })),
  attendance: initialAttendance.map((record) => ({ ...record })),
  grades: initialGrades.map((grade) => ({ ...grade })),
  notices: initialNotices.map((notice) => ({ ...notice })),
  enrollments: initialEnrollments.map((enrollment) => ({ ...enrollment })),
  toast: null,
})

let toastTimer

export function notify(message, type = 'success') {
  window.clearTimeout(toastTimer)
  school.toast = { message, type, id: Date.now() }
  toastTimer = window.setTimeout(() => {
    school.toast = null
  }, 3600)
}

export function clearToast() {
  window.clearTimeout(toastTimer)
  school.toast = null
}
