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
    fontSize: 11px
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
    fontSize: 11px
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
  accordion-title:
    fontFamily: DM Sans
    fontSize: 16px
    fontWeight: 600
    lineHeight: 1.4
  toc-item:
    fontFamily: DM Sans
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.5
  back-to-top:
    fontFamily: DM Mono
    fontSize: 12px
    fontWeight: 500
  rail-preview-title:
    fontFamily: DM Sans
    fontSize: 13px
    fontWeight: 600
    lineHeight: 1.4

rounded:
  xs:   3px     # code inline
  sm:   4px     # badges
  md:   6px     # pills, chips de estado
  lg:   8px     # callouts, code blocks, accordions
  xl:   10px    # mockups, example boxes, cards grandes
  full: 9999px  # circular (step-circle, mockup dots)

spacing:
  # Todo padding, margin y gap sale de esta escala. Excepciones: 1–2px de chips
  # inline (badges, code inline) y geometría que no es espaciado (tamaños,
  # posición de la línea conectora de steps).
  xs:   4px
  sm:   6px
  md:   8px
  lg:   10px
  xl:   12px
  2xl:  16px
  3xl:  20px
  4xl:  24px
  5xl:  28px
  6xl:  32px
  7xl:  40px
  8xl:  48px
  9xl:  56px
  10xl: 80px

breakpoints:
  mobile: 720px   # por debajo: padding lateral 16px, tablas con scroll horizontal
  rail:   1024px  # por debajo no hay margen lateral para el mapa de secciones: se oculta

motion:
  # Movimiento funcional: solo responde a una acción del lector. Con
  # prefers-reduced-motion: reduce no hay transiciones y el scroll es instantáneo.
  # Variables CSS: --motion-<token> (check-design-tokens.sh las verifica).
  duration-fast:   120ms                          # hover, foco, subrayado de links
  duration-base:   200ms                          # abrir un accordion, aparecer el botón "Inicio"
  easing-standard: "cubic-bezier(0.2, 0, 0, 1)"   # entra rápido y se asienta, sin rebote

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

  # —— Índice (TOC) para documentos con 5+ secciones
  toc:
    padding:         "0"
    # elemento: <nav aria-labelledby>, margin-bottom: 40px, lista a 2 columnas (1 en mobile)
  toc-label:
    textColor:       "{colors.label}"
    typography:      "{typography.doc-label}"
  toc-item:
    textColor:       "{colors.primary}"
    typography:      "{typography.toc-item}"
    padding:         "4px 0"
    # link sin subrayado en reposo (navegación, no prosa); hover y foco lo muestran
  toc-num:
    textColor:       "{colors.label}"
    typography:      "{typography.section-num}"
    # mismo número que el section-num de destino

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
    padding:         "12px 16px"
    # border-left: 3px solid {colors.info-border}
  callout-warn:
    backgroundColor: "{colors.warn-bg}"
    textColor:       "{colors.warn-text}"
    typography:      "{typography.body-callout}"
    rounded:         "{rounded.lg}"
    padding:         "12px 16px"
    # border-left: 3px solid {colors.warn-border}
  callout-ok:
    backgroundColor: "{colors.ok-bg}"
    textColor:       "{colors.ok-text}"
    typography:      "{typography.body-callout}"
    rounded:         "{rounded.lg}"
    padding:         "12px 16px"
    # border-left: 3px solid {colors.ok-border}
  callout-red:
    backgroundColor: "{colors.red-bg}"
    textColor:       "{colors.red-text}"
    typography:      "{typography.body-callout}"
    rounded:         "{rounded.lg}"
    padding:         "12px 16px"
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
    padding:         "1px 6px"
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
    padding:         "16px 20px"
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
    typography:      "{typography.accordion-title}"  # un escalón debajo de section-title para no competir con él
    padding:         "12px 16px"
    # cursor: pointer; marcador nativo oculto; glifo +/– (DM Mono, color label) a la derecha
    # [open] agrega border-bottom: 1px solid {colors.border}
  accordion-num:
    textColor:       "{colors.label}"
    typography:      "{typography.section-num}"
    # label mono uppercase opcional dentro del summary (ej. "Reglas", "Checklist")
  accordion-body:
    textColor:       "{colors.body}"
    padding:         "12px 16px 4px"
    # al abrir: fade + translateY(-4px → 0) en {motion.duration-base}

  # —— Botón "Inicio" (volver al inicio, flotante)
  back-to-top:
    backgroundColor: "{colors.surface-dark}"
    textColor:       "{colors.surface-card}"
    typography:      "{typography.back-to-top}"
    rounded:         "{rounded.full}"
    padding:         "8px 16px"
    # position: fixed, right/bottom 24px (16px en mobile); aparece después de 480px de scroll
    # sombra mínima documentada; aparece con fade en {motion.duration-base}; oculto en impresión

  # —— Mapa de secciones (marcas laterales con vista previa)
  section-rail:
    padding:         "0"
    # position: fixed, left 24px, centrado vertical; <1024px e impresión: oculto
  section-rail-tick:
    backgroundColor: "{colors.label}"
    rounded:         "{rounded.full}"
    width:           "12px"
    height:          "2px"
    # área clickeable 48×10px; sección actual (aria-current): 24px y {colors.primary}
    # lupa: bajo el puntero o el foco llega a 40px y las vecinas crecen menos cuanto más lejos (radio 48px)
  section-rail-preview:
    backgroundColor: "{colors.surface-card}"
    rounded:         "{rounded.lg}"
    padding:         "12px 16px"
    # border: 1px solid {colors.border-strong}, width 280px, sombra mínima documentada
  section-rail-preview-num:
    textColor:       "{colors.label}"
    typography:      "{typography.section-num}"
  section-rail-preview-title:
    textColor:       "{colors.primary}"
    typography:      "{typography.rail-preview-title}"
    # una línea, ellipsis
  section-rail-preview-summary:
    textColor:       "{colors.muted}"
    typography:      "{typography.body-callout}"
    # primer párrafo de la sección, máximo 3 líneas
  section-rail-preview-hint:
    textColor:       "{colors.label}"
    typography:      "{typography.doc-meta}"
    # atajos de teclado al pie de la vista previa

  # —— Píldora de sección + índice en hoja inferior (todos los anchos)
  section-pill:
    backgroundColor: "{colors.surface-card}"
    textColor:       "{colors.primary}"
    typography:      "{typography.toc-item}"
    rounded:         "{rounded.full}"
    padding:         "8px 16px"
    # border: 1px solid {colors.border-strong}; fija abajo a la izquierda, 24px (16px en mobile); max-width 360px
  toc-sheet:
    backgroundColor: "{colors.surface-card}"
    padding:         "20px 24px 24px"
    # <dialog> modal pegado abajo, radio 10px arriba, max-height 70vh; fondo surface-dark al 32%

  # —— Copiar enlace a una sección
  section-link:
    textColor:       "{colors.link}"
    typography:      "{typography.doc-meta}"
    # dentro del section-num; visible al pasar por la sección, al enfocarlo y en pantallas táctiles

  # —— Novedades (sección nueva o actualizada)
  change-badge:
    # badge-amber con texto "Nuevo" / "Actualizado"; en el mapa, punto 4px {colors.warn-border}

  # —— Glosario
  term:
    # hereda el color del texto; subrayado punteado 1px {colors.label}, offset 3px
  term-card:
    backgroundColor: "{colors.surface-card}"
    rounded:         "{rounded.lg}"
    padding:         "12px 16px"
    # igual que section-rail-preview: título rail-preview-title, texto body-callout muted

  # —— Puntos sobre capturas
  hotspot:
    backgroundColor: "{colors.surface-dark}"
    textColor:       "{colors.surface-card}"
    typography:      "{typography.step-num}"
    rounded:         "{rounded.full}"
    width:           "24px"
    height:          "24px"
    # border: 2px solid {colors.surface-card} para separarse de cualquier captura
  hotspot-ref:
    backgroundColor: "{colors.surface-dark}"
    textColor:       "{colors.surface-card}"
    typography:      "{typography.badge}"
    rounded:         "{rounded.full}"
    width:           "20px"
    height:          "20px"

  # —— Comparación antes / después
  compare:
    backgroundColor: "{colors.surface-card}"
    rounded:         "{rounded.xl}"
    # border 1.5px {colors.border-strong}; divisor 2px {colors.surface-dark} con perilla circular 32px
  compare-labels:
    textColor:       "{colors.label}"
    typography:      "{typography.doc-label}"
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

El front matter es la **fuente de verdad**. El `:root` del boilerplate declara
una variable CSS por token, con el mismo nombre (`label` → `--label`) y el
mismo valor. Después de tocar un color en cualquiera de los dos lados, correr:

```bash
bash scripts/design/check-design-tokens.sh
```

Falla (exit `1`) si falta una variable, sobra una o un valor no coincide.

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

Si el documento se abre sin conexión, las fuentes caen a un stack de sistema
de métricas parecidas, no al `sans-serif` genérico:

- Sans: `'DM Sans', system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif`
- Mono: `'DM Mono', ui-monospace, 'SF Mono', Menlo, Consolas, monospace`

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
| `accordion-title` | 16px | 600 | Título del `summary` de un accordion |
| `toc-item` | 13px | 400 | Entradas del índice |
| `rail-preview-title` | 13px | 600 | Título en la vista previa del mapa de secciones |

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
| `table-header` | 11px | 500 | 0.10em | UPPERCASE |
| `badge` | 11px | 500 | 0.05em | mixed |

**11px es el piso** del sistema: ningún texto va más chico, ni siquiera en mono.
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
- Padding de callouts y example boxes: **`12–20px`**, nunca más.
- **Todo padding, margin y gap sale de la escala `spacing`** (4, 6, 8, 10, 12, 16, 20, 24, 28, 32, 40, 48, 56, 80). Solo quedan fuera los 1–2px de chips inline y la geometría que no es espaciado (tamaños de círculos y dots, posición de la línea conectora).

### Jerarquía estructural

Un documento típico se estructura así, de arriba a abajo:

```
doc-header           ← encabezado completo del documento (<header>, título en <h1>)
[toc]                ← (opcional, 5+ secciones) índice con links a cada sección
[section-rail]       ← (opcional, va con el índice) mapa lateral fijo, lo arma el script
[section-pill]       ← (opcional, va con el mapa) sección actual + índice en hoja
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

## Motion

El movimiento sigue la misma regla que la profundidad: **funcional y casi
imperceptible**. Un documento Heritage es papel; lo que se mueve solo confirma
que el lector hizo algo, nunca decora.

| Token | Valor | Uso |
| --- | --- | --- |
| `motion.duration-fast` | 120ms | Hover y foco: color, borde, grosor del subrayado |
| `motion.duration-base` | 200ms | Abrir un accordion, aparecer el botón "Inicio" |
| `motion.easing-standard` | `cubic-bezier(0.2, 0, 0, 1)` | Todas las transiciones: entra rápido y se asienta sin rebote |

**Qué se anima**

- Cambios de estado ante una acción: color, borde, opacidad y grosor del subrayado.
- La apertura de un bloque (accordion): el cuerpo aparece con fade y un desplazamiento de 4px.
- El scroll dentro de la página: índice, mapa de secciones y botón "Inicio" con scroll suave.
- La vista previa del mapa de secciones: aparece con fade en `motion.duration-fast`.
- La lupa del mapa de secciones cambia el largo de las marcas sin transición: sigue al puntero
  cuadro a cuadro, así que es manipulación directa y no una animación. Lo mismo vale para el
  divisor de la comparación antes / después.
- La hoja del índice (pantallas angostas) sube con fade y `translateY(4px → 0)` en
  `motion.duration-base`.

**Qué no se anima**

- Nada que el lector no haya pedido: sin entradas al scrollear, sin parallax, sin loops ni autoplay.
- Sin rebotes, escalas, rotaciones ni `box-shadow`: rompen la estética de papel.
- Sin `height` o `max-height` animados en contenido largo: provocan saltos de layout.
- Mockups y su contenido quedan quietos: muestran una pantalla, no una demo.

**Reglas**

- Solo `opacity`, `transform: translateY()` de hasta 4px y propiedades de color.
- Ninguna transición supera `motion.duration-base` (200ms).
- Todo el movimiento va dentro de `@media (prefers-reduced-motion: no-preference)`: con
  "reducir movimiento" activo no hay transiciones y el scroll es instantáneo.
- En impresión no hay transiciones ni animaciones.

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

### Índice (TOC)

Navegación para documentos con **5 o más secciones**; con menos, sobra. Va
inmediatamente después del `doc-header`. Estructura:

```
[toc-label]   "CONTENIDO" — mono uppercase
[toc-list]    01 Título de la sección   05 Título de la sección
              02 …                      06 …
```

- `<nav class="toc" aria-labelledby="toc-label">` con una `<ol>` a dos columnas (una en mobile).
- Cada entrada es un link al `id` del `section-title`, con el número en `toc-num` (mono, color `label`) y el título en `toc-item`.
- Es navegación, no prosa: el link va sin subrayado en reposo y lo muestra en hover y foco.
- **Scroll suave** hasta la sección con el script de navegación del boilerplate: alinea la
  `<section>` completa (número incluido) 16px debajo del borde, mueve el foco al título y
  actualiza el hash. Si el contenido de arriba cambia de alto mientras scrollea (imágenes o
  capturas diferidas), corrige la posición hasta que el layout se asienta.
- Si el documento tiene `part-header`, la parte se indica como un `toc-label` más dentro de la lista, sin link.
- Sin borde ni fondo: el índice no es una pieza encajada, es parte del flujo.

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

- **Inline (`<code>`)**: fondo `{colors.surface-alt}`, padding `1px 6px`, radius `3px`. Para nombres de archivo, identificadores, valores literales en prosa.
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
`{colors.surface-card}`. Lleva `isolation: isolate`: las capturas reales traen capas con `z-index`
alto (modales, menús) que, sin aislar, taparían el botón "Inicio", la píldora y el mapa. Los dots usan `red-border`, `warn-border` y
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
hover el subrayado pasa a `2px`, con transición de `motion.duration-fast`. Nunca
quitar el subrayado en prosa: el color solo no distingue un link del texto. Única excepción: el índice (TOC), donde
el contexto ya indica que todo es navegable. Links externos con texto descriptivo, no
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
- El `summary` usa `accordion-title` (16/600), un escalón por debajo de `section-title` para que el título de la sección siga mandando, y **sin** borde inferior; el marcador nativo se oculta y se reemplaza por un glifo `+` (cerrado) / `–` (abierto) en mono, color `label`, alineado a la derecha.
- Al abrir (`[open]`), el `summary` cierra con `border-bottom: 1px solid {colors.border}` para separar del cuerpo.
- Opcional: un `accordion-num` (mono uppercase, color `label`) al inicio del summary como mini-etiqueta del bloque (`Reglas`, `Comportamiento`, `Checklist`), en el mismo espíritu que `section-num`.
- El `summary` es focuseable con teclado: nunca quitarle el `:focus-visible`.
- **Al abrir**, el `acc-body` aparece con fade y `translateY(-4px → 0)` en `motion.duration-base`.
  `<details>` nativo no anima la altura, y no se fuerza: el cierre es instantáneo.

**Regla de uso:** colapsar los bloques de **referencia** (reglas de negocio,
comportamiento esperado, casos de error, checklist) y dejar **siempre abiertos**
los de **acción** (intro/objetivo, flujo en `steps`, mockups). No anidar
accordions ni meter un mockup pesado adentro de uno cerrado. Si una sección no
es densa, no la colapses — el accordion es para domar volumen, no decoración.

### Botón "Inicio" (volver al inicio)

Botón flotante para documentos largos: vuelve al principio sin que el lector
tenga que scrollear todo de nuevo. Usarlo junto con el índice.

- `<a class="back-to-top" href="#top" aria-label="Volver al inicio" hidden>` con `↑` decorativo (`aria-hidden="true"`) y el texto **Inicio**.
- El `doc-header` lleva `id="top"` y `tabindex="-1"` para recibir el foco después del salto.
- Fijo abajo a la derecha (24px; 16px en mobile), fondo `surface-dark`, texto `surface-card`, mono 12/500, radio circular y la sombra mínima documentada.
- Está oculto (`hidden`) hasta los primeros 480px de scroll; aparece con fade en `motion.duration-base`. Al ocultarse desaparece sin transición, para no quedar clickeable mientras se desvanece.
- Scroll suave hasta `0`, no hasta la posición del header, porque el header tiene margen superior.
- Funciona dentro de visores embebidos que scrollean un iframe (por ejemplo Grid): usa `window` del propio documento.
- No se imprime.

### Mapa de secciones

Atajo lateral para documentos largos: una marca corta por sección, fija a la
izquierda de la página. Al pasar el mouse o enfocar una marca aparece una vista
previa con el número, el título y el comienzo de la sección; al hacer click,
salta a ella. Complementa al índice: el índice se lee una vez arriba, el mapa
queda a mano mientras se lee. Usarlo junto con el índice y el botón "Inicio".

```
 ─
 ──
 ───            ┌──────────────────────────────────┐
 ━━━━━  ←────── │ 03                               │
 ───            │ Quién ve qué                     │
 ──             │ La sección muestra a cada        │
 ─              │ operador solo lo que …           │
 ─              └──────────────────────────────────┘
```

- Markup: solo `<nav class="section-rail" aria-label="Mapa de secciones" hidden></nav>` antes de
  `</body>`. El script de navegación del boilerplate lo arma: una marca por cada `section.section`
  con `section-title` e `id`, y lo muestra si hay 2 o más. **No se escribe a mano**, así que no se
  desalinea cuando cambian las secciones.
- Cada marca es un link al `id` del `section-title`, con `aria-label` "número + título". Usa el
  mismo scroll que el índice: sección completa 16px debajo del borde, foco en el título, hash
  actualizado y `heritage:before-scroll`.
- Marca en reposo: `12×2px`, color `label`. **Sección actual** (`aria-current="location"`, la
  última cuyo borde superior pasó el 30% de la ventana, o la última al llegar al final): `24px` y
  color `primary`. El largo marca el estado, no solo el color.
- **Lupa:** con el puntero sobre el mapa, la marca más cercana llega a `40px` y color `primary`, y
  las vecinas crecen menos cuanto más lejos están, hasta volver a `12px` a `48px` del puntero (unas
  4 marcas por lado, caída en coseno). Sigue la posición vertical del puntero, no solo la marca
  bajo él. Con el foco del teclado la lupa se centra en la marca enfocada. La sección actual nunca
  baja de `24px`. Al salir del mapa todo vuelve al reposo.
- Vista previa: `surface-card`, borde `1px` `border-strong`, radio `8px`, `280px` de ancho, la
  sombra mínima documentada. Muestra `section-num`, el título en una línea y el primer párrafo de
  la sección (hasta 3 líneas). Es decorativa (`aria-hidden="true"`, sin eventos del puntero): el
  nombre accesible ya está en el link. Se centra en la marca y no se sale de la ventana.
- Se oculta por debajo de `1024px` (breakpoint `rail`), donde no queda margen al costado del
  texto, y en impresión. Sin JavaScript no aparece.
- **Progreso:** la marca de la sección actual se llena de `primary` de izquierda a derecha a medida
  que se lee (`--tick-progress`); lo que falta queda en `label`.
- **Leídas:** una sección pasa a leída cuando se recorre el 90% siendo la actual, cuando se pasa
  scrolleando a la siguiente, o al llegar al final del documento. Saltar con el índice o el mapa
  no la marca. Su marca queda en `primary` (en reposo, `label`), su `aria-label` suma
  "leída" y la vista previa muestra `Leída`. Se recuerda por documento en `localStorage`
  (`heritage:visited:<ruta>|<título>`); si el visor lo bloquea, dura la visita.
- **Novedades:** una sección con `data-change` lleva un punto `4px` `warn-border` al lado de la
  marca, y el badge en la vista previa (ver [Novedades](#novedades)).
- **Atajos:** el pie de la vista previa los recuerda (`⌥ ↑ ↓ secciones · ⌥ I índice`, `Alt` fuera
  de Mac). Ver [Atajos de teclado](#atajos-de-teclado).

### Píldora de sección

Píldora fija abajo a la izquierda con la sección actual (`03 · Quién ve qué`); al tocarla abre el
índice en una hoja inferior. Se ve en todos los anchos: en desktop acompaña al mapa (dice dónde
estás sin pasar el mouse) y por debajo de `1024px`, incluido el iframe angosto de Grid, es el único
atajo de navegación.

```
┌─────────────────────────────────────┐
│ …                                   │
│ ╭──────────────────╮   ╭──────────╮ │
│ │ 03  Quién ve qué │   │ ↑ Inicio │ │
│ ╰──────────────────╯   ╰──────────╯ │
└─────────────────────────────────────┘
```

- Markup fijo (`button.section-pill` + `dialog.toc-sheet`, ver snippets); el script completa la
  sección actual y copia el índice adentro de la hoja, con sus etiquetas de parte y novedades. Si
  no hay índice, arma la lista desde las secciones.
- Aparece junto con el botón "Inicio" (después de 480px de scroll) y deja lugar para él: el título
  se corta con ellipsis (máximo `360px`).
- La hoja es un `<dialog>` modal: atrapa el foco, cierra con `Escape`, con "Cerrar" o tocando el
  fondo, y devuelve el foco a la píldora. La sección actual va en negrita
  (`aria-current="location"`). Al elegir una entrada cierra y scrollea como el índice.
- `aria-label` de la píldora: "Sección actual: 03 Quién ve qué. Abrir índice".
- No se imprime.

### Copiar enlace a una sección

Cada `section-num` suma un botón "Copiar enlace" a la derecha. Sirve para responder un ticket con
el link directo a la sección.

- Lo agrega el script; no se escribe a mano. Visible al pasar por la sección o al enfocarlo, y
  siempre en pantallas táctiles (`hover: none`).
- Copia `<URL base>#<id del section-title>`. En visores embebidos (Grid) la URL del iframe no es
  la que ve el lector: declarar la pública con `<meta name="heritage:share-url" content="…">`.
- Confirma con "Enlace copiado" en el botón y en una región `role="status"`. Si el visor bloquea
  el portapapeles, dice "No se pudo copiar" y deja un `console.warn` con el `id` de la sección.

### Novedades

Cuando un documento se actualiza, marca qué cambió para que el lector recurrente vaya directo a eso.

- Se declara **una vez**, en la sección: `<section class="section" data-change="new">` (Nuevo) o
  `data-change="updated"` (Actualizado). El script pone el badge `b-amber` junto al `section-num` y
  lo replica en el índice, la hoja, el mapa y la vista previa.
- Solo para cambios que el lector necesita ver; una corrección de tipeo no es novedad.
- En la primera versión de un documento no se usa: todo sería nuevo.
- Conviene resumirlas en el `doc-meta` (`Novedades: 2 secciones`).

### Glosario

Términos del dominio con su definición a mano, sin salir del párrafo.

```html
<p>Los usuarios con <a class="term" href="#g-ldap-externo">LDAP externo</a> no ven …</p>
…
<dl class="glossary">
  <dt id="g-ldap-externo">LDAP externo</dt>
  <dd>Cuenta de una persona que no es empleada; empieza con <code>ext_</code>.</dd>
</dl>
```

- La definición vive **una sola vez**, en la `<dl class="glossary">` (normalmente una sección
  "Glosario" al final). El término es un link a su `<dt>`: sin JavaScript igual lleva a la
  definición.
- Con JavaScript, al pasar o enfocar el término aparece una tarjeta con el término y la definición,
  debajo (o arriba si no entra). Se puede recorrer con el puntero sin que se cierre y `Escape` la
  cierra (WCAG 1.4.13). El término recibe `aria-describedby` hacia su `<dd>`.
- Estilo: hereda el color del texto, subrayado punteado `label`; así no se confunde con un link
  común. Marcar solo la primera aparición de cada término por sección.
- Ids con prefijo `g-` en kebab-case.

### Puntos sobre capturas

Círculos numerados encima de una captura o mockup que conectan la imagen con los pasos.

```
┌ mockup ─────────────────────────┐      ①  Abrí el menú
│  [≡]①        Buscar …   [⚙]②   │      ②  Elegí "Filtrar"
└─────────────────────────────────┘
```

- `div.hotspot-stage` envuelve el contenido de la captura (`app-frame` o `mockup-body`) y lleva
  los `span.hotspot` con `data-hotspot="1"` y posición en porcentaje (`style="--x:12%;--y:30%"`).
  Ajustar las posiciones mirando la captura renderizada.
- Los pasos (`li.step-item`) y las referencias en el texto (`span.hotspot-ref`) llevan el mismo
  `data-hotspot`. El número del punto coincide con el del paso.
- Al pasar por un paso, una referencia o un punto, se resaltan los que comparten número (anillo
  `focus-ring`) y los demás puntos de la sección bajan a 40% de opacidad.
- Los puntos son `aria-hidden="true"`: el texto del paso lleva la información. En la referencia,
  el texto oculto `punto` le da contexto al lector de pantalla.
- Máximo 6 puntos por captura; más, y la captura deja de leerse.
- Se imprimen.

### Comparación antes / después

Dos capturas superpuestas con un divisor que se arrastra. Para "¿Qué cambió?".

- `div.compare` > `div.compare-stage` con `div.compare-before`, `div.compare-after`,
  `div.compare-handle` y un `input.compare-range` nativo (0–100) que cubre la imagen; debajo,
  `div.compare-labels` con "Antes" y "Después".
- El divisor sigue al puntero o al dedo; con teclado se mueve con las flechas del range, que
  anuncia `aria-valuetext` ("Antes 50%, después 50%"). El foco muestra el anillo alrededor.
- `compare-stage` también lleva `isolation: isolate`, como el mockup.
- Las dos capturas deben tener el mismo ancho y encuadre; si no, no se pueden comparar y van como
  dos mockups.
- Cada `app-frame` dentro de una comparación lleva su `aria-label` ("Captura de pantalla: antes,
  …"), porque no tiene mockup del que tomarlo.
- En impresión se ven lado a lado, sin divisor.

### Atajos de teclado

- `Alt` + `↓` / `↑` (`⌥` en Mac): sección siguiente / anterior. `Alt` + `I`: índice.
- Llevan modificador para no chocar con lectores de pantalla ni con la escritura (WCAG 2.1.4), y
  se ignoran dentro de campos, con la hoja del índice abierta o con otro modificador.
- `Escape` cierra la vista previa del mapa y la tarjeta del glosario.
- Usan el mismo scroll que el índice.

## Accesibilidad

- **Contraste**: todo texto cumple ≥4.5:1 sobre su superficie; bordes con significado y el anillo de foco, ≥3:1. Valores medidos: `label` 4.56–5.33:1, `muted` ≥6.38:1, textos de callout 5.8–7.7:1, `syntax-comment` 4.93:1.
- **Semántica**: `<header>` + `<h1>` para el doc-header, `<section>` + `<h2>` por sección, `<ol>` para steps, `<th scope="col">` en tablas, `<details>/<summary>` para accordions.
- **Foco**: `:focus-visible` con `outline: 2px solid {colors.focus-ring}` y `outline-offset: 2px` en links y summaries. Nunca `outline: none` sin reemplazo.
- **Color no es el único canal**: callouts con palabra clave inicial, badges con texto, links subrayados, estados viejos con `<del>`.
- **Decoración oculta**: dots del mockup, flechas de flujo, números de step-circle, la flecha del botón "Inicio" y la vista previa del mapa de secciones llevan `aria-hidden="true"`.
- **Contenido al pasar el mouse**: la tarjeta del glosario se puede recorrer con el puntero, cierra con `Escape` y su contenido también existe en la página (WCAG 1.4.13). La vista previa del mapa es decorativa y cierra con `Escape`.
- **Atajos**: siempre con modificador (`Alt`/`⌥`), nunca una tecla sola (WCAG 2.1.4).
- **Movimiento**: todo el motion va dentro de `@media (prefers-reduced-motion: no-preference)`; con "reducir movimiento" el scroll es instantáneo y no hay transiciones. Después de un salto por el índice o el botón "Inicio", el foco queda en el destino.
- **Idioma**: `<html lang="es">`; fragmentos en otro idioma con `lang` propio si son prosa (no hace falta para código).

## Impresión

El documento debe imprimirse (o exportarse a PDF) sin perder jerarquía:

- Fondo blanco y sin padding de página: el limestone no se imprime bien y el navegador lo descarta por defecto.
- `break-inside: avoid` en callouts, example boxes, mockups, steps, code blocks y filas de tabla; `break-after: avoid` en títulos.
- Los accordions se abren antes de imprimir (snippet `beforeprint` del boilerplate); el glifo `+/–` se oculta.
- Los links muestran su URL entre paréntesis después del texto.
- Sin transiciones ni animaciones, sin botón "Inicio", mapa de secciones, píldora, botones de copiar enlace ni tarjetas del glosario.
- Las comparaciones antes / después se imprimen lado a lado; los puntos sobre capturas, sí.

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
- **Animá solo respuestas a una acción del lector** (hover, foco, abrir, navegar), con los tokens `motion` y dentro de `prefers-reduced-motion: no-preference`.

### Don't

- **No uses sombras pesadas.** Bordes finos y cambios de superficie son suficientes.
- **No mezcles paletas de color** (verde brillante, rojo Material, azul Bootstrap). El sistema tiene cuatro acentos apagados; cualquier color fuera de la paleta rompe la estética.
- **No uses pesos `700+` de DM Sans**, ni cursivas marcadas. La sobriedad se rompe rápido con tipografía dramática.
- **No anides callouts dentro de callouts** ni callouts dentro de tablas.
- **No uses iconos decorativos** (emojis, lucide a granel). El sistema confía en tipografía y color. Excepción: un emoji muy puntual dentro de un title de step (📦, 🎯) si suma información concreta.
- **No agregues efectos hover llamativos** en documentos estáticos. Si el doc es interactivo, los hovers deben ser cambios sutiles de borde o fondo, nunca elevación dramática.
- **No animes la entrada de contenido al scrollear**, ni uses rebotes, escalas, parallax o duraciones de más de 200ms.
- **No uses fondos blancos puros para el body** en pantalla. El `#F8F7F4` está calibrado para que `surface-card` (blanco) destaque por encima. (En impresión sí se usa blanco.)
- **No uses más de un `doc-title` por archivo.** Para sub-documentos, usar `part-header`.
- **No uses grises más claros que `label`** para texto, ni los `*-border` como color de texto.

## Checklist de conformidad

Antes de entregar o aprobar un documento con este sistema:

- [ ] Un solo `<h1 class="doc-title">`; secciones numeradas con `<h2 class="section-title">`.
- [ ] Solo colores del front matter, referenciados por variable CSS; `check-design-tokens.sh` pasa si se tocó la paleta.
- [ ] Solo DM Sans (400/500/600) y DM Mono (400/500), con su stack de fallback; ningún peso 700 ni texto <11px.
- [ ] Paddings, margins y gaps dentro de la escala `spacing`.
- [ ] Índice (TOC) presente si hay 5 o más secciones.
- [ ] Toda tabla dentro de `.table-wrap`, headers con `scope="col"`.
- [ ] Callouts elegidos por significado y con palabra clave inicial; ninguno anidado.
- [ ] Badges con texto legible sin color; sin emojis.
- [ ] Accordions solo en bloques de referencia; intro, steps y mockups abiertos.
- [ ] Sin sombras (salvo la mínima documentada) ni redondeos >10px no circulares.
- [ ] Sin scroll horizontal de página a 360px de ancho.
- [ ] Vista previa de impresión legible: accordions abiertos, bloques sin cortar.
- [ ] Todo el movimiento está dentro de `prefers-reduced-motion: no-preference`, usa los tokens `motion` y ninguna transición dura más de 200ms.
- [ ] Si hay índice, sus links llevan a la sección completa (número visible) también en el visor final; el botón "Inicio" vuelve a `scrollY` 0.
- [ ] Si hay mapa de secciones: una marca por sección a 1024px o más, la lupa agranda la marca bajo el puntero y achica en forma gradual a las vecinas, la vista previa muestra número, título y primer párrafo sin salirse de la ventana, la marca actual sigue al scroll y el click lleva a la sección completa.
- [ ] La píldora muestra la sección actual y abre la hoja con el índice; la hoja cierra con `Escape` y devuelve el foco.
- [ ] `data-change` solo en secciones que cambiaron desde la versión anterior; el badge aparece en sección, índice y mapa.
- [ ] Cada `a.term` apunta a un `<dt>` existente y su tarjeta muestra la definición.
- [ ] Los `data-hotspot` de puntos, pasos y referencias coinciden, y cada punto cae sobre el elemento correcto de la captura renderizada.
- [ ] Las comparaciones usan capturas del mismo ancho y encuadre, y el divisor se mueve con mouse y teclado.

## Changelog

Cambios que alteran cómo se ve o se escribe un documento. Los documentos
viejos siguen funcionando: los nombres de clase no cambiaron.

### 2026-10-01

- **Componentes:** mapa de secciones (`section-rail`): marcas laterales fijas, una por sección, con vista previa al pasar el mouse o enfocar, efecto lupa sobre las marcas vecinas, sección actual resaltada y el mismo scroll que el índice. Lo arma el script de navegación.
- **Mapa de secciones:** progreso de lectura en la marca actual, secciones leídas recordadas por documento y atajos al pie de la vista previa.
- **Componentes:** píldora de sección con índice en hoja inferior (todos los anchos), copiar enlace a una sección, novedades (`data-change`), glosario con tarjeta (`a.term` + `dl.glossary`), puntos sobre capturas (`hotspot`) y comparación antes / después (`compare`).
- **Teclado:** `Alt`/`⌥` + `↑` `↓` cambia de sección, `Alt`/`⌥` + `I` va al índice, `Escape` cierra las vistas previas.
- **Tokens:** tipografía `rail-preview-title` y breakpoint `rail` (1024px).

### 2026-09-28

- **Motion:** nuevos tokens `motion` (`duration-fast`, `duration-base`, `easing-standard`) con sus variables `--motion-*`, verificadas por `check-design-tokens.sh`. Sección nueva con qué se anima y qué no.
- **Componentes:** botón "Inicio" (volver al inicio) y script de navegación: scroll suave del índice y del botón, alineación de la sección completa y corrección por contenido diferido (evento `heritage:before-scroll`).
- **Transiciones:** subrayado de links, apertura del accordion y aparición del botón "Inicio", todo bajo `prefers-reduced-motion: no-preference` y apagado en impresión.

### 2026-09-27

- **Contraste:** `label` pasa de `#888888` a `#6B6B6B` y `syntax-comment` de `#64748B` a `#7C8BA1` para cumplir WCAG AA. Nuevos tokens `link`, `focus-ring` y `border-neutral`.
- **Tipografía:** `table-header` y `badge` suben de 10px a 11px (nuevo piso). Nuevo token `accordion-title` (16/600): el `summary` deja de usar el tamaño de `section-title`. Stack de fallback de sistema para ambas familias.
- **Spacing:** la escala suma 10, 32 y 56px y se renombra en orden; los paddings fuera de escala se ajustan (callouts `12px 16px`, example box `16px 20px`, accordion `12px 16px`, code inline `1px 6px`, indentación de listas `24px`).
- **Componentes nuevos:** índice (TOC), estilos de link, `mockup-body` y `.table-wrap`.
- **Boilerplate:** HTML semántico (`<h1>`, `<h2>`, `<section>`, `<ol>`), variables CSS con el mismo nombre que los tokens, CSS de todos los componentes, foco visible, breakpoint mobile e impresión.
- **Tooling:** `scripts/design/check-design-tokens.sh` verifica que front matter y `:root` no se desalineen.

### 2026-06-26

- Componente accordion para documentos densos.

### 2026-05-25

- Versión inicial del sistema.

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
  --background:#f8f7f4;--surface-alt:#f0ede6;--surface-card:#fff;
  --border:#e0ddd6;--border-strong:#d0cdc6;--border-neutral:#ccc;--border-ink:#1a1a1a;
  --surface-dark:#1a1a2e;--on-dark:#e2e8f0;
  --info-bg:#eaf3fb;--info-border:#5a9fd4;--info-text:#1a4f7a;
  --warn-bg:#fdf5e0;--warn-border:#d4a44c;--warn-text:#7a5510;
  --ok-bg:#e8f7f2;--ok-border:#4aaa8c;--ok-text:#1a6b52;
  --red-bg:#fef8f6;--red-border:#e8917a;--red-text:#9e3d25;
  --syntax-comment:#7c8ba1;--syntax-keyword:#7dd3fc;--syntax-string:#86efac;
  --syntax-number:#fbbf24;--syntax-function:#c084fc;--syntax-tag:#f9a8d4;
  --sans:'DM Sans',system-ui,-apple-system,'Segoe UI',Roboto,sans-serif;
  --mono:'DM Mono',ui-monospace,'SF Mono',Menlo,Consolas,monospace;
  --motion-duration-fast:120ms;--motion-duration-base:200ms;--motion-easing-standard:cubic-bezier(0.2, 0, 0, 1);
}
*{box-sizing:border-box;margin:0;padding:0;}
body{font-family:var(--sans);background:var(--background);color:var(--primary);padding:48px 24px 80px;max-width:860px;margin:0 auto;}
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
ul,ol{padding-left:24px;margin-bottom:12px;}
li{font-size:14px;line-height:1.7;color:var(--body);margin-bottom:6px;}
strong{color:var(--primary);}
a{color:var(--link);text-decoration:underline;text-decoration-thickness:1px;text-underline-offset:2px;}
a:hover{text-decoration-thickness:2px;}
:focus-visible{outline:2px solid var(--focus-ring);outline-offset:2px;border-radius:2px;}
.callout{border-radius:8px;padding:12px 16px;margin:16px 0;font-size:13px;line-height:1.6;border-left:3px solid;}
.callout p,.callout li{font-size:inherit;line-height:inherit;color:inherit;}
.callout strong{color:inherit;}
.callout>:last-child{margin-bottom:0;}
.c-info{background:var(--info-bg);border-color:var(--info-border);color:var(--info-text);}
.c-warn{background:var(--warn-bg);border-color:var(--warn-border);color:var(--warn-text);}
.c-ok{background:var(--ok-bg);border-color:var(--ok-border);color:var(--ok-text);}
.c-red{background:var(--red-bg);border-color:var(--red-border);color:var(--red-text);}
.table-wrap{overflow-x:auto;margin:16px 0;}
table{width:100%;border-collapse:collapse;font-size:13px;}
th{font-family:var(--mono);font-size:11px;font-weight:500;letter-spacing:0.1em;text-transform:uppercase;color:var(--label);text-align:left;padding:8px 12px;border-bottom:1px solid var(--border);background:var(--surface-alt);}
td{padding:10px 12px;border-bottom:1px solid var(--border);vertical-align:top;line-height:1.5;color:var(--body);}
tr:last-child td{border-bottom:none;}
.badge{display:inline-block;font-family:var(--mono);font-size:11px;font-weight:500;padding:2px 8px;border-radius:4px;letter-spacing:0.05em;border:1px solid;white-space:nowrap;}
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
code{font-family:var(--mono);background:var(--surface-alt);color:var(--primary);padding:1px 6px;border-radius:3px;font-size:12px;}
.code-block{background:var(--surface-dark);border-radius:8px;padding:20px 24px;margin:16px 0;overflow-x:auto;}
.code-block pre{font-family:var(--mono);font-size:12px;line-height:1.7;color:var(--on-dark);white-space:pre;}
.c-comment{color:var(--syntax-comment);} .c-key{color:var(--syntax-keyword);} .c-str{color:var(--syntax-string);}
.c-num{color:var(--syntax-number);} .c-fn{color:var(--syntax-function);} .c-tag{color:var(--syntax-tag);}
.mockup{background:var(--surface-card);border:1.5px solid var(--border-strong);border-radius:10px;overflow:hidden;margin:16px 0;isolation:isolate;}
.mockup-bar{display:flex;align-items:center;gap:12px;padding:10px 16px;background:var(--surface-alt);border-bottom:1px solid var(--border-strong);font-family:var(--mono);font-size:11px;color:var(--label);}
.mockup-dots{display:flex;gap:6px;flex-shrink:0;}
.mockup-dots span{width:10px;height:10px;border-radius:50%;}
.mockup-dots span:nth-child(1){background:var(--red-border);}
.mockup-dots span:nth-child(2){background:var(--warn-border);}
.mockup-dots span:nth-child(3){background:var(--ok-border);}
.mockup-url{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}
.mockup-body{padding:20px;}
.example-box{background:var(--surface-card);border:1.5px solid var(--border-strong);border-radius:10px;padding:16px 20px;margin:16px 0;}
.example-box>:last-child{margin-bottom:0;}
.flow{display:flex;flex-wrap:wrap;align-items:center;gap:8px;margin:16px 0;}
.flow-arrow{font-family:var(--mono);color:var(--label);}
.pill{display:inline-block;font-family:var(--mono);font-size:12px;padding:6px 12px;border-radius:6px;border:1px solid var(--border-strong);}
.pill-neutral{background:var(--surface-alt);color:var(--primary);}
.pill-success{background:var(--ok-bg);color:var(--ok-text);border-color:var(--ok-border);}
.pill-stale{background:var(--surface-alt);color:var(--red-text);text-decoration:line-through;}
.pill-stale del{text-decoration:inherit;}
.toc{margin-bottom:40px;}
.toc-label{font-family:var(--mono);font-size:11px;font-weight:500;letter-spacing:0.14em;text-transform:uppercase;color:var(--label);margin-bottom:8px;}
.toc ol{list-style:none;padding:0;margin:0;columns:2;column-gap:40px;}
.toc li{break-inside:avoid;margin:0;}
.toc li .toc-label{margin:12px 0 4px;}
.toc a{display:flex;align-items:baseline;gap:10px;padding:4px 0;font-size:13px;line-height:1.5;color:var(--primary);text-decoration:none;}
.toc a:hover{text-decoration:underline;text-underline-offset:2px;}
.toc-num{font-family:var(--mono);font-size:11px;font-weight:500;letter-spacing:0.12em;color:var(--label);flex-shrink:0;}
.divider{height:1px;background:var(--border);border:0;margin:28px 0;}
.acc{background:var(--surface-card);border:1px solid var(--border);border-radius:8px;margin-bottom:10px;overflow:hidden;}
.acc>summary{list-style:none;display:flex;align-items:baseline;gap:10px;padding:12px 16px;cursor:pointer;font-size:16px;font-weight:600;line-height:1.4;color:var(--primary);}
.acc>summary::-webkit-details-marker{display:none;}
.acc>summary::after{content:'+';margin-left:auto;font-family:var(--mono);font-size:16px;font-weight:400;color:var(--label);}
.acc[open]>summary{border-bottom:1px solid var(--border);}
.acc[open]>summary::after{content:'–';}
.acc>summary:focus-visible{outline-offset:-2px;}
.acc-body{padding:12px 16px 4px;color:var(--body);}
.back-to-top{position:fixed;right:24px;bottom:24px;display:inline-flex;align-items:center;gap:6px;padding:8px 16px;border-radius:9999px;background:var(--surface-dark);color:var(--surface-card);font-family:var(--mono);font-size:12px;font-weight:500;text-decoration:none;box-shadow:0 1px 2px rgba(0,0,0,0.04);z-index:10;}
.back-to-top:hover{text-decoration:underline;text-underline-offset:2px;}
.back-to-top[hidden]{display:none;}
.section-num{display:flex;align-items:center;gap:8px;}
.change-badge{text-transform:none;}
.toc a .change-badge{margin-left:4px;}
.visually-hidden{position:absolute;width:1px;height:1px;margin:-1px;padding:0;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap;border:0;}
.section-link{margin-left:auto;padding:2px 4px;border:0;background:none;font-family:var(--mono);font-size:11px;font-weight:500;letter-spacing:0.05em;text-transform:none;color:var(--link);text-decoration:underline;text-underline-offset:2px;cursor:pointer;opacity:0;}
.section:hover .section-link,.section-link:focus-visible,.section-link.is-copied{opacity:1;}
.section-rail{position:fixed;left:24px;top:50%;transform:translateY(-50%);z-index:10;}
.section-rail[hidden],.section-rail-preview[hidden],.section-rail-preview [hidden],.term-card[hidden],.section-pill[hidden]{display:none;}
.section-rail ol{list-style:none;padding:0;margin:0;}
.section-rail li{margin:0;}
.section-rail-tick{display:flex;align-items:center;gap:4px;width:48px;padding:4px 0;}
.section-rail-tick::before{content:'';flex-shrink:0;width:var(--tick-width,12px);height:2px;border-radius:9999px;background:var(--label);}
.section-rail-tick.is-visited::before,.section-rail-tick:hover::before,.section-rail-tick:focus-visible::before{background:var(--primary);}
.section-rail-tick[aria-current="location"]::before{width:var(--tick-width,24px);background:linear-gradient(90deg,var(--primary) var(--tick-progress,0%),var(--label) 0);}
.section-rail-tick[data-change]::after{content:'';flex-shrink:0;width:4px;height:4px;border-radius:9999px;background:var(--warn-border);}
.section-rail-preview,.term-card{position:fixed;z-index:11;width:280px;max-width:calc(100vw - 32px);padding:12px 16px;background:var(--surface-card);border:1px solid var(--border-strong);border-radius:8px;box-shadow:0 1px 2px rgba(0,0,0,0.04);}
.section-rail-preview{left:88px;pointer-events:none;}
.section-rail-preview-meta{display:flex;align-items:center;gap:8px;margin-bottom:4px;}
.section-rail-preview-meta:empty{display:none;}
.section-rail-preview-num{font-family:var(--mono);font-size:11px;font-weight:500;letter-spacing:0.12em;text-transform:uppercase;color:var(--label);}
.section-rail-preview-state{margin-left:auto;font-family:var(--mono);font-size:11px;color:var(--label);}
.section-rail-preview-title,.term-card-title{font-size:13px;font-weight:600;line-height:1.4;color:var(--primary);}
.section-rail-preview-title{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}
.section-rail-preview-summary,.term-card-text{margin-top:4px;font-size:13px;line-height:1.6;color:var(--muted);}
.section-rail-preview-summary{display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden;}
.section-rail-preview-hint{margin-top:8px;font-family:var(--mono);font-size:11px;color:var(--label);}
.section-pill{position:fixed;left:24px;bottom:24px;z-index:10;display:inline-flex;align-items:center;gap:8px;max-width:min(360px, calc(100vw - 168px));padding:8px 16px;border:1px solid var(--border-strong);border-radius:9999px;background:var(--surface-card);color:var(--primary);font-family:var(--sans);font-size:13px;line-height:1.4;cursor:pointer;box-shadow:0 1px 2px rgba(0,0,0,0.04);}
.section-pill-num{flex-shrink:0;font-family:var(--mono);font-size:11px;font-weight:500;letter-spacing:0.12em;color:var(--label);}
.section-pill-title{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}
.toc-sheet{position:fixed;inset:auto 0 0 0;width:100%;max-width:none;max-height:70vh;margin:0;padding:0;border:0;border-top:1px solid var(--border-strong);border-radius:10px 10px 0 0;background:var(--surface-card);color:var(--primary);}
.toc-sheet::backdrop{background:rgba(26,26,46,0.32);}
.toc-sheet-body{max-height:70vh;overflow-y:auto;padding:20px 24px 24px;}
.toc-sheet-head{display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;}
.toc-sheet-head .toc-label{margin:0;}
.toc-sheet-close{padding:4px 8px;border:0;background:none;font-family:var(--mono);font-size:12px;font-weight:500;color:var(--link);text-decoration:underline;text-underline-offset:2px;cursor:pointer;}
.toc-sheet ol{list-style:none;padding:0;margin:0;}
.toc-sheet li{margin:0;}
.toc-sheet li .toc-label{margin:16px 0 4px;}
.toc-sheet a{display:flex;align-items:baseline;gap:10px;padding:10px 0;border-bottom:1px solid var(--border);font-size:14px;line-height:1.5;color:var(--primary);text-decoration:none;}
.toc-sheet a[aria-current="location"]{font-weight:600;}
.term{color:inherit;text-decoration:underline dotted;text-decoration-color:var(--label);text-decoration-thickness:1px;text-underline-offset:3px;cursor:help;}
.term:hover{text-decoration-color:var(--primary);}
.term-card{pointer-events:auto;}
.glossary{margin:16px 0;}
.glossary dt{margin-top:12px;font-size:14px;font-weight:600;color:var(--primary);}
.glossary dt:first-child{margin-top:0;}
.glossary dd{margin:4px 0 0;font-size:14px;line-height:1.7;color:var(--body);}
.hotspot-stage{position:relative;}
.hotspot,.hotspot-ref{display:inline-flex;align-items:center;justify-content:center;border-radius:9999px;background:var(--surface-dark);color:var(--surface-card);font-family:var(--mono);font-weight:500;}
.hotspot{position:absolute;left:var(--x);top:var(--y);z-index:1;width:24px;height:24px;transform:translate(-50%,-50%);border:2px solid var(--surface-card);font-size:12px;}
.hotspot-ref{width:20px;height:20px;font-size:11px;vertical-align:1px;}
.hotspot.is-highlighted,.hotspot-ref.is-highlighted,.step-item.is-highlighted .step-circle{outline:2px solid var(--focus-ring);outline-offset:2px;}
.has-hotspot-highlight .hotspot:not(.is-highlighted){opacity:0.4;}
.compare{margin:16px 0;}
.compare-stage{position:relative;isolation:isolate;display:grid;overflow:hidden;border:1.5px solid var(--border-strong);border-radius:10px;background:var(--surface-card);}
.compare-before,.compare-after{grid-area:1/1;min-width:0;}
.compare-after{clip-path:inset(0 0 0 var(--compare-position,50%));}
.compare-handle{position:absolute;top:0;bottom:0;left:var(--compare-position,50%);width:2px;margin-left:-1px;background:var(--surface-dark);pointer-events:none;}
.compare-handle::after{content:'‹ ›';position:absolute;top:50%;left:50%;display:flex;align-items:center;justify-content:center;width:32px;height:32px;transform:translate(-50%,-50%);border-radius:9999px;background:var(--surface-dark);color:var(--surface-card);font-family:var(--mono);font-size:12px;}
.compare-range{position:absolute;inset:0;width:100%;height:100%;margin:0;opacity:0;cursor:ew-resize;}
.compare-stage:has(.compare-range:focus-visible){outline:2px solid var(--focus-ring);outline-offset:2px;}
.compare-labels{display:flex;justify-content:space-between;margin-top:8px;font-family:var(--mono);font-size:11px;font-weight:500;letter-spacing:0.14em;text-transform:uppercase;color:var(--label);}
@media (prefers-reduced-motion:no-preference){
  html{scroll-behavior:smooth;}
  a{transition:text-decoration-thickness var(--motion-duration-fast) var(--motion-easing-standard),color var(--motion-duration-fast) var(--motion-easing-standard);}
  .acc[open]>.acc-body{animation:heritage-reveal var(--motion-duration-base) var(--motion-easing-standard);}
  .back-to-top:not([hidden]){animation:heritage-fade-in var(--motion-duration-base) var(--motion-easing-standard);}
  .section-rail-tick::before{transition:background-color var(--motion-duration-fast) var(--motion-easing-standard);}
  .section-rail-preview:not([hidden]),.term-card:not([hidden]){animation:heritage-fade-in var(--motion-duration-fast) var(--motion-easing-standard);}
  .section-pill:not([hidden]){animation:heritage-fade-in var(--motion-duration-base) var(--motion-easing-standard);}
  .toc-sheet[open]{animation:heritage-rise var(--motion-duration-base) var(--motion-easing-standard);}
  .section-link,.hotspot{transition:opacity var(--motion-duration-fast) var(--motion-easing-standard);}
  .term{transition:text-decoration-color var(--motion-duration-fast) var(--motion-easing-standard);}
  @keyframes heritage-reveal{from{opacity:0;transform:translateY(-4px);}to{opacity:1;transform:none;}}
  @keyframes heritage-fade-in{from{opacity:0;}to{opacity:1;}}
  @keyframes heritage-rise{from{opacity:0;transform:translateY(4px);}to{opacity:1;transform:none;}}
}
@media (max-width:719px){
  body{padding-left:16px;padding-right:16px;}
  .back-to-top{right:16px;bottom:16px;}
  .section-pill{left:16px;bottom:16px;max-width:calc(100vw - 152px);}
  .toc-sheet-body{padding:20px 16px 24px;}
  .toc ol{columns:1;}
  .code-block{padding:16px;}
}
@media (max-width:1023px){
  .section-rail,.section-rail-preview{display:none;}
}
@media (hover:none){
  .section-link{opacity:1;}
}
@media print{
  body{background:#fff;padding:0;max-width:none;}
  .callout,.example-box,.mockup,.step-item,.code-block,tr{break-inside:avoid;}
  .section-title,.part-header,.acc>summary{break-after:avoid;}
  .acc>summary::after{display:none;}
  .back-to-top,.section-rail,.section-rail-preview,.section-pill,.toc-sheet,.section-link,.term-card,.compare-handle,.compare-range{display:none;}
  .term{text-decoration:none;}
  .compare-stage{grid-template-columns:1fr 1fr;gap:16px;border:0;}
  .compare-before,.compare-after{grid-area:auto;border:1.5px solid var(--border-strong);border-radius:10px;overflow:hidden;}
  .compare-after{clip-path:none;}
  *,*::before,*::after{transition:none!important;animation:none!important;}
  a[href^="http"]::after{content:" (" attr(href) ")";font-size:11px;color:var(--label);}
}
</style>
</head>
<body>
<header class="doc-header" id="top" tabindex="-1">
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

<a class="back-to-top" href="#top" aria-label="Volver al inicio" hidden><span aria-hidden="true">↑</span> Inicio</a>
<nav class="section-rail" aria-label="Mapa de secciones" hidden></nav>
<button class="section-pill" type="button" aria-haspopup="dialog" aria-controls="toc-sheet" hidden><span class="section-pill-num"></span><span class="section-pill-title"></span></button>
<dialog class="toc-sheet" id="toc-sheet" aria-labelledby="toc-sheet-label">
  <div class="toc-sheet-body">
    <div class="toc-sheet-head"><div class="toc-label" id="toc-sheet-label">Contenido</div><button class="toc-sheet-close" type="button">Cerrar</button></div>
  </div>
</dialog>
<script>
// Navegación e interacciones Heritage: índice, mapa de secciones, píldora de sección, botón "Inicio",
// atajos, copiar enlace, novedades, glosario, puntos sobre capturas y comparación antes/después.
// Respeta "reducir movimiento". Sin JavaScript el documento se lee completo: solo faltan los atajos.
(function () {
  var button = document.querySelector('.back-to-top');
  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  var SHOW_AFTER_PX = 480;
  var TARGET_OFFSET_PX = 16;
  var SETTLE_MS = 1500;
  var FALLBACK_MS = 900;
  var ACTIVE_LINE_RATIO = 0.3;
  var VIEWPORT_MARGIN_PX = 16;
  var POPOVER_GAP_PX = 8;
  var MIN_RAIL_SECTIONS = 2;
  var CURRENT_TICK_WIDTH_PX = 24;
  var REST_TICK_WIDTH_PX = 12;
  var MAGNIFIED_TICK_WIDTH_PX = 40;
  var MAGNIFIER_RADIUS_PX = 48;
  var VISITED_PROGRESS_RATIO = 0.9;
  var TERM_HIDE_DELAY_MS = 150;
  var COPY_FEEDBACK_MS = 1600;
  var VISITED_STORAGE_PREFIX = 'heritage:visited:';
  var CHANGE_LABELS = { new: 'Nuevo', updated: 'Actualizado' };
  var stopSettling = null;
  var isNavigating = false;
  var frameRequested = false;
  var currentEntry = null;

  // —— Scroll a un destino
  // Inicio: arriba de todo (0). Título de sección: la sección completa, número incluido, con aire.
  function targetTop(target) {
    if (target.id === 'top') return 0;
    var anchor = (target.matches('.section-title') && target.closest('section')) || target;
    return Math.max(0, anchor.getBoundingClientRect().top + window.scrollY - TARGET_OFFSET_PX);
  }
  // 'instant' explícito: con html{scroll-behavior:smooth}, un scrollTo común también sería suave.
  function jump(target) { window.scrollTo({ top: targetTop(target), behavior: 'instant' }); }

  // El contenido de arriba puede cambiar de alto mientras se scrollea (imágenes o capturas diferidas):
  // mantiene el destino alineado hasta que el layout se asienta, salvo que el lector scrollee por su cuenta.
  function settleOn(target) {
    if (stopSettling) stopSettling();
    var observer = new ResizeObserver(function () { jump(target); });
    var stop = function () {
      observer.disconnect();
      ['wheel', 'touchstart', 'keydown'].forEach(function (type) { window.removeEventListener(type, stop); });
      stopSettling = null;
      isNavigating = false;
    };
    ['wheel', 'touchstart', 'keydown'].forEach(function (type) { window.addEventListener(type, stop, { passive: true }); });
    observer.observe(document.body);
    jump(target);
    setTimeout(stop, SETTLE_MS);
    stopSettling = stop;
  }

  function scrollToTarget(target, updateHash) {
    // Mientras dura el salto, las secciones que se cruzan no cuentan como leídas.
    isNavigating = true;
    // Avisa a los componentes diferidos que se rendericen antes de medir el destino.
    document.dispatchEvent(new CustomEvent('heritage:before-scroll', { detail: { target: target } }));
    setTimeout(function () {
      var settled = false;
      var finish = function () {
        if (settled) return;
        settled = true;
        settleOn(target);
      };
      window.scrollTo({ top: targetTop(target), behavior: reduceMotion.matches ? 'auto' : 'smooth' });
      // El navegador puede saltear o frenar el scroll suave (pestaña en segundo plano, visor embebido).
      if ('onscrollend' in window) window.addEventListener('scrollend', finish, { once: true });
      setTimeout(finish, FALLBACK_MS);
    }, 50);
    if (!target.hasAttribute('tabindex')) target.setAttribute('tabindex', '-1');
    target.focus({ preventScroll: true });
    if (updateHash && target.id) history.replaceState(null, '', '#' + target.id);
  }

  // —— Utilidades
  function createElement(tagName, className, text) {
    var element = document.createElement(tagName);
    if (className) element.className = className;
    if (text) element.textContent = text;
    return element;
  }
  function createChangeBadge(change) {
    return createElement('span', 'badge b-amber change-badge', CHANGE_LABELS[change]);
  }
  // Ubica una tarjeta debajo del ancla (o arriba si no entra) sin salirse de la ventana.
  function placeNear(card, anchorRect) {
    var top = anchorRect.bottom + POPOVER_GAP_PX;
    if (top + card.offsetHeight > window.innerHeight - VIEWPORT_MARGIN_PX) top = anchorRect.top - POPOVER_GAP_PX - card.offsetHeight;
    var left = Math.min(anchorRect.left, window.innerWidth - card.offsetWidth - VIEWPORT_MARGIN_PX);
    card.style.top = Math.max(VIEWPORT_MARGIN_PX, top) + 'px';
    card.style.left = Math.max(VIEWPORT_MARGIN_PX, left) + 'px';
  }
  var liveRegion = createElement('div', 'visually-hidden');
  liveRegion.setAttribute('role', 'status');
  document.body.appendChild(liveRegion);
  function announce(message) { liveRegion.textContent = message; }

  // —— Secciones: fuente única para índice, mapa, píldora, atajos y novedades
  var entries = [];
  document.querySelectorAll('section.section').forEach(function (section) {
    var heading = section.querySelector('.section-title');
    if (!heading || !heading.id) return;
    var numberElement = section.querySelector('.section-num');
    var firstParagraph = section.querySelector('p');
    entries.push({
      section: section,
      heading: heading,
      numberElement: numberElement,
      number: numberElement ? numberElement.textContent.trim() : '',
      title: heading.textContent.trim(),
      summary: firstParagraph ? firstParagraph.textContent.replace(/\s+/g, ' ').trim() : '',
      change: CHANGE_LABELS[section.dataset.change] ? section.dataset.change : '',
      visited: false,
      link: null
    });
  });
  var toc = document.querySelector('.toc');

  // Novedades: el badge se escribe una vez (data-change en la sección) y se replica en el índice.
  entries.forEach(function (entry) {
    if (!entry.change) return;
    (entry.numberElement || entry.heading).appendChild(createChangeBadge(entry.change));
    var tocLink = toc && toc.querySelector('a[href="#' + entry.heading.id + '"]');
    if (tocLink) tocLink.appendChild(createChangeBadge(entry.change));
  });

  // Secciones leídas: se recuerdan por documento; si el visor bloquea el almacenamiento, duran la visita.
  var storageKey = VISITED_STORAGE_PREFIX + location.pathname + '|' + document.title;
  var visitedIds = [];
  try { visitedIds = JSON.parse(localStorage.getItem(storageKey) || '[]'); } catch (storageError) { visitedIds = []; }
  function saveVisited() {
    try { localStorage.setItem(storageKey, JSON.stringify(visitedIds)); } catch (storageError) { /* fallback deliberado: progreso solo en memoria */ }
  }

  function tickLabel(entry) {
    var parts = [(entry.number ? entry.number + ' ' : '') + entry.title];
    if (entry.change) parts.push(CHANGE_LABELS[entry.change]);
    if (entry.visited) parts.push('leída');
    return parts.join(', ');
  }
  function renderVisited(entry) {
    if (!entry.link) return;
    entry.link.classList.toggle('is-visited', entry.visited);
    entry.link.setAttribute('aria-label', tickLabel(entry));
  }
  function markVisited(entry) {
    if (entry.visited) return;
    entry.visited = true;
    if (visitedIds.indexOf(entry.heading.id) === -1) visitedIds.push(entry.heading.id);
    saveVisited();
    renderVisited(entry);
  }
  entries.forEach(function (entry) { entry.visited = visitedIds.indexOf(entry.heading.id) !== -1; });

  // —— Copiar enlace a una sección. En visores embebidos, <meta name="heritage:share-url"> da la URL pública.
  var shareMeta = document.querySelector('meta[name="heritage:share-url"]');
  var shareBase = (shareMeta && shareMeta.content) || location.href.split('#')[0];
  function copyWithSelection(text) {
    return new Promise(function (resolve, reject) {
      var field = createElement('textarea', 'visually-hidden');
      field.value = text;
      field.setAttribute('readonly', '');
      document.body.appendChild(field);
      field.select();
      var copied = false;
      try { copied = document.execCommand('copy'); } catch (copyError) { copied = false; }
      field.remove();
      if (copied) resolve();
      else reject(new Error('Heritage:copyText failed: clipboard unavailable in this viewer'));
    });
  }
  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text).catch(function () { return copyWithSelection(text); });
    }
    return copyWithSelection(text);
  }
  entries.forEach(function (entry) {
    if (!entry.numberElement) return;
    var copyButton = createElement('button', 'section-link', 'Copiar enlace');
    var restLabel = 'Copiar enlace a la sección ' + (entry.number || entry.title);
    copyButton.type = 'button';
    copyButton.setAttribute('aria-label', restLabel);
    copyButton.addEventListener('click', function () {
      var url = shareBase + '#' + entry.heading.id;
      var showFeedback = function (message) {
        copyButton.textContent = message;
        copyButton.classList.add('is-copied');
        copyButton.focus({ preventScroll: true });
        announce(message);
        setTimeout(function () {
          copyButton.textContent = 'Copiar enlace';
          copyButton.classList.remove('is-copied');
        }, COPY_FEEDBACK_MS);
      };
      copyText(url).then(function () { showFeedback('Enlace copiado'); }, function (copyError) {
        console.warn('Heritage:copySectionLink failed', { sectionId: entry.heading.id, error: copyError });
        showFeedback('No se pudo copiar');
      });
    });
    entry.numberElement.appendChild(copyButton);
  });

  // —— Mapa de secciones: una marca por sección, lupa, vista previa, progreso, leídas y novedades.
  var rail = document.querySelector('.section-rail');
  var preview = null;
  var hidePreview = function () { if (preview) preview.hidden = true; };
  var isMac = /Mac|iPhone|iPad/.test(navigator.platform || navigator.userAgent);
  var modifierLabel = isMac ? '⌥' : 'Alt';
  if (rail && entries.length >= MIN_RAIL_SECTIONS) {
    var railList = createElement('ol');
    preview = createElement('div', 'section-rail-preview');
    var previewMeta = createElement('div', 'section-rail-preview-meta');
    var previewNumber = createElement('span', 'section-rail-preview-num');
    var previewState = createElement('span', 'section-rail-preview-state');
    var previewBadge = createElement('span', 'badge b-amber change-badge');
    var previewTitle = createElement('div', 'section-rail-preview-title');
    var previewSummary = createElement('div', 'section-rail-preview-summary');
    var previewHint = createElement('div', 'section-rail-preview-hint',
      modifierLabel + ' ↑ ↓ secciones' + (toc ? ' · ' + modifierLabel + ' I índice' : ''));
    previewMeta.append(previewNumber, previewBadge, previewState);
    preview.append(previewMeta, previewTitle, previewSummary, previewHint);
    preview.setAttribute('aria-hidden', 'true');
    preview.hidden = true;

    entries.forEach(function (entry) {
      var item = createElement('li');
      entry.link = createElement('a', 'section-rail-tick');
      entry.link.href = '#' + entry.heading.id;
      if (entry.change) entry.link.dataset.change = entry.change;
      renderVisited(entry);
      item.appendChild(entry.link);
      railList.appendChild(item);
    });
    rail.appendChild(railList);
    document.body.appendChild(preview);
    rail.hidden = false;

    var showPreview = function (entry) {
      previewNumber.textContent = entry.number;
      previewState.textContent = entry.visited ? 'Leída' : '';
      previewBadge.textContent = entry.change ? CHANGE_LABELS[entry.change] : '';
      previewTitle.textContent = entry.title;
      previewSummary.textContent = entry.summary;
      previewNumber.hidden = !entry.number;
      previewState.hidden = !entry.visited;
      previewBadge.hidden = !entry.change;
      previewSummary.hidden = !entry.summary;
      preview.hidden = false;
      var tick = entry.link.getBoundingClientRect();
      var centeredTop = tick.top + tick.height / 2 - preview.offsetHeight / 2;
      var maxTop = window.innerHeight - preview.offsetHeight - VIEWPORT_MARGIN_PX;
      preview.style.top = Math.max(VIEWPORT_MARGIN_PX, Math.min(centeredTop, maxTop)) + 'px';
    };

    // Lupa: cada marca crece según su distancia vertical al puntero (o a la marca enfocada).
    var magnify = function (pointerY) {
      entries.forEach(function (entry) {
        var tick = entry.link.getBoundingClientRect();
        var distance = Math.min(Math.abs(tick.top + tick.height / 2 - pointerY) / MAGNIFIER_RADIUS_PX, 1);
        var influence = (1 + Math.cos(Math.PI * distance)) / 2;
        var width = REST_TICK_WIDTH_PX + (MAGNIFIED_TICK_WIDTH_PX - REST_TICK_WIDTH_PX) * influence;
        if (entry.link.hasAttribute('aria-current')) width = Math.max(width, CURRENT_TICK_WIDTH_PX);
        entry.link.style.setProperty('--tick-width', width.toFixed(1) + 'px');
      });
    };
    var resetMagnifier = function () {
      entries.forEach(function (entry) { entry.link.style.removeProperty('--tick-width'); });
    };
    rail.addEventListener('pointermove', function (event) { magnify(event.clientY); });
    rail.addEventListener('pointerleave', resetMagnifier);

    entries.forEach(function (entry) {
      entry.link.addEventListener('mouseenter', function () { showPreview(entry); });
      entry.link.addEventListener('focus', function () {
        showPreview(entry);
        var tick = entry.link.getBoundingClientRect();
        magnify(tick.top + tick.height / 2);
      });
      entry.link.addEventListener('mouseleave', hidePreview);
      entry.link.addEventListener('blur', function () {
        hidePreview();
        if (!rail.matches(':hover')) resetMagnifier();
      });
    });
  }

  // —— Píldora de sección + índice en hoja inferior (pantallas angostas, donde el mapa no entra)
  var pill = document.querySelector('.section-pill');
  var sheet = document.querySelector('.toc-sheet');
  var sheetReady = Boolean(pill && sheet && sheet.showModal && entries.length >= MIN_RAIL_SECTIONS);
  if (sheetReady) {
    var sheetBody = sheet.querySelector('.toc-sheet-body');
    var sheetList = toc ? toc.querySelector('ol').cloneNode(true) : createElement('ol');
    if (!toc) {
      entries.forEach(function (entry) {
        var item = createElement('li');
        var link = createElement('a', '', entry.title);
        link.href = '#' + entry.heading.id;
        link.prepend(createElement('span', 'toc-num', entry.number));
        item.appendChild(link);
        sheetList.appendChild(item);
      });
    }
    sheetBody.appendChild(sheetList);
    pill.addEventListener('click', function () {
      sheetList.querySelectorAll('a').forEach(function (link) {
        if (currentEntry && link.getAttribute('href') === '#' + currentEntry.heading.id) link.setAttribute('aria-current', 'location');
        else link.removeAttribute('aria-current');
      });
      sheet.showModal();
    });
    sheet.querySelector('.toc-sheet-close').addEventListener('click', function () { sheet.close(); });
    // Click en el fondo (fuera de .toc-sheet-body) cierra la hoja; Escape lo resuelve el <dialog>.
    sheet.addEventListener('click', function (event) { if (event.target === sheet) sheet.close(); });
  }

  // —— Sección actual: progreso de lectura, leídas, píldora y mapa
  function renderCurrent(current, progress) {
    entries.forEach(function (entry) {
      if (!entry.link) return;
      if (entry === current) {
        entry.link.setAttribute('aria-current', 'location');
        entry.link.style.setProperty('--tick-progress', Math.round(progress * 100) + '%');
      } else {
        entry.link.removeAttribute('aria-current');
        entry.link.style.removeProperty('--tick-progress');
      }
    });
    if (sheetReady) {
      pill.querySelector('.section-pill-num').textContent = current.number;
      pill.querySelector('.section-pill-title').textContent = current.title;
      pill.setAttribute('aria-label', 'Sección actual: ' + (current.number ? current.number + ' ' : '') + current.title + '. Abrir índice');
    }
  }
  function updateCurrent() {
    frameRequested = false;
    if (!entries.length) return;
    var activeLine = window.innerHeight * ACTIVE_LINE_RATIO;
    var atBottom = window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 1;
    var current = entries[0];
    entries.forEach(function (entry) {
      if (entry.section.getBoundingClientRect().top <= activeLine) current = entry;
    });
    if (atBottom) current = entries[entries.length - 1];
    var rect = current.section.getBoundingClientRect();
    var progress = atBottom ? 1 : Math.min(Math.max((activeLine - rect.top) / rect.height, 0), 1);
    if (!isNavigating) {
      if (progress >= VISITED_PROGRESS_RATIO) markVisited(current);
      // Pasar scrolleando a la sección siguiente también cuenta como leída; saltar con el índice, no.
      if (currentEntry && entries.indexOf(current) === entries.indexOf(currentEntry) + 1) markVisited(currentEntry);
    }
    currentEntry = current;
    renderCurrent(current, progress);
  }
  // setTimeout y no requestAnimationFrame: rAF no corre en pestañas en segundo plano ni en algunos visores.
  function requestUpdate() {
    if (frameRequested) return;
    frameRequested = true;
    setTimeout(updateCurrent, 16);
  }
  function toggleFloating() {
    var scrolled = window.scrollY >= SHOW_AFTER_PX;
    if (button) button.hidden = !scrolled;
    if (sheetReady) pill.hidden = !scrolled;
  }
  window.addEventListener('scroll', requestUpdate, { passive: true });
  window.addEventListener('scroll', toggleFloating, { passive: true });
  window.addEventListener('scroll', hidePreview, { passive: true });
  window.addEventListener('resize', requestUpdate);
  toggleFloating();
  updateCurrent();

  // —— Glosario: el término enlaza a su <dt>; la definición se lee con aria-describedby y se ve al pasar o enfocar.
  var termCard = createElement('div', 'term-card');
  var termCardTitle = createElement('div', 'term-card-title');
  var termCardText = createElement('div', 'term-card-text');
  var termHideTimer = null;
  termCard.append(termCardTitle, termCardText);
  termCard.setAttribute('aria-hidden', 'true');
  termCard.hidden = true;
  var hideTermCard = function () { clearTimeout(termHideTimer); termCard.hidden = true; };
  var scheduleHideTermCard = function () {
    clearTimeout(termHideTimer);
    termHideTimer = setTimeout(hideTermCard, TERM_HIDE_DELAY_MS);
  };
  var terms = document.querySelectorAll('a.term[href^="#"]');
  if (terms.length) document.body.appendChild(termCard);
  terms.forEach(function (term) {
    var definitionTerm = document.getElementById(term.getAttribute('href').slice(1));
    var definition = definitionTerm && definitionTerm.nextElementSibling;
    if (!definition || definition.tagName !== 'DD') return;
    if (!definition.id) definition.id = definitionTerm.id + '-definition';
    term.setAttribute('aria-describedby', definition.id);
    var showTermCard = function () {
      clearTimeout(termHideTimer);
      termCardTitle.textContent = definitionTerm.textContent.trim();
      termCardText.textContent = definition.textContent.replace(/\s+/g, ' ').trim();
      termCard.hidden = false;
      placeNear(termCard, term.getBoundingClientRect());
    };
    term.addEventListener('mouseenter', showTermCard);
    term.addEventListener('focus', showTermCard);
    term.addEventListener('mouseleave', scheduleHideTermCard);
    term.addEventListener('blur', hideTermCard);
  });
  // La tarjeta se puede recorrer con el puntero sin que desaparezca (WCAG 1.4.13).
  termCard.addEventListener('mouseenter', function () { clearTimeout(termHideTimer); });
  termCard.addEventListener('mouseleave', scheduleHideTermCard);
  window.addEventListener('scroll', hideTermCard, { passive: true });

  // —— Links internos: índice, mapa, hoja inferior y términos del glosario usan el mismo scroll.
  document.querySelectorAll('.toc a[href^="#"], .section-rail a[href^="#"], .toc-sheet a[href^="#"], a.term[href^="#"]').forEach(function (link) {
    link.addEventListener('click', function (event) {
      var target = document.getElementById(link.getAttribute('href').slice(1));
      if (!target) return;
      event.preventDefault();
      if (sheet && sheet.open) sheet.close();
      hideTermCard();
      scrollToTarget(target, true);
    });
  });

  if (button) {
    button.addEventListener('click', function (event) {
      event.preventDefault();
      scrollToTarget(document.getElementById('top'), false);
    });
  }

  // —— Atajos: Alt+↓ / Alt+↑ cambian de sección, Alt+I va al índice, Escape cierra las vistas previas.
  // Con modificador para no chocar con lectores de pantalla ni con la escritura (WCAG 2.1.4).
  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape') { hidePreview(); hideTermCard(); return; }
    if (!event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return;
    if (event.target.closest && event.target.closest('input, textarea, select, [contenteditable]')) return;
    if (sheet && sheet.open) return;
    var currentIndex = entries.indexOf(currentEntry);
    var destination = null;
    if (event.key === 'ArrowDown' && entries[currentIndex + 1]) destination = entries[currentIndex + 1].heading;
    else if (event.key === 'ArrowUp' && entries[currentIndex - 1]) destination = entries[currentIndex - 1].heading;
    else if (event.code === 'KeyI' && toc) destination = toc;
    if (!destination) return;
    event.preventDefault();
    scrollToTarget(destination, destination !== toc);
  });

  // —— Puntos sobre capturas: pasar por un paso o una referencia resalta su punto, y viceversa.
  document.querySelectorAll('section.section').forEach(function (section) {
    if (!section.querySelector('.hotspot[data-hotspot]')) return;
    var linked = section.querySelectorAll('[data-hotspot]');
    var highlight = function (number) {
      linked.forEach(function (element) { element.classList.toggle('is-highlighted', element.dataset.hotspot === number); });
      section.classList.toggle('has-hotspot-highlight', Boolean(number));
    };
    linked.forEach(function (element) {
      element.addEventListener('mouseenter', function () { highlight(element.dataset.hotspot); });
      element.addEventListener('mouseleave', function () { highlight(''); });
    });
  });

  // —— Comparación antes/después: un <input type="range"> nativo mueve el divisor (mouse, táctil y teclado).
  document.querySelectorAll('.compare').forEach(function (compare) {
    var range = compare.querySelector('.compare-range');
    if (!range) return;
    var update = function () {
      var value = Number(range.value);
      compare.style.setProperty('--compare-position', value + '%');
      range.setAttribute('aria-valuetext', 'Antes ' + value + '%, después ' + (100 - value) + '%');
    };
    range.addEventListener('input', update);
    update();
  });
})();
</script>
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
<!-- Índice (TOC): después del doc-header, solo con 5+ secciones -->
<nav class="toc" aria-labelledby="toc-label">
  <div class="toc-label" id="toc-label">Contenido</div>
  <ol>
    <li><a href="#s01"><span class="toc-num">01</span>[Título de la sección]</a></li>
    <li><a href="#s02"><span class="toc-num">02</span>[Título de la sección]</a></li>
  </ol>
</nav>

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

<!-- Botón "Inicio": justo antes de </body>, junto con el script de navegación del boilerplate.
     El doc-header lleva id="top" y tabindex="-1". -->
<a class="back-to-top" href="#top" aria-label="Volver al inicio" hidden><span aria-hidden="true">↑</span> Inicio</a>

<!-- Mapa de secciones: vacío, junto al botón "Inicio". El script de navegación lo arma
     con una marca por cada section.section que tenga section-title con id. -->
<nav class="section-rail" aria-label="Mapa de secciones" hidden></nav>

<!-- Píldora de sección + hoja del índice: junto al mapa. El script completa ambas. -->
<button class="section-pill" type="button" aria-haspopup="dialog" aria-controls="toc-sheet" hidden><span class="section-pill-num"></span><span class="section-pill-title"></span></button>
<dialog class="toc-sheet" id="toc-sheet" aria-labelledby="toc-sheet-label">
  <div class="toc-sheet-body">
    <div class="toc-sheet-head"><div class="toc-label" id="toc-sheet-label">Contenido</div><button class="toc-sheet-close" type="button">Cerrar</button></div>
  </div>
</dialog>

<!-- URL pública para "Copiar enlace" cuando el documento se ve dentro de un iframe (en <head>) -->
<meta name="heritage:share-url" content="[URL del documento en el visor]">

<!-- Novedades: solo el atributo; el script pone los badges -->
<section class="section" aria-labelledby="s04" data-change="updated">…</section>

<!-- Glosario: término en la prosa + definición única -->
<a class="term" href="#g-termino">término</a>
<dl class="glossary">
  <dt id="g-termino">Término</dt>
  <dd>[Definición en una o dos oraciones]</dd>
</dl>

<!-- Puntos sobre una captura + pasos y referencia vinculados -->
<div class="mockup">
  <div class="mockup-bar">…</div>
  <div class="hotspot-stage">
    <div class="app-frame" data-cap="[captura]"></div>
    <span class="hotspot" data-hotspot="1" style="--x:12%;--y:30%" aria-hidden="true">1</span>
  </div>
</div>
<ol class="steps">
  <li class="step-item" data-hotspot="1">…</li>
</ol>
<p>Tocá el botón <span class="hotspot-ref" data-hotspot="1"><span class="visually-hidden">punto </span>1</span>.</p>

<!-- Comparación antes / después -->
<div class="compare">
  <div class="compare-stage">
    <div class="compare-before"><div class="app-frame" data-cap="[antes]" aria-label="Captura de pantalla: antes, …"></div></div>
    <div class="compare-after"><div class="app-frame" data-cap="[después]" aria-label="Captura de pantalla: después, …"></div></div>
    <div class="compare-handle" aria-hidden="true"></div>
    <input class="compare-range" type="range" min="0" max="100" value="50" aria-label="Comparar antes y después">
  </div>
  <div class="compare-labels"><span>Antes</span><span>Después</span></div>
</div>
```

Componentes que se cargan de forma diferida (imágenes, capturas embebidas) y
cambian de alto al renderizarse escuchan `heritage:before-scroll`: el script de
navegación lo dispara con `event.detail.target` antes de medir el destino, para
que rendericen todo lo que está por encima.

```js
document.addEventListener('heritage:before-scroll', (event) => {
  // renderizar los elementos diferidos que están antes de event.detail.target
});
```
