"""Generate an editable Open XML PowerPoint deck (Python stdlib + Pillow)."""
from __future__ import annotations

from html import escape
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "PRESENTACION_ColegioGest.pptx"
MEDIA = ROOT / "docs" / "capturas-manual"
EMU = 914400
SW, SH = 13.333333 * EMU, 7.5 * EMU
P_NS = "http://schemas.openxmlformats.org/presentationml/2006/main"
A_NS = "http://schemas.openxmlformats.org/drawingml/2006/main"
R_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
CT_NS = "http://schemas.openxmlformats.org/package/2006/content-types"

ET.register_namespace("p", P_NS)
ET.register_namespace("a", A_NS)
ET.register_namespace("r", R_NS)


def emu(inches: float) -> int:
    return int(inches * EMU)


def esc(value: str) -> str:
    return escape(value, quote=False)


def group_tree() -> str:
    return (
        '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
        '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
        '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
    )


class Slide:
    def __init__(self, number: int, background: str = "F7FAFC"):
        self.number = number
        self.background = background
        self.parts: list[str] = []
        self.rels = [
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>'
        ]
        self.image_count = 0
        self.shape_id = 2

    def add_text(
        self,
        text: str,
        x: float,
        y: float,
        w: float,
        h: float,
        *,
        size: int = 18,
        color: str = "243746",
        bold: bool = False,
        fill: str | None = None,
        align: str = "l",
        valign: str = "t",
        font: str = "Aptos",
        margin: float = 0.06,
        shape: str = "rect",
    ):
        ident = self.shape_id
        self.shape_id += 1
        fill_xml = f'<a:solidFill><a:srgbClr val="{fill}"/></a:solidFill>' if fill else "<a:noFill/>"
        line_xml = '<a:ln><a:solidFill><a:srgbClr val="D7E2EB"/></a:solidFill></a:ln>' if fill else "<a:ln><a:noFill/></a:ln>"
        text_paras = []
        for line in text.split("\n"):
            text_paras.append(
                f'<a:p><a:pPr algn="{align}"/><a:r><a:rPr lang="es-AR" sz="{size*100}" b="{1 if bold else 0}">'
                f'<a:solidFill><a:srgbClr val="{color}"/></a:solidFill><a:latin typeface="{font}"/></a:rPr>'
                f'<a:t xml:space="preserve">{esc(line)}</a:t></a:r><a:endParaRPr lang="es-AR" sz="{size*100}"/></a:p>'
            )
        self.parts.append(
            f'<p:sp><p:nvSpPr><p:cNvPr id="{ident}" name="Text {ident}"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>'
            f'<p:spPr><a:xfrm><a:off x="{emu(x)}" y="{emu(y)}"/><a:ext cx="{emu(w)}" cy="{emu(h)}"/></a:xfrm>'
            f'<a:prstGeom prst="{shape}"><a:avLst/></a:prstGeom>{fill_xml}{line_xml}</p:spPr>'
            f'<p:txBody><a:bodyPr wrap="square" lIns="{emu(margin)}" rIns="{emu(margin)}" tIns="{emu(margin)}" bIns="{emu(margin)}" anchor="{valign}"><a:noAutofit/></a:bodyPr><a:lstStyle/>'
            + "".join(text_paras)
            + "</p:txBody></p:sp>"
        )

    def add_image(self, file: Path, x: float, y: float, w: float, h: float, media_name: str | None = None):
        from PIL import Image

        ident = self.shape_id
        self.shape_id += 1
        self.image_count += 1
        rid = f"rId{self.image_count + 1}"
        name = media_name or f"slide{self.number}_image{self.image_count}.png"
        IMAGE_SOURCES[name] = file
        with Image.open(file) as image:
            iw, ih = image.size
        ratio = min(w / iw, h / ih)
        out_w, out_h = iw * ratio, ih * ratio
        off_x = x + (w - out_w) / 2
        off_y = y + (h - out_h) / 2
        self.rels.append(
            f'<Relationship Id="{rid}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/{name}"/>'
        )
        self.parts.append(
            f'<p:pic><p:nvPicPr><p:cNvPr id="{ident}" name="{esc(name)}"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>'
            f'<p:blipFill><a:blip r:embed="{rid}"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>'
            f'<p:spPr><a:xfrm><a:off x="{emu(off_x)}" y="{emu(off_y)}"/><a:ext cx="{emu(out_w)}" cy="{emu(out_h)}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>'
        )
        return name

    def xml(self) -> str:
        bg = f'<p:bg><p:bgPr><a:solidFill><a:srgbClr val="{self.background}"/></a:solidFill><a:effectLst/></p:bgPr></p:bg>'
        return (
            f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            f'<p:sld xmlns:a="{A_NS}" xmlns:r="{R_NS}" xmlns:p="{P_NS}"><p:cSld>{bg}<p:spTree>'
            + group_tree()
            + "".join(self.parts)
            + '</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>'
        )

    def rels_xml(self) -> str:
        return f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="{REL_NS}">' + "".join(self.rels) + "</Relationships>"


slides: list[Slide] = []
IMAGE_SOURCES: dict[str, Path] = {}


def add_slide(title: str, subtitle: str = "", bg: str = "F7FAFC") -> Slide:
    slide = Slide(len(slides) + 1, bg)
    if title:
        slide.add_text(title.upper(), 0.55, 0.35, 12.2, 0.25, size=10, color="20547F", bold=True)
        if subtitle:
            slide.add_text(subtitle, 0.55, 0.82, 12.2, 0.58, size=28, color="102A43", bold=True)
    slide.add_text(f"ColegioGest · Presentación final", 0.55, 7.12, 10.8, 0.18, size=8, color="8191A0")
    slide.add_text(f"{len(slides)+1:02d} / 12", 11.8, 7.12, 0.9, 0.18, size=8, color="8191A0", align="r")
    slides.append(slide)
    return slide


def textbox(slide: Slide, text: str, x: float, y: float, w: float, h: float, **kwargs):
    slide.add_text(text, x, y, w, h, **kwargs)


# 1 — Cover
s = Slide(1, "123B5A")
s.add_text("PROYECTO INTEGRADOR · PDISWD", .75, .55, 7.2, .35, size=12, color="BBDDF5", bold=True)
s.add_text("SISTEMA DE GESTIÓN ESCOLAR", .75, 1.7, 8.3, .45, size=18, color="E2F1FC", bold=True)
s.add_text("ColegioGest", .75, 2.25, 10.8, 1.0, size=48, color="FFFFFF", bold=True)
s.add_text("Una plataforma para centralizar la información académica y facilitar el trabajo de administración, docentes y alumnos.", .8, 3.55, 8.9, 1.0, size=21, color="E1EEF7")
s.add_text("Vue 3   ·   Vue Router   ·   Supabase Auth   ·   PostgreSQL + RLS", .8, 5.25, 9.5, .45, size=16, color="FFFFFF", bold=True, fill="20547F", shape="roundRect")
s.add_text("Presentación final · 15 de noviembre de 2026", .8, 6.65, 8.0, .35, size=11, color="C5D9E9")
slides.append(s)

# 2 — Problem and objectives
s = add_slide("01 · Problema y objetivos", "¿Qué necesidad resuelve?")
textbox(s, "La información escolar dispersa en planillas y documentos genera duplicados, errores, demoras y riesgo de pérdida.", .65, 1.65, 5.4, 1.05, size=22, color="33495B")
for i, (head, body) in enumerate([
    ("Centralizar", "Personas, cursos, materias y actividad académica en un solo sistema."),
    ("Organizar", "Conservar inscripciones y registros sin perder historial."),
    ("Proteger", "Mostrar a cada rol solo la información que le corresponde."),
    ("Facilitar", "Consultar notas, asistencias, tareas y avisos desde web."),
]):
    x = 6.45 + (i % 2) * 3.1
    y = 1.72 + (i // 2) * 1.75
    textbox(s, head, x, y, 2.8, .38, size=18, color="102A43", bold=True, fill="EAF2F9", shape="roundRect")
    textbox(s, body, x, y+.45, 2.8, .95, size=14, color="536779")
textbox(s, "3 roles coordinados: Administrador · Profesor · Alumno", 1.0, 5.65, 10.8, .62, size=20, color="20547F", bold=True, fill="EAF2F9", shape="roundRect")

# 3 — Roles
s = add_slide("02 · Usuarios", "Un espacio para cada perfil")
cards = [
    ("Administrador", "Gestiona alumnos, profesores, usuarios, cursos, materias, asignaciones e inscripciones. Supervisa notas, actividades y avisos."),
    ("Profesor", "Consulta cursos y alumnos asignados; registra asistencia y calificaciones; publica actividades y avisos."),
    ("Alumno", "Consulta sus datos, materias, notas, asistencias, actividades y avisos. No edita sus registros académicos."),
]
for i, (head, body) in enumerate(cards):
    x = .7 + i*4.15
    textbox(s, head, x, 2.05, 3.75, .55, size=22, color="102A43", bold=True, fill="EAF2F9", shape="roundRect")
    textbox(s, body, x+.08, 2.78, 3.55, 1.65, size=16, color="526779")
    textbox(s, ["Gestión institucional", "Trabajo docente", "Consulta personal"][i], x+.08, 4.7, 3.5, .35, size=13, color="20547F", bold=True)
textbox(s, "Autorización en dos capas: menú y rutas en Vue Router + políticas RLS en PostgreSQL.", .8, 5.85, 11.5, .65, size=18, color="176B48", bold=True, fill="EDF8F2", shape="roundRect")

# 4 — Features
s = add_slide("03 · Funcionalidades", "De la administración a la consulta")
textbox(s, "ADMINISTRACIÓN", .75, 1.7, 5.5, .45, size=18, color="20547F", bold=True)
textbox(s, "• CRUD de alumnos y profesores\n• Cursos, materias y asignaciones\n• Inscripciones con historial\n• Usuarios, roles y avisos", .85, 2.25, 5.4, 2.4, size=17, color="283C4D", fill="F4F8FB", shape="roundRect")
textbox(s, "DOCENCIA Y ALUMNADO", 6.95, 1.7, 5.5, .45, size=18, color="20547F", bold=True)
textbox(s, "• Asistencia por curso, materia y fecha\n• Calificaciones 1–10\n• Actividades y estado de entrega\n• Consulta de notas y asistencias propias", 7.05, 2.25, 5.3, 2.4, size=17, color="283C4D", fill="F4F8FB", shape="roundRect")
textbox(s, "La entrega registra el estado “Entregada”; no incluye carga de archivos. La recuperación por correo depende de SMTP/Redirect URL.", .8, 5.35, 11.8, .75, size=14, color="8A5A00", fill="FFF6E6", shape="roundRect")

# 5 — Architecture
s = add_slide("04 · Arquitectura", "Vue organiza la experiencia; Supabase protege los datos")
textbox(s, "Vue 3 · Vite SPA", 4.5, 1.65, 4.3, .55, size=20, color="FFFFFF", bold=True, fill="20547F", shape="roundRect", align="ctr")
for i, text in enumerate(["Vue Router\nrutas por rol", "Views + Components\npantallas", "Stores\nsesión y avisos"]):
    textbox(s, text, .8+i*4.15, 2.55, 3.5, .8, size=15, color="102A43", bold=True, fill="EAF2F9", shape="roundRect", align="ctr")
textbox(s, "↓", 5.8, 3.35, 1.4, .4, size=25, color="7199B7", bold=True, align="ctr")
textbox(s, "Services / school.js · consultas, CRUD y RPC", 3.2, 3.8, 6.9, .55, size=17, color="102A43", bold=True, fill="F4F8FB", shape="roundRect", align="ctr")
textbox(s, "↓ HTTPS · publishable/anon key · JWT", 3.7, 4.45, 6.0, .4, size=13, color="536779", bold=True, align="ctr")
for i, text in enumerate(["Supabase Auth", "PostgreSQL + RLS", "Vistas + RPC + triggers"]):
    textbox(s, text, .8+i*4.15, 5.0, 3.5, .65, size=16, color="FFFFFF", bold=True, fill="123B5A", shape="roundRect", align="ctr")
textbox(s, "No se usa service_role en el navegador.", 4.0, 6.0, 5.4, .35, size=14, color="176B48", bold=True, align="ctr")

# 6 — Data model
s = add_slide("05 · Base de datos", "Entidades y relaciones principales")
model = [
    ("usuarios", "1:0..1", "alumnos · profesores"),
    ("inscripciones", "N:M", "alumnos ↔ cursos"),
    ("asignaciones", "N:M:N", "materias · cursos · profesores"),
    ("actividades", "1:N", "entregas_actividades ↔ alumnos"),
]
for i, (name, card, detail) in enumerate(model):
    y = 1.65 + i*1.0
    textbox(s, name, .8, y, 2.6, .55, size=17, color="FFFFFF", bold=True, fill="20547F", shape="roundRect", align="ctr")
    textbox(s, card, 3.65, y, 1.35, .55, size=15, color="176B48", bold=True, align="ctr")
    textbox(s, detail, 5.1, y, 3.6, .55, size=15, color="283C4D", fill="EAF2F9", shape="roundRect", align="ctr")
textbox(s, "También: calificaciones, asistencias y avisos.", 8.95, 1.65, 3.5, .55, size=15, color="102A43", bold=True)
textbox(s, "12 tablas principales\nUUID como PK\nFK explícitas\nCHECK + índices únicos\nBaja lógica + auditoría", 9.0, 2.35, 3.45, 2.55, size=17, color="283C4D", fill="F4F8FB", shape="roundRect")
textbox(s, "Decisión clave: datos personales centralizados en usuarios; tablas puente conservan historial y relaciones N:M.", .85, 6.0, 11.7, .65, size=15, color="20547F", bold=True, fill="EAF2F9", shape="roundRect")

# 7 — Security
s = add_slide("06 · Seguridad", "Seguridad aplicada en varias capas")
sec_cards = [
    ("Autenticación", "Supabase Auth, perfil por usuario, cuenta inactiva bloqueada y logout por 30 minutos de inactividad."),
    ("RLS", "El alumno consulta lo propio; el profesor opera en asignaciones; el administrador gestiona la institución."),
    ("Reglas", "Nota 1–10, inscripción activa, asistencia válida, sin fechas futuras y sin duplicados."),
    ("Hardening 009–010", "Perfiles propios protegidos, docente asignado no se desactiva, altas sin contraseña default y alta admin restringida."),
]
for i,(head,body) in enumerate(sec_cards):
    x=.7+(i%2)*6.15; y=1.65+(i//2)*1.9
    textbox(s,head,x,y,5.7,.5,size=18,color="102A43",bold=True,fill="EAF2F9",shape="roundRect")
    textbox(s,body,x+.08,y+.62,5.55,.95,size=15,color="4A6172")
textbox(s,"Las migraciones 001–010 están aplicadas. Las pruebas negativas que requieren escritura deben repetirse en ambiente aislado.",.8,5.85,11.8,.7,size=14,color="8A5A00",fill="FFF6E6",shape="roundRect")

# 8 — screens
s = add_slide("07 · Pantallas", "La información adecuada en cada pantalla")
s.add_text("Panel administrativo",.65,1.3,5.8,.4,size=17,color="102A43",bold=True)
s.add_text("Indicadores y accesos rápidos a alumnos, cursos e inscripciones.",.65,1.75,5.8,.55,size=12,color="536779")
s.add_image(MEDIA/"manual-panel-admin.png",.8,2.25,4.2,4.3)
s.add_text("Registro docente",6.8,1.3,5.8,.4,size=17,color="102A43",bold=True)
s.add_text("Selección de curso, materia y fecha; búsqueda de alumnos y estados.",6.8,1.75,5.7,.55,size=12,color="536779")
s.add_image(MEDIA/"asistencia-filtros.png",7.6,2.25,3.0,4.3)
s.add_text("Capturas de demostración; identidades ocultas.",8.0,6.65,4.3,.25,size=9,color="8191A0",align="ctr")

# 9 — demonstration
s = add_slide("08 · Demostración", "Un flujo de punta a punta")
for i,(head,body) in enumerate([
    ("1 · Administrador", "Crear/habilitar alumno, inscribirlo y asignar curso, materia y profesor."),
    ("2 · Profesor", "Tomar asistencia, cargar nota y publicar actividad y aviso."),
    ("3 · Alumno", "Consultar notas/asistencia, leer avisos y marcar actividad entregada."),
]):
    x=.7+i*4.15
    textbox(s,head,x,2.0,3.8,.55,size=18,color="FFFFFF",bold=True,fill="20547F",shape="roundRect",align="ctr")
    textbox(s,body,x+.1,2.85,3.55,1.45,size=16,color="283C4D",fill="F4F8FB",shape="roundRect")
s.add_text("Usar datos ficticios y cuentas autorizadas. No realizar escrituras sobre datos reales durante la defensa.",.9,5.15,11.5,.9,size=18,color="8A5A00",bold=True,fill="FFF6E6",shape="roundRect")

# 10 — Code examples
s = add_slide("09 · Código", "Tres decisiones de implementación")
snippets = [
    ("Vue Router · src/router/index.js", "if (!session.user) return { name: 'login' }\nif (to.meta.roles && !to.meta.roles.includes(session.user.role))\n  return { name: 'access-denied' }"),
    ("Supabase · src/services/school.js", "from('asistencias').upsert(records, {\n  onConflict: 'id_alumno,id_curso,id_materia,fecha'\n})"),
    ("PostgreSQL · migración 009", "using (cuenta_activa()\n  and es_admin()\n  and id <> auth.uid())"),
]
for i,(head,code) in enumerate(snippets):
    x=.55+i*4.25
    textbox(s,head,x,1.6,4.0,.6,size=15,color="102A43",bold=True,fill="EAF2F9",shape="roundRect")
    textbox(s,code,x,2.35,4.0,2.3,size=12,color="DCEAF5",fill="122A40",shape="roundRect",font="Consolas",margin=.18)
textbox(s,"El guard orienta navegación; RLS y triggers son la protección autoritativa. El cliente nunca usa service_role.",.8,5.55,11.8,.75,size=15,color="20547F",bold=True,fill="F4F8FB",shape="roundRect")

# 11 — challenges and results
s = add_slide("10 · Dificultades y resultados", "Qué se resolvió y qué falta medir")
s.add_text("Dificultades y soluciones",.7,1.55,5.7,.45,size=18,color="102A43",bold=True)
s.add_text("• Mock sin persistencia → PostgreSQL + seed\n• Permisos solo en UI → RLS + RPC + triggers\n• Perfil propio modificable → migración 009\n• Baja docente sin guarda → asignaciones vigentes\n• Fechas futuras/password por defecto → validación UI/BD\n• Alta admin faltante → migración 010",.8,2.15,5.6,3.1,size=15,color="283C4D",fill="EDF8F1",shape="roundRect")
s.add_text("Resultados y pendientes",6.9,1.55,5.7,.45,size=18,color="102A43",bold=True)
s.add_text("• Build aprobado; instalación limpia npm ci\n• Migraciones 001–010 aplicadas\n• Acceso de tres roles y flujos de integración documentados\n• Pendiente CRUD/negativos en entorno aislado\n• SMTP, rendimiento, WCAG, 360 px, navegadores y restore sin medición\n• RF20–RF23 quedan en V2",7.0,2.15,5.55,3.1,size=15,color="283C4D",fill="FFF6E6",shape="roundRect")

# 12 — close
s = Slide(12,"123B5A")
s.add_text("CIERRE · COLEGIOGEST",.7,.55,8,.35,size=12,color="BBDDF5",bold=True)
s.add_text("Una base segura para\nseguir creciendo",.7,1.55,7.3,1.5,size=36,color="FFFFFF",bold=True)
s.add_text("La versión actual resuelve la gestión académica central y separa el acceso por rol.",.75,3.35,6.7,1.0,size=19,color="E1EEF7")
s.add_text("Mejoras futuras\nRF20 · Reportes PDF/Excel\nRF21 · Notificaciones por correo\nRF22 · Boletín automático\nRF23 · Acceso para tutores",8.0,1.8,4.3,3.1,size=18,color="FFFFFF",bold=False,fill="20547F",shape="roundRect")
s.add_text("Defender: distinguir evidencia ejecutada, pruebas históricas y pendientes. Gracias.",.8,6.05,11.8,.65,size=18,color="FFFFFF",bold=True,fill="20547F",shape="roundRect")
slides.append(s)


def presentation_xml() -> str:
    ids = "".join(f'<p:sldId id="{256+i}" r:id="rId{i+2}"/>' for i in range(len(slides)))
    return (
        f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        f'<p:presentation xmlns:a="{A_NS}" xmlns:r="{R_NS}" xmlns:p="{P_NS}">'
        '<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>'
        f'<p:sldIdLst>{ids}</p:sldIdLst><p:sldSz cx="12192000" cy="6858000" type="screen16x9"/>'
        '<p:notesSz cx="6858000" cy="9144000"/><p:defaultTextStyle/></p:presentation>'
    )


def presentation_rels() -> str:
    rels = ['<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>']
    rels.extend(f'<Relationship Id="rId{i+2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide{i+1}.xml"/>' for i in range(len(slides)))
    return f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="{REL_NS}">' + "".join(rels) + "</Relationships>"


def master_xml() -> str:
    return (
        f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        f'<p:sldMaster xmlns:a="{A_NS}" xmlns:r="{R_NS}" xmlns:p="{P_NS}"><p:cSld><p:spTree>{group_tree()}</p:spTree></p:cSld>'
        '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>'
        '<p:sldLayoutIdLst><p:sldLayoutId id="1" r:id="rId1"/></p:sldLayoutIdLst><p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles></p:sldMaster>'
    )


def layout_xml() -> str:
    return (
        f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        f'<p:sldLayout xmlns:a="{A_NS}" xmlns:r="{R_NS}" xmlns:p="{P_NS}" type="blank" preserve="1">'
        f'<p:cSld name="Blank"><p:spTree>{group_tree()}</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>'
    )


def theme_xml() -> str:
    return f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="{A_NS}" name="ColegioGest">
 <a:themeElements>
  <a:clrScheme name="ColegioGest"><a:dk1><a:srgbClr val="102A43"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1><a:dk2><a:srgbClr val="243746"/></a:dk2><a:lt2><a:srgbClr val="F7FAFC"/></a:lt2><a:accent1><a:srgbClr val="20547F"/></a:accent1><a:accent2><a:srgbClr val="1B744D"/></a:accent2><a:accent3><a:srgbClr val="E7A323"/></a:accent3><a:accent4><a:srgbClr val="9B3030"/></a:accent4><a:accent5><a:srgbClr val="7894AB"/></a:accent5><a:accent6><a:srgbClr val="D7E2EB"/></a:accent6><a:hlink><a:srgbClr val="20547F"/></a:hlink><a:folHlink><a:srgbClr val="714F8E"/></a:folHlink></a:clrScheme>
  <a:fontScheme name="ColegioGest"><a:majorFont><a:latin typeface="Aptos Display"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont><a:minorFont><a:latin typeface="Aptos"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont></a:fontScheme>
  <a:fmtScheme name="ColegioGest"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"><a:alpha val="95000"/></a:schemeClr></a:solidFill><a:solidFill><a:schemeClr val="phClr"><a:alpha val="90000"/></a:schemeClr></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln><a:ln w="19050"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln><a:ln w="25400"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"><a:alpha val="95000"/></a:schemeClr></a:solidFill><a:solidFill><a:schemeClr val="phClr"><a:alpha val="90000"/></a:schemeClr></a:solidFill></a:bgFillStyleLst></a:fmtScheme>
 </a:themeElements>
</a:theme>'''


content_types = [
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
    '<Default Extension="xml" ContentType="application/xml"/>',
    '<Default Extension="png" ContentType="image/png"/>',
    '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>',
    '<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>',
    '<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>',
    '<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>',
    '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>',
    '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>',
]
content_types.extend(f'<Override PartName="/ppt/slides/slide{i}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>' for i in range(1, len(slides)+1))

root_rels = f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="{REL_NS}"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>'''
master_rels = f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="{REL_NS}"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/></Relationships>'''
layout_rels = f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="{REL_NS}"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>'''
core_props = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:title>ColegioGest · Presentación final</dc:title><dc:subject>Proyecto integrador PDISWD</dc:subject><dc:creator>ColegioGest</dc:creator></cp:coreProperties>'''
app_props = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"><Application>ColegioGest presentation generator</Application><PresentationFormat>On-screen Show (16:9)</PresentationFormat><Slides>12</Slides></Properties>'''


def main():
    from PIL import Image

    # Validate all XML fragments before packaging.
    parts: dict[str, str] = {
        "[Content_Types].xml": f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="{CT_NS}">' + "".join(content_types) + "</Types>",
        "_rels/.rels": root_rels,
        "ppt/presentation.xml": presentation_xml(),
        "ppt/_rels/presentation.xml.rels": presentation_rels(),
        "ppt/slideMasters/slideMaster1.xml": master_xml(),
        "ppt/slideMasters/_rels/slideMaster1.xml.rels": master_rels,
        "ppt/slideLayouts/slideLayout1.xml": layout_xml(),
        "ppt/slideLayouts/_rels/slideLayout1.xml.rels": layout_rels,
        "ppt/theme/theme1.xml": theme_xml(),
        "docProps/core.xml": core_props,
        "docProps/app.xml": app_props,
    }
    for i, slide in enumerate(slides, start=1):
        parts[f"ppt/slides/slide{i}.xml"] = slide.xml()
        parts[f"ppt/slides/_rels/slide{i}.xml.rels"] = slide.rels_xml()
        for relation in slide.rels:
            if 'relationships/image' in relation:
                target = relation.split('Target="../media/', 1)[1].split('"', 1)[0]
                media_part = f"ppt/media/{target}"
                if media_part not in parts:
                    source = IMAGE_SOURCES.get(target)
                    if source is None:
                        raise FileNotFoundError(f"Missing source for slide image: {target}")
                    with Image.open(source) as img:
                        img.verify()
                    parts[media_part] = source.read_bytes()

    for name, content in parts.items():
        if name.endswith(".xml"):
            ET.fromstring(content)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(OUT, "w", ZIP_DEFLATED) as package:
        for name, content in parts.items():
            package.writestr(name, content if isinstance(content, bytes) else content.encode("utf-8"))
    with ZipFile(OUT) as package:
        bad = package.testzip()
        if bad:
            raise RuntimeError(f"Corrupt PPTX package part: {bad}")
    print(f"Created {OUT} ({len(slides)} slides, {OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
