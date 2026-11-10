# Scope

What betternotes is and is not. This is the owner's feature list; do not add to it.

## iPad app (native Swift, full feature set)

Device: iPad Air 11" with Apple Pencil Pro, latest iPadOS.

- **Toolbar**: pen, highlighter, eraser (stroke and pixel), selector, shapes, text, image.
  Palm rejection, undo/redo, very low latency.
- **Apple Pencil Pro**: squeeze, double-tap, barrel roll, hover, pressure, tilt/azimuth.
  GoodNotes-like tool selector on squeeze. Squeeze and double-tap actions are configurable
  (quick-switch tool, toggle eraser, open palette).
- **Selector**, two modes:
  1. object select: tap or lasso selects whole strokes/objects;
  2. clip select: the lasso cuts strokes at its boundary; cut parts can be moved, copied,
     deleted or recoloured.
- **Shapes** (meant to be a strength): editable objects (line, arrow, rect, rounded rect,
  ellipse, triangle, polygon, curve, connectors that stay attached), handles, fill/stroke/dash,
  snapping, grid/guides, align/distribute, hold-to-perfect and auto-recognition (can be disabled).
- **Layers** per page: show/hide, lock, reorder, rename, opacity, "move selection to layer".
  A PDF background is a locked base layer.
- **Mirror mode**: strokes mirrored live across an axis (vertical, horizontal, both, optional
  radial), toggled per page.
- **PDF** import and annotation, export with annotations baked in.
- **Text**: typed text and Markdown blocks anywhere on the page.
- **OCR**: local handwriting recognition for search.

## Web companion (PWA on GitHub Pages, installable, offline-capable)

- View everything: strokes, layers, shapes, PDFs, chapters, links.
- Type and edit text blocks, paste text and images, search, library and graph,
  export PDF/SVG/PNG.
- Basic drawing: freehand pen/highlighter/eraser, basic shapes and arrows, basic layers
  (show/hide, reorder, move to layer), select and move whole objects.
- NOT in the web app: clip-select, mirror mode, advanced shape tools, iPad-level pen feel.
- It must never damage iPad-created content: unknown object types are kept untouched on save.

## Shared

- Obsidian's clean monochrome look (dark and light), minimal chrome, tabs for open
  notebooks/pages.
- Two library views: GoodNotes-style (folders, covers/thumbnails, drag and drop) and an
  Obsidian-style graph (notebooks/chapters/pages as nodes; links, backlinks and tags as edges;
  filters and search). Links via `[[...]]` in text blocks or by linking a selection.
- Chapters: notebook -> chapters -> pages, with chapter tabs/sidebar.
- Search across titles, tags, typed text and OCR'd handwriting.

## Format and sync

- `docs/FORMAT.md` + JSON schema; one file per page plus assets; Swift and TypeScript
  reference implementations sharing conformance fixtures.
- Sync via the user's own OneDrive (Microsoft Graph, OAuth PKCE, multi-tenant + personal).
  Google Drive is optional and must never be required. Offline-first, per-page versioning,
  no silent overwrites.

## Opt-in integrations

- Claude and Perplexity with the user's own API keys. Nothing is sent unless triggered;
  results become text blocks. Pluggable provider layer.
- `.goodnotes` import: separate converter, prototype after inspecting a sample in
  `private-samples/`. No promise of full fidelity.
- Mebis import (Bavarian school platform, PDF/PPTX/DOCX): choose the destination on import.
  Never store the school password, never violate Mebis's terms. Feasibility spike first.
  Ranked: (a) solid manual flow, (b) Moodle web-service token if allowed,
  (c) browser extension/bookmarklet.

## Never build

Sticker store (users import their own images), tape tool, audio recording, built-in AI
features, accounts, telemetry, paywall, a personal backend. OneNote is not a model, except
for chapters.

## Milestones

| | Content | Checkpoint |
|---|---|---|
| a | Rules files, empty-app .ipa in CI, FORMAT.md + schema + Swift and TS packages with tests | |
| b | Drawing app + latency spike (PencilKit vs custom vs fallback) + SideStore docs + OneDrive registration spike | owner tests drawing feel |
| c | iPad: pen, layers, storage | |
| d | iPad: selector (both modes) and shapes | |
| e | iPad: PDF, text blocks, chapters | |
| f | iPad: library view, tabs, Obsidian-style UI | owner tests on iPad |
| g | OneDrive sync | owner tests |
| h | PWA companion with basic drawing | owner tests on Android and Fedora |
| i | Graph view and search on both | |
| j | Mirror mode, OCR | |
| k | Manual import flow + Mebis spike | |
| l | AI hooks | |
| m | .goodnotes converter | |
