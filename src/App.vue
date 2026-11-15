<script setup>
import { onBeforeUnmount, watch } from 'vue'
import { RouterView, useRouter } from 'vue-router'
import ToastViewport from './components/ToastViewport.vue'
import { session, signOut } from './stores/auth'
import { notify } from './stores/toast'

const router = useRouter()
const IDLE_TIMEOUT_MS = 30 * 60 * 1000
const LAST_ACTIVITY_KEY = 'colegiogest:lastActivityAt'
const activityEvents = ['pointerdown', 'keydown', 'scroll', 'touchstart', 'mousemove']
let idleTimer
let lastActivityWrite = 0

function clearIdleTimer() {
  if (idleTimer) window.clearTimeout(idleTimer)
  idleTimer = undefined
}

async function expireIdleSession() {
  if (!session.user) return
  clearIdleTimer()
  sessionStorage.removeItem(LAST_ACTIVITY_KEY)
  try {
    await signOut()
  } finally {
    notify('La sesión se cerró por inactividad. Iniciá sesión nuevamente.', 'error')
    router.replace('/login')
  }
}

function scheduleIdleExpiry(delay = IDLE_TIMEOUT_MS) {
  clearIdleTimer()
  idleTimer = window.setTimeout(expireIdleSession, Math.max(0, delay))
}

function handleActivity() {
  if (!session.user) return
  const now = Date.now()
  if (now - lastActivityWrite >= 60_000) {
    localStorage.setItem(LAST_ACTIVITY_KEY, String(now))
    lastActivityWrite = now
  }
  scheduleIdleExpiry()
}

function checkIdleOnVisibility() {
  if (!session.user || document.visibilityState !== 'visible') return
  const lastActivity = Number(localStorage.getItem(LAST_ACTIVITY_KEY)) || Date.now()
  const remaining = IDLE_TIMEOUT_MS - (Date.now() - lastActivity)
  if (remaining <= 0) expireIdleSession()
  else scheduleIdleExpiry(remaining)
}

function checkCrossTabActivity(event) {
  if (event.key !== LAST_ACTIVITY_KEY || !session.user) return
  const lastActivity = Number(event.newValue) || Date.now()
  const remaining = IDLE_TIMEOUT_MS - (Date.now() - lastActivity)
  if (remaining <= 0) expireIdleSession()
  else scheduleIdleExpiry(remaining)
}

watch(() => session.user?.id, (userId) => {
  clearIdleTimer()
  activityEvents.forEach((event) => window.removeEventListener(event, handleActivity))
  document.removeEventListener('visibilitychange', checkIdleOnVisibility)
  window.removeEventListener('storage', checkCrossTabActivity)
  if (!userId) {
    localStorage.removeItem(LAST_ACTIVITY_KEY)
    return
  }

  const lastActivity = Number(localStorage.getItem(LAST_ACTIVITY_KEY))
  if (lastActivity && Date.now() - lastActivity >= IDLE_TIMEOUT_MS) {
    expireIdleSession()
    return
  }

  if (!lastActivity) {
    localStorage.setItem(LAST_ACTIVITY_KEY, String(Date.now()))
    lastActivityWrite = Date.now()
  } else {
    lastActivityWrite = lastActivity
  }
  activityEvents.forEach((event) => window.addEventListener(event, handleActivity, { passive: true }))
  document.addEventListener('visibilitychange', checkIdleOnVisibility)
  window.addEventListener('storage', checkCrossTabActivity)
  scheduleIdleExpiry(lastActivity ? IDLE_TIMEOUT_MS - (Date.now() - lastActivity) : IDLE_TIMEOUT_MS)
}, { immediate: true })

onBeforeUnmount(() => {
  clearIdleTimer()
  activityEvents.forEach((event) => window.removeEventListener(event, handleActivity))
  document.removeEventListener('visibilitychange', checkIdleOnVisibility)
  window.removeEventListener('storage', checkCrossTabActivity)
})
</script>

<template>
  <RouterView />
  <ToastViewport />
</template>
