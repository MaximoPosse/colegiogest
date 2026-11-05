<script setup>
import { ArrowRight, BookOpenCheck, CalendarCheck, ChartNoAxesColumnIncreasing, GraduationCap, ShieldCheck, UsersRound } from '@lucide/vue'
import BaseButton from '../components/BaseButton.vue'
</script>

<template>
  <div class="public-page">
    <header class="public-header">
      <RouterLink class="brand" to="/" aria-label="ColegioGest, inicio">
        <img src="/escudo-colegiogest.svg" alt="" class="brand__crest" />
        <span><strong>ColegioGest</strong><small>Gestión escolar</small></span>
      </RouterLink>
      <RouterLink to="/login" class="public-header__login">Ingresar <ArrowRight :size="16" /></RouterLink>
    </header>

    <main>
      <section class="landing-hero">
        <div class="landing-hero__copy">
          <div class="eyebrow"><span class="eyebrow__dot"></span> Una comunidad que aprende</div>
          <h1>La vida escolar,<br /><span>más conectada.</span></h1>
          <p>Un espacio para acompañar cada día del colegio. Organizá la información académica y mantené cerca a toda la comunidad educativa.</p>
          <div class="landing-hero__actions">
            <RouterLink to="/login"><BaseButton>Ingresar al sistema <ArrowRight :size="17" /></BaseButton></RouterLink>
            <a class="landing-hero__secondary" href="#comunidad">Conocé la plataforma</a>
          </div>
          <div class="landing-hero__note"><ShieldCheck :size="17" /> Acceso seguro para cada integrante</div>
        </div>
        <div class="landing-illustration" aria-label="Resumen de la actividad escolar">
          <div class="landing-illustration__sun"></div>
          <div class="landing-illustration__card landing-illustration__card--top">
            <div class="mini-card__heading"><span class="mini-card__icon"><CalendarCheck :size="16" /></span><span>Asistencia de hoy</span><span class="mini-card__more">•••</span></div>
            <div class="mini-card__number">94<span>%</span></div>
            <div class="mini-progress"><i></i></div>
            <div class="mini-card__caption">Un gran día para aprender</div>
          </div>
          <div class="landing-illustration__card landing-illustration__card--bottom">
            <div class="mini-card__heading"><span class="mini-card__icon mini-card__icon--rose"><BookOpenCheck :size="16" /></span><span>Tu semana</span></div>
            <div class="mini-schedule"><span><i class="schedule-dot schedule-dot--blue"></i> Matemática</span><b>08:00</b></div>
            <div class="mini-schedule"><span><i class="schedule-dot schedule-dot--rose"></i> Lengua</span><b>10:15</b></div>
            <div class="mini-schedule"><span><i class="schedule-dot schedule-dot--green"></i> Ciencias</span><b>12:00</b></div>
          </div>
          <div class="landing-illustration__seal"><GraduationCap :size="24" /><span>Aprender<br />juntos</span></div>
          <div class="landing-illustration__dots"></div>
          <div class="landing-illustration__plant"><i></i><i></i><i></i><i></i></div>
        </div>
      </section>

      <section id="comunidad" class="landing-community">
        <div class="section-intro">
          <span class="eyebrow">Todo en un mismo lugar</span>
          <h2>Cada rol, su propio espacio.</h2>
          <p>La información que necesitás, organizada para que puedas enfocarte en lo importante.</p>
        </div>
        <div class="role-cards">
          <article class="role-card"><span class="role-card__icon role-card__icon--blue"><UsersRound :size="21" /></span><h3>Administración</h3><p>Alumnos, cursos, inscripciones y la gestión diaria del colegio.</p></article>
          <article class="role-card"><span class="role-card__icon role-card__icon--rose"><BookOpenCheck :size="21" /></span><h3>Docentes</h3><p>Cursos, asistencia, calificaciones y actividades en un solo lugar.</p></article>
          <article class="role-card"><span class="role-card__icon role-card__icon--green"><ChartNoAxesColumnIncreasing :size="21" /></span><h3>Estudiantes</h3><p>Un espacio personal para seguir tus materias y próximos desafíos.</p></article>
        </div>
      </section>
    </main>
    <footer class="public-footer"><span>© 2026 ColegioGest · Sistema de gestión escolar</span><span>Hecho para acompañar a nuestra comunidad</span></footer>
  </div>
</template>
