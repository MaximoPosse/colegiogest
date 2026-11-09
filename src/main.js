import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import { initAuth } from './stores/auth'
import './style.css'

async function bootstrap() {
  await initAuth()
  createApp(App).use(router).mount('#app')
}

bootstrap()
