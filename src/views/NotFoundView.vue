<script setup>
import { ArrowLeft, SearchX } from '@lucide/vue'
</script>

<template>
  <div class="simple-state-page">
    <RouterLink class="brand" to="/"><img src="/escudo-colegiogest.svg" alt="" class="brand__crest" /><span><strong>ColegioGest</strong><small>Gestión escolar</small></span></RouterLink>
    <main class="simple-state-card"><span class="simple-state-card__icon"><SearchX :size="28" /></span><span class="eyebrow">Error 404</span><h1>Esta página no está en el mapa</h1><p>Puede que el enlace haya cambiado. Te ayudamos a volver al inicio.</p><RouterLink to="/" class="back-link"><ArrowLeft :size="16" /> Ir al inicio</RouterLink></main>
  </div>
</template>
