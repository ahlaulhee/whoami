---
name: ahlaulhee
description: Setup guides from one real machine, set in Paradise on graph paper.
colors:
  ground: "#101010"
  panel: "#151515"
  raised: "#1c1c1c"
  line: "#2a2a2a"
  line-strong: "#424242"
  fg: "#e8e3e3"
  muted: "#a39d9d"
  paradise-red: "#b66467"
  paradise-green: "#8c977d"
  paradise-yellow: "#d9bc8c"
  paradise-blue: "#8da3b9"
  paradise-cyan: "#8aa6a2"
typography:
  display:
    fontFamily: "Geist Variable, system-ui, sans-serif"
    fontSize: "clamp(1.75rem, 1.2rem + 2.2vw, 2.75rem)"
    fontWeight: 650
    lineHeight: 1.25
    letterSpacing: "-0.025em"
  headline:
    fontFamily: "Geist Variable, system-ui, sans-serif"
    fontSize: "1.5rem"
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: "-0.015em"
  title:
    fontFamily: "Geist Variable, system-ui, sans-serif"
    fontSize: "1.25rem"
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: "-0.01em"
  body:
    fontFamily: "Geist Variable, system-ui, sans-serif"
    fontSize: "1.0625rem"
    fontWeight: 400
    lineHeight: 1.75
  label:
    fontFamily: "Geist Mono Variable, ui-monospace, monospace"
    fontSize: "0.8125rem"
    fontWeight: 400
    lineHeight: 1.6
rounded:
  none: "0"
spacing:
  gap: "clamp(1rem, 2.5vw, 2rem)"
  pad: "clamp(1.125rem, 3vw, 2rem)"
components:
  panel:
    backgroundColor: "{colors.panel}"
    rounded: "{rounded.none}"
    padding: "{spacing.pad}"
  article-title:
    backgroundColor: "{colors.fg}"
    textColor: "{colors.panel}"
    typography: "{typography.display}"
  nav-link-active:
    backgroundColor: "{colors.fg}"
    textColor: "{colors.panel}"
  tested-stamp:
    backgroundColor: "{colors.raised}"
    textColor: "{colors.fg}"
    typography: "{typography.label}"
  inline-code:
    backgroundColor: "{colors.raised}"
    textColor: "{colors.paradise-yellow}"
---

# Design System: ahlaulhee

## Overview

**Creative North Star: "The Machine Notebook"**

Notes kept for one specific computer. The page is a dark sheet of graph paper (a 32px hairline grid on `ground`); square panels sit on it like taped-in pages. Inside a panel the reading column is calm: Geist at 17px, 70ch, real contrast. Paradise colours show up in small, functional doses: icons, tags, inline code, the tested-on label.

Visually inspired by the Spectre Astro theme (two columns, square bordered panels, inverted title), rebuilt from scratch and recoloured. Dark only.

**Key Characteristics:**
- Square corners everywhere; 1px borders, no shadows, no glow.
- Two columns on desktop: sticky rail (profile, tags or contents) and the reading panel.
- The article title is an inverted block, like a terminal selection.
- Every guide shows a "tested on" stamp before the body.

## Colors

Paradise on near-black: muted, warm, low saturation.

### Primary
- **Paradise Blue** (#8da3b9): links, highlighted code line accent, focus border in code frames.

### Secondary
- **Paradise Red** (#b66467): panel title icons, profile icons, text selection.
- **Paradise Yellow** (#d9bc8c): inline code, draft badge, current series part, focus ring.

### Tertiary
- **Paradise Green** (#8c977d): the "tested on" label, copy-success tooltip.
- **Paradise Cyan** (#8aa6a2): tag links.

### Neutral
- **Ground** (#101010): page background under the grid.
- **Panel** (#151515): panels; Paradise's own background.
- **Raised** (#1c1c1c): code frames, stamps, blockquotes, hover fills.
- **Line** (#2a2a2a) and **Line Strong** (#424242): borders and separators.
- **Paper White** (#e8e3e3): body text and inverted blocks.
- **Ash** (#a39d9d): secondary text, dates, descriptions.

### Named Rules
**The Small Doses Rule.** Accent colours mark function (an icon, a tag, a code token, a state). No panel, button or section is filled with an accent.

## Typography

**Body Font:** Geist Variable (with system-ui)
**Label/Mono Font:** Geist Mono Variable (with ui-monospace)

**Character:** A plain grotesque for reading, its mono sibling for anything the reader might type or compare: code, dates, versions, nav.

### Hierarchy
- **Display** (650, clamp 1.75–2.75rem, 1.25): article title only, inverted.
- **Headline** (600, 1.5rem, 1.3): article h2, with a hairline rule above.
- **Title** (600, 1.25rem, 1.3): panel titles with a red icon.
- **Body** (400, 1.0625rem, 1.75): article prose, max 70ch.
- **Label** (400 mono, 0.8125rem): dates, tags, tested-on stamp, nav, footer.

### Named Rules
**The Typed Text Rule.** Mono only for what a reader would type or compare (code, versions, dates, paths) and for nav labels. Running text and headings stay in Geist.

## Layout

Container `min(100% - 2·gap, 80rem)`. Below 64em one column with the rail stacked above the content (contents collapse into a `<details>`). From 64em: `17.5rem` sticky rail plus `minmax(0, 1fr)` column. Grids always declare `minmax(0, 1fr)` so code blocks scroll instead of widening the page. Gap and panel padding scale with `clamp`.

## Elevation & Depth

Flat. Depth comes from tonal steps (ground → panel → raised) and 1px borders. No box-shadows, including in Expressive Code frames.

## Shapes

Radius 0 on panels, code frames, badges and buttons. Lists inside panels are divided by hairlines, never boxed.

## Components

### Panels
- **Corner Style:** square (0)
- **Background:** panel (#151515), 1px line border
- **Shadow Strategy:** none
- **Internal Padding:** `clamp(1.125rem, 3vw, 2rem)`

### Navigation
- Mono, lowercase, separated by a dim `/`. Hover turns blue; the current section is an inverted block (paper white on panel).

### Article header (signature)
- Inverted title block, mono meta line with icons (date, updated, read time), cyan `#tags`, the tested-on stamp (raised box, green label, versions separated by `·`), then the series strip: part N of M, parts numbered `01 02 03`, unpublished parts marked "(coming soon)" without a link.

### Code
- Expressive Code with the Paradise VS Code theme, Geist Mono 0.875rem, line height 1.65, square frames, terminal frames for shell, copy button on every block.

## Do's and Don'ts

### Do:
- **Do** keep every new surface on the panel + rail grammar.
- **Do** show versions in the tested-on stamp and in the slug.
- **Do** use Lucide icons (Simple Icons for brands) at 14–18px.

### Don't:
- **Don't** add rounded corners, shadows or glows.
- **Don't** nest bordered boxes inside panels; separate with hairlines.
- **Don't** add a light theme without a full second palette (Paradise has no light variant).
