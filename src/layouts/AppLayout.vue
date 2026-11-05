<script setup>
import { ref } from 'vue'
import AppHeader from '../components/AppHeader.vue'
import SideMenu from '../components/SideMenu.vue'

const menuOpen = ref(false)
</script>

<template>
  <div class="app-shell">
    <AppHeader :menu-open="menuOpen" @toggle-menu="menuOpen = !menuOpen" />
    <div class="app-shell__body">
      <SideMenu :open="menuOpen" @close="menuOpen = false" />
      <main class="main-content"><RouterView /></main>
    </div>
  </div>
</template>
