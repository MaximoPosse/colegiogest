<script setup>
defineProps({
  label: { type: String, required: true },
  value: { type: [String, Number], required: true },
  detail: { type: String, default: '' },
  icon: { type: Object, required: true },
  tone: { type: String, default: 'blue' },
})
</script>

<template>
  <article class="stat-card">
    <div class="stat-card__top">
      <span class="stat-card__icon" :class="`stat-card__icon--${tone}`"><component :is="icon" :size="19" /></span>
      <span class="stat-card__label">{{ label }}</span>
    </div>
    <div class="stat-card__value">{{ value }}</div>
    <div v-if="detail" class="stat-card__detail">{{ detail }}</div>
  </article>
</template>
