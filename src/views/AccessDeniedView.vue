<script setup>
import { ArrowLeft, ShieldAlert } from '@lucide/vue'
</script>

<template>
  <div class="simple-state-page">
    <RouterLink class="brand" to="/"><img src="/escudo-colegiogest.svg" alt="" class="brand__crest" /><span><strong>ColegioGest</strong><small>Gestión escolar</small></span></RouterLink>
    <main class="simple-state-card"><span class="simple-state-card__icon simple-state-card__icon--warning"><ShieldAlert :size="28" /></span><span class="eyebrow">Acceso restringido</span><h1>No tenés permiso para ver esta pantalla</h1><p>El acceso a esta sección depende de tu rol. Volvé a tu espacio para continuar.</p><RouterLink to="/app" class="back-link"><ArrowLeft :size="16" /> Volver a mi panel</RouterLink></main>
  </div>
</template>
