# Análisis de datos · Etapa 3 → Etapa 6

Este documento reconstruye y documenta el modelo de datos de la Etapa 3 de **ColegioGest**, explica su normalización y registra las decisiones tomadas al llevarlo a un modelo físico en Supabase/PostgreSQL durante la Etapa 6.

## 1. Alcance

La Etapa 3 definió el dominio escolar con estas entidades:

- **Usuario**
- **Alumno**
- **Profesor**
- **Curso**
- **Materia**
- **Calificación**
- **Asistencia**
- **Actividad**
- **Aviso**
- **Inscripción**
- **Asignación**

La Etapa 6 conserva ese modelo conceptual y lo implementa con tablas normalizadas, claves, restricciones, índices, triggers, RLS y vistas de lectura. No se rediseñó la interfaz ni se cambió el stack Vue 3 + Vite.

## 2. Entidades, atributos y relaciones

### 2.1 Usuario

Persona con acceso al sistema. Concentra los datos personales que antes podían aparecer repetidos en distintas entidades.

| Atributo | Tipo | Obligatorio | Descripción |
| --- | --- | --- | --- |
| `id` | uuid | Sí | Identificador. Es el mismo `auth.users.id` de Supabase Auth. |
| `nombre` | text | Sí | Nombre de la persona. |
| `apellido` | text | Sí | Apellido. |
| `dni` | text | Sí | Documento, 7 a 9 dígitos, único. |
| `correo` | text | Sí | Correo de acceso, único sin distinguir mayúsculas. |
| `rol` | `rol_usuario` | Sí | `administrador`, `profesor` o `alumno`. |
| `estado` | `estado_cuenta` | Sí | `activo` o `inactivo`. Una cuenta inactiva no puede operar. |
| `fecha_alta` | timestamptz | Sí | Alta en el sistema. |
| `created_at`, `updated_at` | timestamptz | Sí | Auditoría básica. |

Relaciones: 1:1 con Alumno o Profesor; 1:N con Aviso como autor.

### 2.2 Alumno

Perfil académico del estudiante. **No repite** nombre, apellido, DNI ni correo: los obtiene de Usuario.

| Atributo | Tipo | Obligatorio | Descripción |
| --- | --- | --- | --- |
| `id` | uuid | Sí | Identificador del perfil. |
| `id_usuario` | uuid | Sí | FK única a `usuarios.id`. |
| `fecha_nacimiento` | date | No | Dato complementario. |
| `telefono` | text | No | Contacto. |
| `estado` | `estado_cuenta` | Sí | Se sincroniza con la baja lógica. |
| `created_at`, `updated_at` | timestamptz | Sí | Auditoría. |

Relaciones: 1:N con Inscripción, Calificación, Asistencia y Entrega.

### 2.3 Profesor

Perfil docente. Tampoco duplica datos personales.

| Atributo | Tipo | Obligatorio | Descripción |
| --- | --- | --- | --- |
| `id` | uuid | Sí | Identificador del perfil. |
| `id_usuario` | uuid | Sí | FK única a `usuarios.id`. |
| `estado` | `estado_cuenta` | Sí | Estado del perfil. |
| `created_at`, `updated_at` | timestamptz | Sí | Auditoría. |

Relaciones: 1:N con Asignación, Calificación, Asistencia y Actividad.

### 2.4 Curso

| Atributo | Tipo | Obligatorio | Descripción |
| --- | --- | --- | --- |
| `id` | uuid | Sí | Identificador. |
| `anio` | smallint | Sí | Año o grado, 1 a 12. |
| `division` | varchar(10) | Sí | División, por ejemplo `A`. |
| `turno` | text | No | `mañana`, `tarde` o `noche`. |
| `created_at`, `updated_at` | timestamptz | Sí | Auditoría. |

Unicidad funcional: `(anio, division, turno)`.

### 2.5 Materia

| Atributo | Tipo | Obligatorio | Descripción |
| --- | --- | --- | --- |
| `id` | uuid | Sí | Identificador. |
| `nombre` | text | Sí | Nombre único sin distinguir mayúsculas. |
| `descripcion` | text | No | Descripción. |
| `created_at`, `updated_at` | timestamptz | Sí | Auditoría. |

La materia es un catálogo independiente: una misma materia puede dictarse en varios cursos y por varios docentes.

### 2.6 Asignación

Resuelve la relación **N:M:N** entre Materia, Curso y Profesor para un ciclo lectivo. Es la base de los permisos del docente.

| Atributo | Tipo | Obligatorio | Descripción |
| --- | --- | --- | --- |
| `id` | uuid | Sí | Identificador. |
| `id_materia` | uuid | Sí | FK a `materias.id`. |
| `id_curso` | uuid | Sí | FK a `cursos.id`. |
| `id_profesor` | uuid | Sí | FK a `profesores.id`. |
| `anio_lectivo` | smallint | Sí | Ciclo, 2000 a 2100. |
| `created_at`, `updated_at` | timestamptz | Sí | Auditoría. |

Unicidad: `(id_materia, id_curso, id_profesor, anio_lectivo)`.

### 2.7 Inscripción

Resuelve la relación **N:M** entre Alumno y Curso y conserva el historial.

| Atributo | Tipo | Obligatorio | Descripción |
| --- | --- | --- | --- |
| `id` | uuid | Sí | Identificador. |
| `id_alumno` | uuid | Sí | FK a `alumnos.id`. |
| `id_curso` | uuid | Sí | FK a `cursos.id`. |
| `fecha_inscripcion` | date | Sí | Fecha del movimiento. |
| `estado` | `estado_inscripcion` | Sí | `activa` o `finalizada`. |
| `created_at`, `updated_at` | timestamptz | Sí | Auditoría. |

Regla: un alumno solo puede tener **una inscripción activa** a la vez (índice único parcial). Cambiar de curso finaliza la anterior y crea una nueva.

### 2.8 Calificación

| Atributo | Tipo | Obligatorio | Descripción |
| --- | --- | --- | --- |
| `id` | uuid | Sí | Identificador. |
| `id_alumno` | uuid | Sí | FK a `alumnos.id`. |
| `id_materia` | uuid | Sí | FK a `materias.id`. |
| `id_profesor` | uuid | Sí | FK a `profesores.id`. |
| `tipo_instancia` | text | Sí | Por ejemplo “Trabajo práctico 1”. |
| `nota` | numeric(4,2) | Sí | Escala de 1 a 10. |
| `fecha` | date | Sí | Fecha de la evaluación. |
| `observacion` | text | No | Comentario. |
| `created_at`, `updated_at` | timestamptz | Sí | Auditoría. |

Regla de integridad: la combinación alumno + materia + profesor debe corresponder a una inscripción activa y a una asignación vigente.

### 2.9 Asistencia

| Atributo | Tipo | Obligatorio | Descripción |
| --- | --- | --- | --- |
| `id` | uuid | Sí | Identificador. |
| `id_alumno` | uuid | Sí | FK a `alumnos.id`. |
| `id_curso` | uuid | Sí | FK a `cursos.id`. |
| `id_materia` | uuid | Sí | FK a `materias.id`. |
| `id_profesor` | uuid | Sí | FK a `profesores.id`. |
| `fecha` | date | Sí | Día registrado. |
| `estado` | `estado_asistencia` | Sí | `presente`, `ausente`, `tardanza` o `justificada`. |
| `observacion` | text | No | Comentario. |
| `created_at`, `updated_at` | timestamptz | Sí | Auditoría. |

Unicidad: `(id_alumno, id_curso, id_materia, fecha)`, lo que permite hacer *upsert* al guardar la asistencia del día.

### 2.10 Actividad

| Atributo | Tipo | Obligatorio | Descripción |
| --- | --- | --- | --- |
| `id` | uuid | Sí | Identificador. |
| `titulo` | text | Sí | Título. |
| `descripcion` | text | Sí | Consigna. |
| `fecha_entrega` | date | Sí | Fecha límite. |
| `id_materia` | uuid | Sí | FK a `materias.id`. |
| `id_curso` | uuid | Sí | FK a `cursos.id`. |
| `id_profesor` | uuid | Sí | FK a `profesores.id`. |
| `fecha_publicacion` | timestamptz | Sí | Momento de publicación. |
| `created_at`, `updated_at` | timestamptz | Sí | Auditoría. |

### 2.11 Entrega de actividad (agregada en Etapa 6)

La Etapa 5 ya ofrecía la acción **“Marcar entregada”**. Para no perder esa funcionalidad al eliminar los datos mock, se agregó una entidad técnica:

| Atributo | Tipo | Obligatorio | Descripción |
| --- | --- | --- | --- |
| `id` | uuid | Sí | Identificador. |
| `id_actividad` | uuid | Sí | FK a `actividades.id`. |
| `id_alumno` | uuid | Sí | FK a `alumnos.id`. |
| `estado` | `estado_entrega` | Sí | `pendiente` o `entregada`. |
| `fecha_entrega` | timestamptz | Sí | Momento de la entrega. |
| `comentario` | text | No | Comentario opcional. |
| `created_at`, `updated_at` | timestamptz | Sí | Auditoría. |

Unicidad: `(id_actividad, id_alumno)`.

### 2.12 Aviso

| Atributo | Tipo | Obligatorio | Descripción |
| --- | --- | --- | --- |
| `id` | uuid | Sí | Identificador. |
| `titulo` | text | Sí | Título. |
| `contenido` | text | Sí | Cuerpo del aviso. |
| `categoria` | `categoria_aviso` | Sí | `institucional`, `academico` o `evento`. |
| `fecha_publicacion` | timestamptz | Sí | Fecha de publicación. |
| `id_autor` | uuid | Sí | FK a `usuarios.id`. |
| `id_curso_destino` | uuid | No | FK a `cursos.id`; `null` = toda la comunidad. |
| `created_at`, `updated_at` | timestamptz | Sí | Auditoría. |

## 3. Relaciones y cardinalidades

| Relación | Cardinalidad | Resolución |
| --- | --- | --- |
| Usuario – Alumno | 1 : 0..1 | `alumnos.id_usuario` único |
| Usuario – Profesor | 1 : 0..1 | `profesores.id_usuario` único |
| Alumno – Curso | N : M | `inscripciones` |
| Materia – Curso – Profesor | N : M : N | `asignaciones` |
| Alumno – Calificación | 1 : N | `calificaciones.id_alumno` |
| Alumno – Asistencia | 1 : N | `asistencias.id_alumno` |
| Profesor – Actividad | 1 : N | `actividades.id_profesor` |
| Actividad – Alumno | N : M | `entregas_actividades` |
| Usuario – Aviso | 1 : N | `avisos.id_autor` |
| Curso – Aviso | 1 : N opcional | `avisos.id_curso_destino` |

## 4. Reglas de negocio

1. Una cuenta inactiva no puede iniciar sesión ni consultar datos.
2. El rol se obtiene de `usuarios.rol`, nunca de datos enviados por el cliente.
3. Un alumno solo puede tener una inscripción activa.
4. Solo se puede calificar o registrar asistencia si el alumno está inscripto y el docente tiene una asignación vigente para esa materia y curso.
5. Un docente solo publica actividades para sus asignaciones.
6. Un alumno solo marca entregada una actividad de su propio curso.
7. Los avisos sin curso destino son visibles para toda la comunidad; con curso destino, solo para ese curso.
8. Las bajas de alumnos son lógicas (`estado = 'inactivo'`), para conservar el historial académico.
9. No se puede eliminar una asignación con historial de calificaciones, asistencias o actividades.
10. El propio usuario no puede cambiar su rol ni su estado; solo un administrador puede hacerlo.

## 5. Normalización

- **Datos personales únicos**: `nombre`, `apellido`, `dni` y `correo` viven solo en `usuarios`. `alumnos` y `profesores` son perfiles 1:1.
- **Catálogos separados**: `cursos` y `materias` no repiten datos dentro de cada asignación o actividad.
- **Relaciones N:M explícitas**: `inscripciones` y `asignaciones` evitan arrays o campos repetidos.
- **Sin dependencias transitivas**: el curso de un alumno se obtiene por su inscripción activa; no se guarda `id_curso` en `alumnos`.
- **Atomicidad**: no hay columnas con listas de materias, cursos o alumnos.
- **Integridad referencial**: todas las relaciones usan FK con `on delete` explícito (`cascade` para perfiles e historial, `restrict` para catálogos con historial).

## 6. Problemas del modelo anterior basado en datos mock

Antes de la Etapa 6, la aplicación funcionaba con `src/data/mockData.js` y `demoStore.js`. Ese esquema tenía limitaciones:

- Los datos vivían en memoria y se perdían al recargar.
- No existía autenticación real ni control de permisos.
- La información personal podía aparecer repetida en distintos objetos.
- Las relaciones se resolvían por nombres o ids sueltos, sin claves foráneas.
- No había validaciones de integridad ni historial.
- Los cambios de estado y las bajas no quedaban auditados.

La Etapa 6 reemplaza ese esquema por tablas normalizadas y elimina por completo `src/data`.

## 7. Cambios respecto de la Etapa 3

| Cambio | Motivo |
| --- | --- |
| `usuarios` como espejo de `auth.users` | Vincular autenticación real con el rol de negocio. |
| `alumnos` y `profesores` solo con `id_usuario` y datos de perfil | Evitar duplicación de datos personales. |
| `inscripciones` con historial y estado | Resolver N:M y permitir cambios de curso sin perder historial. |
| `asignaciones` con `anio_lectivo` | Soportar varios ciclos y habilitar permisos docentes por materia/curso. |
| Entidad `entregas_actividades` | Conservar la funcionalidad “Marcar entregada” de la Etapa 5. |
| Enumeraciones (`rol_usuario`, `estado_cuenta`, `estado_inscripcion`, `estado_asistencia`, `categoria_aviso`, `estado_entrega`) | Evitar valores inválidos. |
| Timestamps `created_at`, `updated_at`, `fecha_alta` | Auditoría mínima. |
| Baja lógica de alumnos y cuentas | Conservar historial académico. |
| Restricciones de unicidad y `CHECK` | Evitar DNI/correos duplicados, notas fuera de rango, cursos inválidos. |
| Triggers de integridad académica | Validar que las operaciones respeten inscripciones y asignaciones. |
| RLS y RPC administrativas | Aplicar permisos en la base y no solo en Vue. |

## 8. Trazabilidad modelo conceptual → modelo físico

| Etapa 3 | Etapa 6 |
| --- | --- |
| Usuario | `public.usuarios` |
| Alumno | `public.alumnos` |
| Profesor | `public.profesores` |
| Curso | `public.cursos` |
| Materia | `public.materias` |
| Calificación | `public.calificaciones` |
| Asistencia | `public.asistencias` |
| Actividad | `public.actividades` |
| Aviso | `public.avisos` |
| Inscripción | `public.inscripciones` |
| Asignación | `public.asignaciones` |
| “Marcar entregada” (UI Etapa 5) | `public.entregas_actividades` |

El DER se elabora de forma manual a partir de este análisis y del esquema descrito en [`docs/ETAPA6.md`](./ETAPA6.md).
