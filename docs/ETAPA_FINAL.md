# Etapa Final · Preparación de entrega y defensa

**ColegioGest · Proyecto Integrador PDISWD · Vue 3 + Supabase**  
Actualización: 16 de noviembre de 2026.

Este documento organiza la revisión final, la demostración y la defensa. Los resultados distinguen pruebas ejecutadas, evidencia histórica y verificaciones que siguen pendientes; no se presentan pendientes como aprobados.

## 1. Revisión final del sistema

- Requerimientos esenciales RF01–RF11 y RF17 implementados en la versión actual; RF12–RF19 también están disponibles, con configuración/pruebas externas pendientes en RF19.
- Alta de administrador, profesor y alumno, cambio de rol y gestión académica disponibles; migraciones 001–010 aplicadas y registradas en Supabase.
- El hardening de migración 009 protege perfiles, desactivación docente y fechas futuras. Migración 010 agrega alta directa de administradores.
- `npm run build` aprobado. Se verificó además una instalación limpia mediante `npm ci` seguida de build en una copia temporal sin `node_modules`.
- PI02–PI06 y PI10–PI11 son evidencia histórica; UI12–UI15 y la validación vacía del alta de administrador se ejecutaron en navegador durante la revisión.
- Los CRUD que escriben datos, pruebas negativas posteriores a 009/010 y las pruebas de RNF se deben repetir en un proyecto Supabase aislado.
- RF20–RF23 (reportes PDF/Excel, notificaciones, boletín y tutores) son mejoras V2, no defectos de V1.

## 2. Versión reproducible en otra computadora

1. Instalar Node.js 20+ y npm.
2. Descargar/clonar el repositorio.
3. Ejecutar `npm ci`.
4. Copiar `.env.example` como `.env` y completar `VITE_SUPABASE_URL` y `VITE_SUPABASE_ANON_KEY` del proyecto autorizado. Nunca usar `service_role` en Vite.
5. Para una base vacía, ejecutar `supabase/setup_completo.sql` una sola vez desde SQL Editor. Contiene migraciones 001–010 y el seed ficticio.
6. Configurar Authentication → URL Configuration: Site URL y Redirect URL `/restablecer`. Para recuperar contraseña por correo, configurar SMTP y un buzón de prueba.
7. Ejecutar `npm run dev`; para validar producción, `npm run build`.

Las migraciones ya están aplicadas al proyecto remoto Colegiogest. No ejecutar el script completo sobre una base existente.

## 3. Guion de demostración funcional

**Importante:** usar cuentas de demostración autorizadas. Para demostrar escrituras, usar un entorno de prueba o registros descartables con limpieza autorizada; no insertar ni borrar datos reales durante la defensa.

1. **Administrador:** iniciar sesión; mostrar panel, alta de administrador, alumnos/profesores, cursos/materias, asignaciones e inscripciones.
2. **Profesor:** abrir Mis cursos; tomar asistencia para el día actual, cargar una calificación y publicar una actividad y un aviso dirigidos a un curso.
3. **Alumno:** consultar sus datos, notas y asistencias; abrir actividad y avisos de su curso; marcar una actividad entregada.
4. **Seguridad:** mostrar que cada rol tiene su propio menú y que una ruta de otro rol deniega acceso. Explicar que RLS aplica el permiso también en PostgreSQL.
5. **Cierre:** cerrar sesión; mencionar recuperación por correo, límites actuales y mejoras V2.

## 4. Arquitectura

```text
Navegador
  Vue 3 + Vite (SPA)
    ├── Vue Router: rutas públicas/privadas y meta.roles
    ├── views: pantallas por proceso y rol
    ├── components: formularios, tablas, menús, tarjetas y avisos
    ├── stores/auth.js: sesión, perfil, login, recuperación y logout
    ├── App.vue: expiración de sesión por 30 min de inactividad
    ├── services/school.js: operaciones de dominio y consultas Supabase
    └── lib/mappers.js / errors.js: adaptación de filas y errores
             │ HTTPS + publishable/anon key + JWT
             ▼
  Supabase Auth + PostgreSQL
    ├── 12 tablas, PK/FK, CHECK, índices y triggers
    ├── vistas v_* con RLS
    └── RPC admin_* SECURITY DEFINER con validación de rol
```

Vue Router controla la navegación visible; RLS y las RPC autorizan las operaciones en la base. El frontend nunca contiene `service_role`.

## 5. Modelo de datos

Tablas: `usuarios`, `alumnos`, `profesores`, `cursos`, `materias`, `asignaciones`, `inscripciones`, `calificaciones`, `asistencias`, `actividades`, `entregas_actividades` y `avisos`.

- **PK:** `id` UUID en cada entidad; `usuarios.id` coincide con `auth.users.id`.
- **Usuario–Alumno/Profesor:** 1 a 0..1 con `id_usuario` único.
- **Alumno–Curso:** N:M mediante `inscripciones`, con fecha/estado e historial; solo una activa.
- **Materia–Curso–Profesor:** N:M:N mediante `asignaciones`, incluyendo ciclo lectivo.
- **Alumno–Calificación / Alumno–Asistencia:** 1:N, sujetas a inscripción y asignación vigente.
- **Actividad–Alumno:** N:M mediante `entregas_actividades`.
- **Aviso:** autor FK a `usuarios`; curso destino opcional (NULL representa toda la institución).

Se normalizan datos personales en `usuarios`, se usan tablas puente para N:M, bajas lógicas para preservar historia y restricciones/triggers para mantener integridad fuera de la interfaz.

## 6. Tres fragmentos de código para explicar

### A. Guard de rutas · `src/router/index.js`

`router.beforeEach` inicializa Auth, lleva usuarios anónimos al login y comprueba `meta.roles`. Se relaciona con `stores/auth.js`, `SideMenu.vue` y las políticas RLS.

```js
await initAuth()
if (!session.user) return { name: 'login', query: { redirect: to.fullPath } }
if (to.meta.roles && !to.meta.roles.includes(session.user.role)) {
  return { name: 'access-denied' }
}
```

### B. Asistencia sin duplicados · `src/services/school.js`

`saveAttendance` usa upsert con la clave alumno/curso/materia/fecha. La validación de PostgreSQL comprueba inscripción, asignación y fecha no futura.

```js
db().from('asistencias').upsert(records, {
  onConflict: 'id_alumno,id_curso,id_materia,fecha',
})
```

### C. Alta segura de administrador · `supabase/migrations/20261115000200_admin_account_creation.sql`

`admin_crear_administrador` usa `SECURITY DEFINER`, verifica `es_admin()`, valida DNI/correo/contraseña, crea la cuenta Auth y perfil, y concede ejecución solo a `authenticated`. El frontend llama la RPC desde `createAdministrator` en `src/services/school.js`.

## 7. Dificultad técnica y solución

Al pasar de datos mock a Supabase, los permisos no podían depender solo de botones o menús: una llamada directa a la API podía intentar operar fuera del rol. Se implementaron RLS y RPC administrativas con validación en PostgreSQL. En revisión final se detectaron actualizaciones propias de perfil, baja docente sin comprobar asignaciones, contraseñas predeterminadas en RPC y fechas futuras; las migraciones 009/010, las validaciones de Vue y el timeout de sesión abordan esos casos. El comportamiento negativo post-migración se debe retestar en ambiente aislado.

## 8. Resultados frente a objetivos

- **Logrado:** centralización del registro académico, administración de cursos/personas, procesos docentes y consulta por alumno.
- **Logrado:** permisos por rol, historial de inscripciones, validaciones de integridad y altas de los tres perfiles.
- **Verificado:** build normal y clean-install build; acceso a los tres roles, filtros y formulario de administrador con validación vacía.
- **Pendiente de prueba:** CRUD con escrituras aisladas, cambios de curso, rechazos negativos de 009/010, correo real, mediciones de rendimiento, WCAG, 360 px, matriz de navegadores y restore.
- **V2:** RF20–RF23.

## 9. Preguntas para la defensa oral

1. **¿Por qué se separan Usuario, Alumno y Profesor?** Los datos personales viven una sola vez; los perfiles guardan atributos y permisos específicos.
2. **¿Qué resuelve Inscripción?** La relación N:M alumno–curso y el historial de cambios.
3. **¿Qué resuelve Asignación?** Vincula materia, curso, profesor y ciclo lectivo; define el alcance del docente.
4. **¿Por qué hay guardas y RLS?** La guarda mejora la navegación; RLS protege la base ante llamadas directas.
5. **¿Cómo evita duplicar asistencia?** Upsert por clave única alumno/curso/materia/fecha.
6. **¿Cómo se conserva el historial al dar de baja?** Baja lógica y finalización de inscripción, sin borrar registros académicos.
7. **¿Qué protege la RPC de alta de administrador?** Solo admin puede ejecutarla; valida datos/contraseña y no expone `service_role`.
8. **¿Cómo se evita una nota futura?** La interfaz limita el campo y el trigger SQL rechaza la operación directa.
9. **¿Se suben archivos en la entrega?** No; solo cambia el estado a “Entregada”.
10. **¿Qué falta para validar completamente?** Pruebas CRUD/negativas aisladas y métricas RNF; además configuración de SMTP/backup.

## 10. Revisión de la versión definitiva (16/11/2026)

- **Dependencia innecesaria eliminada:** `@supabase/ssr` figuraba en `package.json` pero no se importa en `src/`; se quitó con `npm uninstall`.
- **`.env.example` saneado:** contenía la URL y la publishable key de un proyecto real; ahora trae marcadores (`TU-PROYECTO`). El `.env` real sigue ignorado por git y no hay referencias a `service_role` en `src/`.
- **Script SQL:** se comprobó que `supabase/setup_completo.sql` contiene las 10 migraciones y el seed (solo difieren comentarios).
- **Instalación limpia:** `npm ci` + `npm run build` en una copia sin `node_modules` ni `.env`: correcto.
- **Documentación unificada** en `docs/` (PDFs de las etapas 1–4, DER, implementación, manual y Etapa 8) y enlaces del README actualizados.
- **Fuera del proyecto:** las carpetas `reportes-qa/` y `reportes-qa-ahorrapp/` pertenecen a otro sistema (Ahorrapp) y no deben incluirse en la entrega.

## 11. Correspondencia con la consigna de la Etapa Final

| Punto | Dónde está |
| --- | --- |
| 1. Revisión final y errores de Etapa 8 (ER01–ER05) | Sección 1 y `docs/Etapa8_Pruebas.pdf`; correcciones en migraciones 009/010 |
| 2. Versión definitiva y limpieza | Sección 10 |
| 3. Script SQL, RLS y datos ficticios | `supabase/setup_completo.sql`, `supabase/migrations/`, `supabase/seed.sql` |
| 4. Ejecución en otra computadora | Sección 2 y README |
| 5. Demostración | Sección 3 |
| 6. Presentación | `docs/PRESENTACION_ColegioGest.pptx` / `.pdf` |
| 7–8. Arquitectura y modelo de datos | Secciones 4 y 5, `docs/DER_ColegioGest.pdf`, `docs/ETAPA6.md` |
| 9–10. Operaciones, roles y permisos | Sección 3; cuentas en el README (contraseña `demo123`, solo demostración) |
| 11–12. Código relevante y dificultad técnica | Secciones 6 y 7 |
| 13. Resultados vs. objetivos | Sección 8 |
| 14. Defensa oral | Sección 9 |
| 15. Entrega | Sección 12 |

## 12. Archivos de entrega

- Código y configuración: `src/`, `package.json`, `package-lock.json`, `.env.example`, `index.html`, `vite.config.js`, `public/`.
- Base reproducible: `supabase/setup_completo.sql`, `supabase/migrations/` (001–010) y `supabase/seed.sql`.
- Documentación de las etapas: PDFs en `docs/` (Etapas 1–4, DER, implementación, manual de usuario, Etapa 8) y los `.md` técnicos.
- Presentación: `docs/PRESENTACION_ColegioGest.pptx` y `.pdf`.
- Esta guía: `docs/ETAPA_FINAL.md`.

**Reproducción:** `npm ci` → configurar `.env` → `npm run dev` o `npm run build`. No versionar `.env` ni credenciales privadas.
