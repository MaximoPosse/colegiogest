import { reactive } from 'vue'

export const ui = reactive({
  toast: null,
})

let toastTimer

export function notify(message, type = 'success') {
  if (typeof window !== 'undefined') window.clearTimeout(toastTimer)
  ui.toast = { message, type, id: Date.now() }
  toastTimer = setTimeout(() => {
    ui.toast = null
  }, 4200)
}

export function clearToast() {
  if (typeof window !== 'undefined') window.clearTimeout(toastTimer)
  ui.toast = null
}
