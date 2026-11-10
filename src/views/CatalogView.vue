<script setup>
import { computed } from 'vue'
import CoursesSection from '../components/catalog/CoursesSection.vue'
import EnrollmentsSection from '../components/catalog/EnrollmentsSection.vue'
import UsersSection from '../components/catalog/UsersSection.vue'

const props = defineProps({ section: { type: String, required: true } })

const component = computed(() => {
  if (props.section === 'usuarios') return UsersSection
  if (props.section === 'inscripciones') return EnrollmentsSection
  return CoursesSection
})
</script>

<template>
  <component :is="component" />
</template>
