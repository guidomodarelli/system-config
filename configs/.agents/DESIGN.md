---
version: alpha
name: Heritage Spec
description: >
  Sistema visual para documentos técnicos y especificaciones internas.
  Estética de "broadsheet contemporáneo": fondo cálido tipo piedra caliza,
  sans neutra para lectura, mono para metadatos y código.
  Inspirado en specs de producto, RFCs y diseño editorial sobrio.
colors:
  # Texto e ink
  primary:           "#1A1A1A"   # Tinta profunda — títulos, énfasis, body fuerte
  body:              "#333333"   # Texto corrido — párrafos, listas, celdas
  muted:             "#555555"   # Sutil — subtítulos, descripciones secundarias
  label:             "#6B6B6B"   # Metadatos, labels mono, números de sección (≥4.5:1 en todas las superficies)
  link:              "#1A4F7A"   # Links en prosa (mismo tono que info-text)
  focus-ring:        "#1A4F7A"   # Outline de :focus-visible (≥3:1 sobre cualquier superficie clara)
  # Superficies neutras
  background:        "#F8F7F4"   # Fondo principal — limestone cálido
  surface-alt:       "#F0EDE6"   # Beige cálido — headers de tabla, code inline, badges neutros
  surface-card:      "#FFFFFF"   # Mockups, example boxes, accordions
  # Bordes
  border:            "#E0DDD6"   # Borde estándar — separadores, tablas
  border-strong:     "#D0CDC6"   # Borde de cards/mockups/pills
  border-neutral:    "#CCCCCC"   # Borde del badge gris
  border-ink:        "#1A1A1A"   # Línea pesada del doc-header y part-header (2px)
  # Superficie oscura (code blocks, step circles)
  surface-dark:      "#1A1A2E"
  on-dark:           "#E2E8F0"
  # Callout — Info (azul broadsheet)
  info-bg:           "#EAF3FB"
  info-border:       "#5A9FD4"
  info-text:         "#1A4F7A"
  # Callout — Warn (amber)
  warn-bg:           "#FDF5E0"
  warn-border:       "#D4A44C"
  warn-text:         "#7A5510"
  # Callout — Ok (verde apagado)
  ok-bg:             "#E8F7F2"
  ok-border:         "#4AAA8C"
  ok-text:           "#1A6B52"
  # Callout — Red/Alert (coral terracota)
  red-bg:            "#FEF8F6"
  red-border:        "#E8917A"
  red-text:          "#9E3D25"
  # Acentos para syntax highlighting (sobre surface-dark)
  syntax-comment:    "#7C8BA1"   # ≥4.5:1 sobre surface-dark
  syntax-keyword:    "#7DD3FC"
  syntax-string:     "#86EFAC"
  syntax-number:     "#FBBF24"
  syntax-function:   "#C084FC"
  syntax-tag:        "#F9A8D4"

typography:
  doc-title:
    fontFamily: DM Sans
    fontSize: 28px
    fontWeight: 600
    lineHeight: 1.2
  doc-sub:
    fontFamily: DM Sans
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.5
  doc-label:
    fontFamily: DM Mono
    fontSize: 11px
    fontWeight: 500
    letterSpacing: 0.14em
    # uso: text-transform: uppercase
  doc-meta:
    fontFamily: DM Mono
    fontSize: 11px
    fontWeight: 400
  part-title:
    fontFamily: DM Sans
    fontSize: 22px
    fontWeight: 600
    lineHeight: 1.2
  section-num:
    fontFamily: DM Mono
    fontSize: 11px
    fontWeight: 500
    letterSpacing: 0.12em
    # uso: text-transform: uppercase, color label
  section-title:
    fontFamily: DM Sans
    fontSize: 20px
    fontWeight: 600
    lineHeight: 1.3
  body-md:
    fontFamily: DM Sans
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.7
  body-callout:
    fontFamily: DM Sans
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.6
  table-header:
    fontFamily: DM Mono
    fontSize: 10px
    fontWeight: 500
    letterSpacing: 0.1em
    # uso: text-transform: uppercase
  table-cell:
    fontFamily: DM Sans
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.5
  badge:
    fontFamily: DM Mono
    fontSize: 10px
    fontWeight: 500
    letterSpacing: 0.05em
  code-inline:
    fontFamily: DM Mono
    fontSize: 12px
    fontWeight: 400
  code-block:
    fontFamily: DM Mono
    fontSize: 12px
    fontWeight: 400
    lineHeight: 1.7
  step-num:
    fontFamily: DM Mono
    fontSize: 12px
    fontWeight: 500
  step-label:
    fontFamily: DM Sans
    fontSize: 14px
    fontWeight: 600
  step-desc:
    fontFamily: DM Sans
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.6

rounded:
  xs:   3px     # code inline
  sm:   4px     # badges
  md:   6px     # pills, chips de estado
  lg:   8px     # callouts, code blocks, accordions
  xl:   10px    # mockups, example boxes, cards grandes
  full: 9999px  # circular (step-circle, mockup dots)

spacing:
  xs:  4px
  sm:  6px
  md:  8px
  lg:  12px
  xl:  16px
  2xl: 20px
  3xl: 24px
  4xl: 28px
  5xl: 40px
  6xl: 48px
  7xl: 80px

breakpoints:
  mobile: 720px   # por debajo: padding lateral 16px, tablas con scroll horizontal

components:
  # —— Layout raíz
  page:
    backgroundColor: "{colors.background}"
    textColor:       "{colors.primary}"
    typography:      "{typography.body-md}"
    padding:         "48px 24px 80px"
    # max-width: 860px, centrado horizontalmente; <720px: padding lateral 16px

  # —— Doc header
  doc-header:
    backgroundColor: "{colors.background}"
    padding:         "0 0 20px 0"
    # border-bottom: 2px solid {colors.border-ink}, margin-bottom: 40px
  doc-header-label:
    textColor:       "{colors.label}"
    typography:      "{typography.doc-label}"
  doc-header-title:
    textColor:       "{colors.primary}"
    typography:      "{typography.doc-title}"
    # elemento: <h1> (único por documento)
  doc-header-sub:
    textColor:       "{colors.muted}"
    typography:      "{typography.doc-sub}"
  doc-header-meta:
    textColor:       "{colors.label}"
    typography:      "{typography.doc-meta}"
    # display: flex, flex-wrap: wrap, gap: 24px, margin-top: 16px

  # —— Part header (separa partes mayores A / B)
  part-header:
    padding:         "32px 0 0 0"
    # border-top: 2px solid {colors.border-ink}, margin-top: 56px, margin-bottom: 40px
  part-header-label:
    textColor:       "{colors.label}"
    typography:      "{typography.doc-label}"
  part-header-title:
    textColor:       "{colors.primary}"
    typography:      "{typography.part-title}"
    # elemento: <h2>

  # —— Section block (bloque numerado)
  section:
    padding:         "0"
    # margin-bottom: 40px; elemento: <section>
  section-num:
    textColor:       "{colors.label}"
    typography:      "{typography.section-num}"
  section-title:
    textColor:       "{colors.primary}"
    typography:      "{typography.section-title}"
    # elemento: <h2>; padding-bottom: 8px, border-bottom: 1px solid {colors.border}

  # —— Links
  link:
    textColor:       "{colors.link}"
    # text-decoration: underline 1px, text-underline-offset: 2px; hover: grosor 2px

  # —— Callouts (4 variantes semánticas)
  callout-info:
    backgroundColor: "{colors.info-bg}"
    textColor:       "{colors.info-text}"
    typography:      "{typography.body-callout}"
    rounded:         "{rounded.lg}"
    padding:         "14px 18px"
    # border-left: 3px solid {colors.info-border}
  callout-warn:
    backgroundColor: "{colors.warn-bg}"
    textColor:       "{colors.warn-text}"
    typography:      "{typography.body-callout}"
    rounded:         "{rounded.lg}"
    padding:         "14px 18px"
    # border-left: 3px solid {colors.warn-border}
  callout-ok:
    backgroundColor: "{colors.ok-bg}"
    textColor:       "{colors.ok-text}"
    typography:      "{typography.body-callout}"
    rounded:         "{rounded.lg}"
    padding:         "14px 18px"
    # border-left: 3px solid {colors.ok-border}
  callout-red:
    backgroundColor: "{colors.red-bg}"
    textColor:       "{colors.red-text}"
    typography:      "{typography.body-callout}"
    rounded:         "{rounded.lg}"
    padding:         "14px 18px"
    # border-left: 3px solid {colors.red-border}

  # —— Table
  table-header:
    backgroundColor: "{colors.surface-alt}"
    textColor:       "{colors.label}"
    typography:      "{typography.table-header}"
    padding:         "8px 12px"
    # text-transform: uppercase, border-bottom: 1px solid {colors.border}
  table-cell:
    textColor:       "{colors.body}"
    typography:      "{typography.table-cell}"
    padding:         "10px 12px"
    # border-bottom: 1px solid {colors.border}, vertical-align: top
  table-wrap:
    padding:         "0"
    # overflow-x: auto — contenedor obligatorio para que la tabla no rompa el layout en mobile

  # —— Badges (pills compactas mono)
  badge-green:
    backgroundColor: "{colors.ok-bg}"
    textColor:       "{colors.ok-text}"
    typography:      "{typography.badge}"
    rounded:         "{rounded.sm}"
    padding:         "2px 8px"
    # border: 1px solid {colors.ok-border}
  badge-amber:
    backgroundColor: "{colors.warn-bg}"
    textColor:       "{colors.warn-text}"
    typography:      "{typography.badge}"
    rounded:         "{rounded.sm}"
    padding:         "2px 8px"
    # border: 1px solid {colors.warn-border}
  badge-red:
    backgroundColor: "{colors.red-bg}"
    textColor:       "{colors.red-text}"
    typography:      "{typography.badge}"
    rounded:         "{rounded.sm}"
    padding:         "2px 8px"
    # border: 1px solid {colors.red-border}
  badge-gray:
    backgroundColor: "{colors.surface-alt}"
    textColor:       "{colors.muted}"
    typography:      "{typography.badge}"
    rounded:         "{rounded.sm}"
    padding:         "2px 8px"
    # border: 1px solid {colors.border-neutral}

  # —— Steps (proceso numerado con línea conectora)
  step-circle:
    backgroundColor: "{colors.surface-dark}"
    textColor:       "{colors.surface-card}"
    typography:      "{typography.step-num}"
    rounded:         "{rounded.full}"
    width:           "32px"
    height:          "32px"
  step-label:
    textColor:       "{colors.primary}"
    typography:      "{typography.step-label}"
  step-desc:
    textColor:       "{colors.muted}"
    typography:      "{typography.step-desc}"
  # Línea conectora: 1px sólido {colors.border}, vertical, entre step-circles

  # —— Code (inline + block)
  code-inline:
    backgroundColor: "{colors.surface-alt}"
    textColor:       "{colors.primary}"
    typography:      "{typography.code-inline}"
    rounded:         "{rounded.xs}"
    padding:         "1px 5px"
  code-block:
    backgroundColor: "{colors.surface-dark}"
    textColor:       "{colors.on-dark}"
    typography:      "{typography.code-block}"
    rounded:         "{rounded.lg}"
    padding:         "20px 24px"

  # —— Mockup (ventana navegador estilizada)
  mockup:
    backgroundColor: "{colors.surface-card}"
    rounded:         "{rounded.xl}"
    # border: 1.5px solid {colors.border-strong}, overflow: hidden
  mockup-bar:
    backgroundColor: "{colors.surface-alt}"
    textColor:       "{colors.label}"
    typography:      "{typography.doc-meta}"
    padding:         "10px 16px"
    # border-bottom: 1px solid {colors.border-strong}
    # dots 10×10px {rounded.full}: {colors.red-border}, {colors.warn-border}, {colors.ok-border}
  mockup-body:
    backgroundColor: "{colors.surface-card}"
    padding:         "20px"

  # —— Example box (cita destacada con label mono)
  example-box:
    backgroundColor: "{colors.surface-card}"
    rounded:         "{rounded.xl}"
    padding:         "18px 22px"
    # border: 1.5px solid {colors.border-strong}
  example-box-label:
    textColor:       "{colors.label}"
    typography:      "{typography.doc-label}"

  # —— Pills (chips de estado para flujos)
  pill-neutral:
    backgroundColor: "{colors.surface-alt}"
    textColor:       "{colors.primary}"
    typography:      "{typography.code-inline}"
    rounded:         "{rounded.md}"
    padding:         "6px 12px"
    # border: 1px solid {colors.border-strong}
  pill-success:
    backgroundColor: "{colors.ok-bg}"
    textColor:       "{colors.ok-text}"
    typography:      "{typography.code-inline}"
    rounded:         "{rounded.md}"
    padding:         "6px 12px"
    # border: 1px solid {colors.ok-border}
  pill-stale:
    backgroundColor: "{colors.surface-alt}"
    textColor:       "{colors.red-text}"
    typography:      "{typography.code-inline}"
    rounded:         "{rounded.md}"
    padding:         "6px 12px"
    # border: 1px solid {colors.border-strong}, text-decoration: line-through

  # —— Divider
  divider:
    backgroundColor: "{colors.border}"
    height:          "1px"
    # margin: 28px 0

  # —— Accordion (bloque colapsable de detalle)
  accordion:
    backgroundColor: "{colors.surface-card}"
    rounded:         "{rounded.lg}"
    # border: 1px solid {colors.border}, margin-bottom: 10px, overflow: hidden
  accordion-summary:
    textColor:       "{colors.primary}"
    typography:      "{typography.section-title}"  # mismo peso/size que un título de sección, sin border
    padding:         "13px 16px"
    # cursor: pointer; marcador nativo oculto; glifo +/– (DM Mono, color label) a la derecha
    # [open] agrega border-bottom: 1px solid {colors.border}
  accordion-num:
    textColor:       "{colors.label}"
    typography:      "{typography.section-num}"
    # label mono uppercase opcional dentro del summary (ej. "Reglas", "Checklist")
  accordion-body:
    textColor:       "{colors.body}"
    padding:         "14px 16px 4px"
---

## Overview

Minimalismo arquitectónico + gravitas periodística. La interfaz emula un
broadsheet premium o una galería contemporánea: fondo de piedra caliza
cálida, tinta profunda para titulares, y un único acento por familia de
callout en lugar de paletas saturadas.

El sistema fue diseñado para **documentos densos en información**: specs
técnicas, reglas de negocio, RFCs, runbooks. Prioriza legibilidad
prolongada por sobre impacto visual, y conviene leerse impreso o en
pantalla sin perder jerarquía.

**Características clave:**

- Dos familias tipográficas únicas — **DM Sans** para lectura, **DM Mono** para metadatos.
- Fondo `#F8F7F4` (no blanco puro) para reducir fatiga visual.
- Numeración explícita de secciones (`01`, `02`, …) en mono uppercase como guía estructural.
- Cuatro tonos de callout (info, warn, ok, red) que cubren todo el espectro de aviso.
- Ningún componente usa sombras pesadas: la jerarquía se logra con tipografía y bordes finos.
- Todo par texto/fondo cumple **WCAG AA** (≥4.5:1); ver [Accesibilidad](#accesibilidad).

**Fuera de alcance:** modo oscuro. La estética es de papel impreso; el
documento declara `color-scheme: light` y no redefine la paleta.

## Colors

La paleta se construye sobre **neutros cálidos de alto contraste** y cuatro
familias de acento semánticas. Nada de grises azulados ni blancos puros.
Cualquier color que no esté en el front matter está fuera del sistema.

### Tinta y texto

- **primary (`#1A1A1A`)** — Tinta profunda para titulares, énfasis, body en negrita.
- **body (`#333333`)** — Texto corrido en párrafos, listas, celdas de tabla. Es lo que el lector lee por más tiempo; por eso no es negro absoluto.
- **muted (`#555555`)** — Subtítulos, descripciones secundarias de un step. Lo suficientemente legible pero claramente subordinado.
- **label (`#6B6B6B`)** — Metadatos, números de sección, headers de tabla en mono uppercase. Texto que "guía" sin reclamar atención. Es el gris más claro permitido para texto: el anterior `#888888` no llegaba a 4.5:1 en ninguna superficie.
- **link (`#1A4F7A`)** — Links dentro de prosa, siempre subrayados. Comparte tono con `info-text` para no sumar un acento nuevo.

### Superficies

- **background (`#F8F7F4`)** — Limestone cálido. Reemplaza el blanco puro para suavizar la lectura.
- **surface-alt (`#F0EDE6`)** — Beige cálido para headers de tabla, code inline, badges neutros. Diferencia sutil del fondo.
- **surface-card (`#FFFFFF`)** — Único uso del blanco puro: dentro de mockups, example boxes y accordions que necesitan destacarse como "pieza encajada" sobre el fondo.
- **surface-dark (`#1A1A2E`)** — Tinta nocturna para code blocks y step circles. Único elemento muy oscuro de la página: por eso ancla la mirada cuando aparece.

### Acentos semánticos

Cada acento viene en tríada `bg / border / text` y se usa siempre en los mismos roles:

- **Info (azul broadsheet)** — Contexto, aclaraciones, lógica de fondo. Es el callout por defecto cuando hay duda.
- **Warn (amber)** — Advertencias suaves, condicionales, "ojo con esto". No alarmante.
- **Ok (verde apagado)** — Confirmaciones, éxito, "lo que sí queremos".
- **Red (coral terracota, no rojo brillante)** — Alertas críticas, consecuencias, pendientes urgentes. El tono está apagado a propósito para no romper la paleta editorial; transmite seriedad sin gritar.

El uso es consistente: **bg suave** rellena el callout, **border** se aplica como `border-left: 3px solid`, **text** colorea el texto del callout y de los badges asociados. Los `*-border` son decorativos: **nunca usarlos como color de texto** (no alcanzan 3:1).

## Typography

Dos familias, ambas de Google Fonts. Cargarlas con `<link>` + `preconnect`
(más rápido que `@import`, que bloquea el parseo del CSS):

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600&family=DM+Mono:wght@400;500&display=swap">
```

### DM Sans — lectura

Geométrica humanista, levemente grotesca. Funciona en titulares y en body
sin cambiar de carácter. Pesos disponibles: 400 (regular), 500 (medium),
600 (semibold). **Nunca usar 700 o más** — rompe la sobriedad editorial.
Ojo: `<h1>`, `<h2>`, `<th>` y `<strong>` son `bold` (700) por defecto en el
navegador; el boilerplate los fija en 600.

| Token | Tamaño | Peso | Uso |
| --- | --- | --- | --- |
| `doc-title` | 28px | 600 | Título de documento (1× por página, `<h1>`) |
| `part-title` | 22px | 600 | División entre partes mayores (Parte A / Parte B) |
| `section-title` | 20px | 600 | Encabezado de sección numerada (`<h2>`) |
| `body-md` | 14px | 400 | Párrafos y listas |
| `body-callout` | 13px | 400 | Texto dentro de callouts (más compacto) |
| `table-cell` | 13px | 400 | Celdas de tabla |
| `step-label` | 14px | 600 | Etiqueta de cada paso |
| `step-desc` | 13px | 400 | Descripción bajo la etiqueta del paso |

Line-height: **1.7** para body, **1.6** para callouts, **1.5** para celdas.
Esto da espacio para leer páginas largas sin agotar la vista.

### DM Mono — estructura

Monoespaciada, geométrica. Es la "voz del sistema": números, IDs, labels,
estados. Siempre indica algo que el lector debería tratar como literal o como
metadato — no como prosa.

| Token | Tamaño | Peso | Tracking | Caja |
| --- | --- | --- | --- | --- |
| `doc-label` | 11px | 500 | 0.14em | UPPERCASE |
| `section-num` | 11px | 500 | 0.12em | UPPERCASE |
| `doc-meta` | 11px | 400 | — | mixed |
| `table-header` | 10px | 500 | 0.10em | UPPERCASE |
| `badge` | 10px | 500 | 0.05em | mixed |
| `code-inline` | 12px | 400 | — | mixed |
| `code-block` | 12px | 400 | — | mixed |
| `step-num` | 12px | 500 | — | mixed |

**Regla mnemotécnica:** si el contenido es legible como oración, va en **DM Sans**.
Si es un identificador, número, label, código o estado, va en **DM Mono**.

## Layout

### Página

- Ancho máximo: **`860px`**, centrado horizontalmente.
- Padding del body: **`48px`** arriba, **`24px`** a los lados, **`80px`** abajo.
- Fondo `{colors.background}` sólido (no gradientes).
- En mobile (`<720px`) el padding lateral baja a `16px` y las tablas scrollean horizontalmente dentro de `.table-wrap`; la tipografía se mantiene en los mismos tamaños. Nunca debe haber scroll horizontal de la página.

### Densidad

- Separación entre secciones: **`40px`**.
- Separación interna de una sección (entre párrafos, listas, tablas, callouts): **`12–16px`**.
- Padding de callouts y example boxes: **`14–22px`**, nunca más.

### Jerarquía estructural

Un documento típico se estructura así, de arriba a abajo:

```
doc-header           ← encabezado completo del documento (<header>, título en <h1>)
section 01           ← cada sección numerada (<section>, título en <h2>)
section 02
section 03
[part-header]        ← (opcional) separador de partes mayores (título en <h2>)
section 04
section 05
…
```

### Gramática de líneas

Hay dos familias de líneas y no se mezclan:

- **Divisores** (separan bloques del flujo): `2px` sólido tinta en `doc-header` (abajo) y `part-header` (arriba); `1px` `{colors.border}` bajo cada `section-title`, entre filas de tabla y en `.divider`. **Son los únicos divisores del sistema** — no agregar otros.
- **Contornos** (delimitan una pieza encajada): `1px` en accordions y badges, `1.5px` `{colors.border-strong}` en mockups y example boxes, `3px` a la izquierda en callouts para indicar el tono.

## Elevation & Depth

El sistema **no usa sombras**. La profundidad se logra exclusivamente con:

1. **Bordes finos** (`1px` / `1.5px`) en tono cálido `{colors.border}` o `{colors.border-strong}`.
2. **Cambios de superficie** entre `background`, `surface-alt`, `surface-card` y `surface-dark`.
3. **Bordes-izquierdos gruesos** (`3px`) en callouts, que indican el tono del bloque.

Esto mantiene la sensación de papel impreso y evita el aire "interfaz de
software". Si en algún caso muy puntual se necesita sombra, usar
`0 1px 2px rgba(0,0,0,0.04)` — apenas perceptible.

## Shapes

| Token | Valor | Uso |
| --- | --- | --- |
| `rounded.xs` | 3px | Code inline |
| `rounded.sm` | 4px | Badges |
| `rounded.md` | 6px | Pills, chips de estado |
| `rounded.lg` | 8px | Callouts, code blocks, accordions |
| `rounded.xl` | 10px | Mockups, example boxes, cards grandes |
| `rounded.full` | 9999px | Step circles, dots del mockup bar |

**Sin redondeos por encima de `10px`** salvo lo circular puro. Esto preserva
el carácter editorial — nada de bubbles tipo dashboard SaaS.

## Components

Los snippets HTML de cada componente están en [Snippets de componentes](#snippets-de-componentes).

### Doc header

El primer bloque de todo documento. Estructura vertical:

```
[doc-label]   ← contexto: proyecto, alcance, área (mono uppercase)
[doc-title]   ← título principal (<h1>) — puede ocupar 2 líneas con <br>
[doc-sub]     ← subtítulo descriptivo (1 línea)
[doc-meta]    ← row horizontal de metadatos (fecha · prioridad · estado · estimado)
```

Cierra con `border-bottom: 2px solid {colors.border-ink}` y `margin-bottom: 40px`.
Las fechas de `doc-meta` van en formato absoluto (`2026-09-27`), nunca relativas.

### Part header

Separa partes mayores de un documento largo (Parte A / Parte B). Abre con
`border-top: 2px solid {colors.border-ink}`, `margin-top: 56px` y
`padding-top: 32px`. Lleva un `part-header-label` mono uppercase
(`PARTE B`) y un `part-header-title` (`<h2>`, 22/600). Si el documento tiene
una sola parte, no usarlo.

### Section

Bloque numerado. Estructura:

```
[section-num]    "01", "02", … (mono uppercase, color label)
[section-title]  Título de la sección (<h2>, DM Sans 20/600)
[contenido]      párrafos, listas, callouts, tablas, code, mockups, steps
```

El `section-title` cierra con `border-bottom: 1px solid {colors.border}` y
`padding-bottom: 8px`. **No agregar `<h3>`+ para sub-jerarquías dentro de
una sección** — preferir prosa con `<strong>`. Si una sección crece
demasiado, dividirla en dos secciones numeradas o colapsar su referencia en
accordions.

### Callouts

Cuatro variantes, cada una con borde-izquierdo de `3px`. Reglas de elección:

- **Info (azul)**: contexto, lógica de fondo, "esto funciona así porque…".
- **Warn (amber)**: precaución, condicionales, restricciones.
- **Ok (verde)**: confirmaciones, "esto sí queremos", éxito.
- **Red (coral)**: consecuencias críticas, pendientes urgentes, errores.

Empezar el callout con una palabra clave en `<strong>` (`Importante:`,
`Ojo:`, `Resultado:`) para que el tono no dependa solo del color.
**Nunca anidar callouts**. Si un callout contiene una lista, usar `<ul>` o
`<ol>` normales — el callout ya provee el énfasis.

### Tables

- Siempre dentro de `<div class="table-wrap">` para que scrolleen en mobile.
- Header en `{typography.table-header}` (mono, uppercase, tracking), con `scope="col"`.
- Fondo de header en `{colors.surface-alt}`.
- Celdas en `{typography.table-cell}` (13px) con `padding: 10px 12px`, `vertical-align: top`, `line-height: 1.5`.
- Borde inferior `1px solid {colors.border}` entre filas; **sin borde** en la última fila.
- Sin bordes verticales — la separación columna se logra con padding y el cambio tipográfico header/celda.

Usar tablas para comparativas estructuradas (operación / efecto / condición)
o para listas con columnas claras. Si tiene menos de 2 columnas reales,
preferir una lista.

### Badges

Pills compactas para estado. Cuatro variantes:

- `b-green`: ✓, "Sí", "Completado".
- `b-amber`: "Solo como excepción", "Media", "A coordinar".
- `b-red`: "Pendiente", "Bloqueante".
- `b-gray`: "Opcional", neutral.

Siempre en mono, siempre con `padding: 2px 8px`, siempre con borde `1px` del
color de la familia. **El texto del badge debe entenderse sin el color**
(`✓ Sí`, no un badge verde vacío). **No usar emojis dentro de badges** — el
color y el texto ya transmiten estado.

### Steps

Lista vertical numerada con línea conectora. Estructura:

```
[step-circle 1] [step-label] + [step-desc]
       │
[step-circle 2] [step-label] + [step-desc]
       │
[step-circle N] [step-label] + [step-desc]
```

- Se marca como `<ol class="steps">`; el número del `step-circle` es decorativo (`aria-hidden="true"`) porque la lista ordenada ya lo anuncia.
- `step-circle` es un círculo de `32×32px`, fondo `{colors.surface-dark}`, texto blanco mono.
- La línea conectora es `1px solid {colors.border}`, vertical, desde el bottom del circle hasta el siguiente; el último step no la tiene.
- Usar steps para **secuencias temporales o procesos accionables** ("1. cancela → 2. se re-suscribe"). No usar para listas de items independientes — para eso, `<ul>`.

### Code

- **Inline (`<code>`)**: fondo `{colors.surface-alt}`, padding `1px 5px`, radius `3px`. Para nombres de archivo, identificadores, valores literales en prosa.
- **Block (`.code-block`)**: fondo `{colors.surface-dark}`, texto `{colors.on-dark}`, padding `20px 24px`, radius `8px`, `overflow-x: auto`. Para snippets de SQL, HTML, JS, configuración. Escapar `<`, `>` y `&` dentro del `<pre>`.

Sintaxis: usar `<span>` con clases `c-comment`, `c-key`, `c-str`, `c-num`,
`c-fn`, `c-tag` para colorear manualmente. Los colores están en
`colors.syntax-*`. **No incluir números de línea** salvo que sean
referenciados desde el texto.

### Mockup

Ventana de navegador estilizada (tres dots tipo macOS + URL bar). Usar
**solo cuando una pantalla real ayuda más que la descripción**. Estructura:

```
[mockup-bar]   dots rojo/amarillo/verde + texto de URL (mono, color label)
[mockup-body]  contenido real del mockup (puede ser un layout multi-columna)
```

Border `1.5px solid {colors.border-strong}`, radius `10px`, fondo
`{colors.surface-card}`. Los dots usan `red-border`, `warn-border` y
`ok-border` (10×10px) y son decorativos (`aria-hidden="true"`). Agregar
`role="img"` + `aria-label` con una descripción breve de la pantalla cuando
el mockup es un dibujo y no contenido legible.

### Example box

Cita destacada con label mono. Estructura:

```
[example-label]   "EJEMPLO PRÁCTICO" — mono uppercase
[example-body]    el cuerpo del ejemplo
```

Border `1.5px solid {colors.border-strong}`, fondo blanco, radius `10px`.
Equivalente a un callout pero con tono **neutro** — para narrar un caso
concreto sin teñirlo de aviso/éxito/error.

### Pills (chips de estado en flujos)

Útiles para representar transiciones de valor (`$15 → $20`):

- `pill-neutral`: estado actual sin connotación.
- `pill-success`: estado deseado / vigente.
- `pill-stale`: estado viejo (con `text-decoration: line-through`). Para lectores de pantalla, envolver el valor en `<del>` en lugar de depender solo del tachado visual.

Se intercalan con flechas mono (`→`, `aria-hidden="true"`) en color
`{colors.label}`, dentro de un contenedor `.flow` que hace wrap en mobile.

### Link

Color `{colors.link}`, subrayado `1px` con `text-underline-offset: 2px`; en
hover el subrayado pasa a `2px`. Nunca quitar el subrayado: el color solo no
distingue un link del texto. Links externos con texto descriptivo, no
"click acá".

### Accordion (bloques colapsables)

Bloque de detalle que arranca **cerrado** y se expande al click. Pensado para
**documentos densos**: una sección con muchas reglas, tablas de comportamiento,
casos de error y checklists se vuelve un muro vertical. El accordion deja a la
vista solo los títulos y el lector abre lo que necesita.

Implementación nativa con `<details class="acc">` + `<summary>` (sin JS para
abrir/cerrar). Estructura:

```
[summary]   [accordion-num] (label mono opcional) + título  ···  glifo +/–
[acc-body]  contenido: prosa, listas, tablas, callouts
```

- Borde `1px solid {colors.border}`, radius `8px`, fondo `surface-card`.
- El `summary` usa el peso/tamaño de un `section-title` pero **sin** su borde inferior; el marcador nativo se oculta y se reemplaza por un glifo `+` (cerrado) / `–` (abierto) en mono, color `label`, alineado a la derecha.
- Al abrir (`[open]`), el `summary` cierra con `border-bottom: 1px solid {colors.border}` para separar del cuerpo.
- Opcional: un `accordion-num` (mono uppercase, color `label`) al inicio del summary como mini-etiqueta del bloque (`Reglas`, `Comportamiento`, `Checklist`), en el mismo espíritu que `section-num`.
- El `summary` es focuseable con teclado: nunca quitarle el `:focus-visible`.

**Regla de uso:** colapsar los bloques de **referencia** (reglas de negocio,
comportamiento esperado, casos de error, checklist) y dejar **siempre abiertos**
los de **acción** (intro/objetivo, flujo en `steps`, mockups). No anidar
accordions ni meter un mockup pesado adentro de uno cerrado. Si una sección no
es densa, no la colapses — el accordion es para domar volumen, no decoración.

## Accesibilidad

- **Contraste**: todo texto cumple ≥4.5:1 sobre su superficie; bordes con significado y el anillo de foco, ≥3:1. Valores medidos: `label` 4.56–5.33:1, `muted` ≥6.38:1, textos de callout 5.8–7.7:1, `syntax-comment` 4.93:1.
- **Semántica**: `<header>` + `<h1>` para el doc-header, `<section>` + `<h2>` por sección, `<ol>` para steps, `<th scope="col">` en tablas, `<details>/<summary>` para accordions.
- **Foco**: `:focus-visible` con `outline: 2px solid {colors.focus-ring}` y `outline-offset: 2px` en links y summaries. Nunca `outline: none` sin reemplazo.
- **Color no es el único canal**: callouts con palabra clave inicial, badges con texto, links subrayados, estados viejos con `<del>`.
- **Decoración oculta**: dots del mockup, flechas de flujo y números de step-circle llevan `aria-hidden="true"`.
- **Idioma**: `<html lang="es">`; fragmentos en otro idioma con `lang` propio si son prosa (no hace falta para código).

## Impresión

El documento debe imprimirse (o exportarse a PDF) sin perder jerarquía:

- Fondo blanco y sin padding de página: el limestone no se imprime bien y el navegador lo descarta por defecto.
- `break-inside: avoid` en callouts, example boxes, mockups, steps, code blocks y filas de tabla; `break-after: avoid` en títulos.
- Los accordions se abren antes de imprimir (snippet `beforeprint` del boilerplate); el glifo `+/–` se oculta.
- Los links muestran su URL entre paréntesis después del texto.

## Do's and Don'ts

### Do

- **Numerá las secciones** (`01`, `02`, …). Da una sensación de spec serio y permite referenciar "ver sección 04".
- **Usá `doc-label` y `section-num` en mono uppercase**. Es la firma visual del sistema.
- **Elegí callouts conscientemente**: cada uno tiene un significado, no son intercambiables.
- **Mantené párrafos cortos** (3–5 líneas máximo). El line-height generoso es para escanear, no para muros de texto.
- **Usá `<strong>` para énfasis dentro de prosa**, no `<b>` ni colores arbitrarios.
- **Tipografiá las celdas de tabla con `table-cell`** (DM Sans 13px) — los headers van en mono, las celdas no.
- **Envolvé toda tabla en `.table-wrap`** para que no desborde en mobile.
- **Colapsá los bloques de referencia en docs densos** con `accordion` (reglas, comportamiento, errores, checklist) y dejá abiertos intro, flujo y mockups. Convertí listas largas de "comportamiento" en tablas `situación → comportamiento`.
- **Referenciá colores por variable CSS** (`var(--label)`), no por hex suelto: así el documento sigue a la paleta si cambia.

### Don't

- **No uses sombras pesadas.** Bordes finos y cambios de superficie son suficientes.
- **No mezcles paletas de color** (verde brillante, rojo Material, azul Bootstrap). El sistema tiene cuatro acentos apagados; cualquier color fuera de la paleta rompe la estética.
- **No uses pesos `700+` de DM Sans**, ni cursivas marcadas. La sobriedad se rompe rápido con tipografía dramática.
- **No anides callouts dentro de callouts** ni callouts dentro de tablas.
- **No uses iconos decorativos** (emojis, lucide a granel). El sistema confía en tipografía y color. Excepción: un emoji muy puntual dentro de un title de step (📦, 🎯) si suma información concreta.
- **No agregues efectos hover llamativos** en documentos estáticos. Si el doc es interactivo, los hovers deben ser cambios sutiles de borde o fondo, nunca elevación dramática.
- **No uses fondos blancos puros para el body** en pantalla. El `#F8F7F4` está calibrado para que `surface-card` (blanco) destaque por encima. (En impresión sí se usa blanco.)
- **No uses más de un `doc-title` por archivo.** Para sub-documentos, usar `part-header`.
- **No uses grises más claros que `label`** para texto, ni los `*-border` como color de texto.

## Checklist de conformidad

Antes de entregar o aprobar un documento con este sistema:

- [ ] Un solo `<h1 class="doc-title">`; secciones numeradas con `<h2 class="section-title">`.
- [ ] Solo colores del front matter, referenciados por variable CSS.
- [ ] Solo DM Sans (400/500/600) y DM Mono (400/500); ningún peso 700.
- [ ] Toda tabla dentro de `.table-wrap`, headers con `scope="col"`.
- [ ] Callouts elegidos por significado y con palabra clave inicial; ninguno anidado.
- [ ] Badges con texto legible sin color; sin emojis.
- [ ] Accordions solo en bloques de referencia; intro, steps y mockups abiertos.
- [ ] Sin sombras (salvo la mínima documentada) ni redondeos >10px no circulares.
- [ ] Sin scroll horizontal de página a 360px de ancho.
- [ ] Vista previa de impresión legible: accordions abiertos, bloques sin cortar.

---

### Boilerplate HTML mínimo

Para arrancar un documento nuevo con el sistema, copiar este esqueleto. Incluye
el CSS de **todos** los componentes; los que no se usen pueden quedarse.

```html
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>[Título del documento]</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600&family=DM+Mono:wght@400;500&display=swap">
<style>
:root{
  color-scheme:light;
  --primary:#1a1a1a;--body:#333;--muted:#555;--label:#6b6b6b;--link:#1a4f7a;--focus-ring:#1a4f7a;
  --bg:#f8f7f4;--surface-alt:#f0ede6;--surface-card:#fff;
  --border:#e0ddd6;--border-strong:#d0cdc6;--border-neutral:#ccc;--border-ink:#1a1a1a;
  --surface-dark:#1a1a2e;--on-dark:#e2e8f0;
  --info-bg:#eaf3fb;--info-border:#5a9fd4;--info-text:#1a4f7a;
  --warn-bg:#fdf5e0;--warn-border:#d4a44c;--warn-text:#7a5510;
  --ok-bg:#e8f7f2;--ok-border:#4aaa8c;--ok-text:#1a6b52;
  --red-bg:#fef8f6;--red-border:#e8917a;--red-text:#9e3d25;
  --syntax-comment:#7c8ba1;--syntax-keyword:#7dd3fc;--syntax-string:#86efac;
  --syntax-number:#fbbf24;--syntax-function:#c084fc;--syntax-tag:#f9a8d4;
  --sans:'DM Sans',sans-serif;--mono:'DM Mono',monospace;
}
*{box-sizing:border-box;margin:0;padding:0;}
body{font-family:var(--sans);background:var(--bg);color:var(--primary);padding:48px 24px 80px;max-width:860px;margin:0 auto;}
h1,h2,th,strong{font-weight:600;}
.doc-header{border-bottom:2px solid var(--border-ink);padding-bottom:20px;margin-bottom:40px;}
.doc-label,.part-header-label,.example-label{font-family:var(--mono);font-size:11px;font-weight:500;letter-spacing:0.14em;text-transform:uppercase;color:var(--label);margin-bottom:8px;}
.doc-title{font-size:28px;line-height:1.2;margin-bottom:6px;}
.doc-sub{font-size:14px;line-height:1.5;color:var(--muted);}
.doc-meta{display:flex;flex-wrap:wrap;gap:8px 24px;margin-top:16px;font-family:var(--mono);font-size:11px;color:var(--label);}
.part-header{border-top:2px solid var(--border-ink);margin-top:56px;padding-top:32px;margin-bottom:40px;}
.part-header-title{font-size:22px;line-height:1.2;}
.section{margin-bottom:40px;}
.section-num,.acc-num{font-family:var(--mono);font-size:11px;font-weight:500;letter-spacing:0.12em;text-transform:uppercase;color:var(--label);}
.section-num{margin-bottom:6px;}
.section-title{font-size:20px;line-height:1.3;margin-bottom:16px;padding-bottom:8px;border-bottom:1px solid var(--border);}
p{font-size:14px;line-height:1.7;color:var(--body);margin-bottom:12px;}
ul,ol{padding-left:22px;margin-bottom:12px;}
li{font-size:14px;line-height:1.7;color:var(--body);margin-bottom:6px;}
strong{color:var(--primary);}
a{color:var(--link);text-decoration:underline;text-decoration-thickness:1px;text-underline-offset:2px;}
a:hover{text-decoration-thickness:2px;}
:focus-visible{outline:2px solid var(--focus-ring);outline-offset:2px;border-radius:2px;}
.callout{border-radius:8px;padding:14px 18px;margin:16px 0;font-size:13px;line-height:1.6;border-left:3px solid;}
.callout p,.callout li{font-size:inherit;line-height:inherit;color:inherit;}
.callout strong{color:inherit;}
.callout>:last-child{margin-bottom:0;}
.c-info{background:var(--info-bg);border-color:var(--info-border);color:var(--info-text);}
.c-warn{background:var(--warn-bg);border-color:var(--warn-border);color:var(--warn-text);}
.c-ok{background:var(--ok-bg);border-color:var(--ok-border);color:var(--ok-text);}
.c-red{background:var(--red-bg);border-color:var(--red-border);color:var(--red-text);}
.table-wrap{overflow-x:auto;margin:16px 0;}
table{width:100%;border-collapse:collapse;font-size:13px;}
th{font-family:var(--mono);font-size:10px;font-weight:500;letter-spacing:0.1em;text-transform:uppercase;color:var(--label);text-align:left;padding:8px 12px;border-bottom:1px solid var(--border);background:var(--surface-alt);}
td{padding:10px 12px;border-bottom:1px solid var(--border);vertical-align:top;line-height:1.5;color:var(--body);}
tr:last-child td{border-bottom:none;}
.badge{display:inline-block;font-family:var(--mono);font-size:10px;font-weight:500;padding:2px 8px;border-radius:4px;letter-spacing:0.05em;border:1px solid;white-space:nowrap;}
.b-green{background:var(--ok-bg);color:var(--ok-text);border-color:var(--ok-border);}
.b-amber{background:var(--warn-bg);color:var(--warn-text);border-color:var(--warn-border);}
.b-red{background:var(--red-bg);color:var(--red-text);border-color:var(--red-border);}
.b-gray{background:var(--surface-alt);color:var(--muted);border-color:var(--border-neutral);}
.steps{list-style:none;padding:0;margin:16px 0;}
.step-item{display:flex;gap:16px;padding-bottom:24px;margin:0;position:relative;}
.step-item::before{content:'';position:absolute;left:15px;top:32px;bottom:0;width:1px;background:var(--border);}
.step-item:last-child{padding-bottom:0;}
.step-item:last-child::before{display:none;}
.step-circle{width:32px;height:32px;border-radius:50%;background:var(--surface-dark);color:var(--surface-card);display:flex;align-items:center;justify-content:center;font-family:var(--mono);font-size:12px;font-weight:500;flex-shrink:0;}
.step-body{padding-top:4px;flex:1;}
.step-label{font-size:14px;font-weight:600;margin-bottom:4px;}
.step-desc{font-size:13px;color:var(--muted);line-height:1.6;}
code{font-family:var(--mono);background:var(--surface-alt);color:var(--primary);padding:1px 5px;border-radius:3px;font-size:12px;}
.code-block{background:var(--surface-dark);border-radius:8px;padding:20px 24px;margin:16px 0;overflow-x:auto;}
.code-block pre{font-family:var(--mono);font-size:12px;line-height:1.7;color:var(--on-dark);white-space:pre;}
.c-comment{color:var(--syntax-comment);} .c-key{color:var(--syntax-keyword);} .c-str{color:var(--syntax-string);}
.c-num{color:var(--syntax-number);} .c-fn{color:var(--syntax-function);} .c-tag{color:var(--syntax-tag);}
.mockup{background:var(--surface-card);border:1.5px solid var(--border-strong);border-radius:10px;overflow:hidden;margin:16px 0;}
.mockup-bar{display:flex;align-items:center;gap:12px;padding:10px 16px;background:var(--surface-alt);border-bottom:1px solid var(--border-strong);font-family:var(--mono);font-size:11px;color:var(--label);}
.mockup-dots{display:flex;gap:6px;flex-shrink:0;}
.mockup-dots span{width:10px;height:10px;border-radius:50%;}
.mockup-dots span:nth-child(1){background:var(--red-border);}
.mockup-dots span:nth-child(2){background:var(--warn-border);}
.mockup-dots span:nth-child(3){background:var(--ok-border);}
.mockup-url{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}
.mockup-body{padding:20px;}
.example-box{background:var(--surface-card);border:1.5px solid var(--border-strong);border-radius:10px;padding:18px 22px;margin:16px 0;}
.example-box>:last-child{margin-bottom:0;}
.flow{display:flex;flex-wrap:wrap;align-items:center;gap:8px;margin:16px 0;}
.flow-arrow{font-family:var(--mono);color:var(--label);}
.pill{display:inline-block;font-family:var(--mono);font-size:12px;padding:6px 12px;border-radius:6px;border:1px solid var(--border-strong);}
.pill-neutral{background:var(--surface-alt);color:var(--primary);}
.pill-success{background:var(--ok-bg);color:var(--ok-text);border-color:var(--ok-border);}
.pill-stale{background:var(--surface-alt);color:var(--red-text);text-decoration:line-through;}
.pill-stale del{text-decoration:inherit;}
.divider{height:1px;background:var(--border);border:0;margin:28px 0;}
.acc{background:var(--surface-card);border:1px solid var(--border);border-radius:8px;margin-bottom:10px;overflow:hidden;}
.acc>summary{list-style:none;display:flex;align-items:baseline;gap:10px;padding:13px 16px;cursor:pointer;font-size:20px;font-weight:600;line-height:1.3;color:var(--primary);}
.acc>summary::-webkit-details-marker{display:none;}
.acc>summary::after{content:'+';margin-left:auto;font-family:var(--mono);font-size:16px;font-weight:400;color:var(--label);}
.acc[open]>summary{border-bottom:1px solid var(--border);}
.acc[open]>summary::after{content:'–';}
.acc>summary:focus-visible{outline-offset:-2px;}
.acc-body{padding:14px 16px 4px;color:var(--body);}
@media (max-width:719px){
  body{padding-left:16px;padding-right:16px;}
  .code-block{padding:16px;}
}
@media print{
  body{background:#fff;padding:0;max-width:none;}
  .callout,.example-box,.mockup,.step-item,.code-block,tr{break-inside:avoid;}
  .section-title,.part-header,.acc>summary{break-after:avoid;}
  .acc>summary::after{display:none;}
  a[href^="http"]::after{content:" (" attr(href) ")";font-size:11px;color:var(--label);}
}
</style>
</head>
<body>
<header class="doc-header">
  <div class="doc-label">[Etiqueta — proyecto o área]</div>
  <h1 class="doc-title">[Título principal]</h1>
  <p class="doc-sub">[Subtítulo descriptivo]</p>
  <div class="doc-meta"><span>Fecha: …</span><span>Estado: …</span></div>
</header>

<section class="section" aria-labelledby="s01">
  <div class="section-num">01</div>
  <h2 class="section-title" id="s01">[Título de la sección]</h2>
  <p>…</p>
</section>

<script>
// Abre los accordions al imprimir para que el PDF no oculte contenido.
window.addEventListener('beforeprint', () => {
  document.querySelectorAll('details.acc').forEach((accordion) => { accordion.open = true; });
});
</script>
</body>
</html>
```

### Snippets de componentes

Markup de referencia para cada componente. Los nombres de clase son contrato:
otras skills (por ejemplo `user-manual`) dependen de ellos.

```html
<!-- Part header -->
<div class="part-header">
  <div class="part-header-label">Parte B</div>
  <h2 class="part-header-title">[Título de la parte]</h2>
</div>

<!-- Callout -->
<div class="callout c-warn"><strong>Ojo:</strong> …</div>

<!-- Tabla -->
<div class="table-wrap">
  <table>
    <thead><tr><th scope="col">Situación</th><th scope="col">Comportamiento</th><th scope="col">Estado</th></tr></thead>
    <tbody><tr><td>…</td><td>…</td><td><span class="badge b-green">✓ Sí</span></td></tr></tbody>
  </table>
</div>

<!-- Steps -->
<ol class="steps">
  <li class="step-item">
    <span class="step-circle" aria-hidden="true">1</span>
    <div class="step-body"><div class="step-label">[Acción]</div><div class="step-desc">[Detalle]</div></div>
  </li>
</ol>

<!-- Code block -->
<div class="code-block"><pre><span class="c-comment">// comentario</span>
<span class="c-key">const</span> total = <span class="c-fn">sum</span>(<span class="c-num">1</span>, <span class="c-num">2</span>);</pre></div>

<!-- Mockup -->
<div class="mockup">
  <div class="mockup-bar">
    <div class="mockup-dots" aria-hidden="true"><span></span><span></span><span></span></div>
    <span class="mockup-url">app.ejemplo.com/ruta</span>
  </div>
  <div class="mockup-body">…</div>
</div>

<!-- Example box -->
<div class="example-box">
  <div class="example-label">Ejemplo práctico</div>
  <p>…</p>
</div>

<!-- Flujo con pills -->
<div class="flow">
  <span class="pill pill-stale"><del>$15</del></span>
  <span class="flow-arrow" aria-hidden="true">→</span>
  <span class="pill pill-success">$20</span>
</div>

<!-- Accordion -->
<details class="acc">
  <summary><span class="acc-num">Reglas</span>[Título del bloque]</summary>
  <div class="acc-body"><p>…</p></div>
</details>

<!-- Divider -->
<hr class="divider">
```
