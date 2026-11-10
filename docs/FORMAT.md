# The betternotes format, version 1.0

This specification and `schema/betternotes.schema.json` are released under CC0: anyone may
implement the format. Reference implementations: `core/` (Swift) and `packages/format-ts/`
(TypeScript). Both must pass the shared fixtures in `fixtures/`.

## 1. Overview

A notebook is a plain folder whose name ends in `.bnote`:

```
Physics.bnote/
  notebook.json            the notebook: title, tags, chapters
  pages/<pageId>.json      one file per page
  pages/<pageId>.ocr.json  optional: recognised handwriting of that page
  assets/<sha256>.<ext>    images and PDFs
  .backup/                 optional: previous versions kept by an app (never synced)
```

A library is any folder containing `.bnote` folders; sub-folders are library folders.
There is no index file: everything is found by listing folders.

One file per page keeps sync conflicts small: two devices only collide when they edit the
same page.

## 2. General rules

- Files are JSON, UTF-8, no byte order mark. Key order and whitespace carry no meaning.
- **Lengths and coordinates** are integers in units of 1/100 point (1 point = 1/72 inch).
  A4 is 59528 x 84189. Origin is the top-left corner of the page, x to the right, y down.
- **Angles** are integers in 1/10 degree, clockwise.
- **Fractions** (opacity, pressure, confidence) are integers 0 to 1000.
- **Colours** are `#rrggbb` or `#rrggbbaa`, lowercase hex.
- **Timestamps** are UTC, ISO 8601, to the second: `2026-11-10T12:00:00Z`.
- **Ids** are strings of 1 to 64 characters from `A-Z a-z 0-9 _ -`. Writers generate
  lowercase UUIDs. Notebook, chapter and page ids are unique within a library; layer and
  object ids are unique within their page.
- Every file has `format` (which kind of file) and `formatVersion` (`"major.minor"`).

## 3. Versions and forward compatibility

These rules are what keeps a simpler app (the web companion, an older version) from damaging
content written by a more capable one.

1. **Preserve what you do not understand.** A reader MUST keep every unknown field and every
   object with an unknown `type`, and write them back unchanged, in the same position in
   their array. Unknown objects may be shown as a placeholder (they usually have
   `x`, `y`, `w`, `h`) but must not be edited, only moved between layers or deleted by
   an explicit user action.
2. **Newer minor** (file `1.7`, app knows `1.0`): open normally, rule 1 applies. When
   saving, keep the file's higher `formatVersion`; never lower it.
3. **Newer major** (file `2.0`, app knows `1.x`): open **read-only**. Do not save.
4. **Older major**: migrate. Before writing the migrated file, copy the original to
   `.backup/<relative path>.<timestamp>` inside the notebook.
5. New fields are added in minor versions and must be optional. A change that an older
   reader would misinterpret needs a new major version.

## 4. Safety rules for writers

- Write to a temporary file in the same folder, then rename it over the target (atomic).
- Never modify an asset file; assets are immutable and named by their content.
- Keep a copy of the previous version in `.backup/` before a migration and before
  resolving a sync conflict. `.backup/` is local and is not synced.

## 5. `notebook.json`

```json
{
  "format": "betternotes.notebook",
  "formatVersion": "1.0",
  "id": "5b0c1c0e-6f0a-4a43-9d1b-0f2a3b4c5d6e",
  "title": "Physics",
  "created": "2026-11-10T12:00:00Z",
  "modified": "2026-11-10T12:30:00Z",
  "tags": ["school"],
  "cover": { "color": "#3a3a3a" },
  "chapters": [
    { "id": "ch-mechanics", "title": "Mechanics", "order": 1024 }
  ]
}
```

| Field | Required | Meaning |
|---|---|---|
| `id`, `title`, `created`, `modified` | yes | |
| `tags` | no | list of strings without `#` |
| `cover` | no | `color` and/or `asset` (file name in `assets/`) |
| `chapters` | yes (may be empty) | `id`, `title`, `order` |

The notebook file does **not** list its pages. Each page names its chapter. So adding,
moving or deleting a page never touches `notebook.json`.

### Ordering

`order` is an integer. Items are sorted by `order`, ties by `id`. Writers leave gaps
(1024, 2048, ...) and insert at the midpoint between neighbours. When no gap is left, the
writer renumbers the siblings.

## 6. Page file `pages/<pageId>.json`

```json
{
  "format": "betternotes.page",
  "formatVersion": "1.0",
  "id": "0d6f6c0a-1d1b-4c58-9a57-3d0b7d3a8f10",
  "chapter": "ch-mechanics",
  "order": 1024,
  "title": "Free fall",
  "created": "2026-11-10T12:00:00Z",
  "modified": "2026-11-10T12:30:00Z",
  "tags": [],
  "size": { "w": 59528, "h": 84189 },
  "paper": { "type": "grid", "color": "#ffffff", "lineColor": "#d0d0d0", "spacing": 1417 },
  "mirror": { "mode": "vertical", "cx": 29764, "cy": 42094 },
  "layers": [
    { "id": "l1", "name": "Layer 1", "visible": true, "locked": false, "opacity": 1000,
      "objects": [] }
  ]
}
```

| Field | Required | Meaning |
|---|---|---|
| `id` | yes | equals the file name without `.json` |
| `chapter` | yes | chapter id, or `null` for pages outside any chapter |
| `order` | yes | position within the chapter (see Ordering) |
| `title`, `tags` | no | |
| `created`, `modified` | yes | |
| `size` | yes | `w`, `h` |
| `paper` | no | `type`: `blank`, `lined`, `grid`, `dots`; `color`; `lineColor`; `spacing`. Default: blank white |
| `mirror` | no | symmetry drawing: `mode` is `vertical`, `horizontal`, `both` or `radial`; `cx`, `cy` centre; `count` for radial. Absent = off |
| `layers` | yes | bottom layer first |

### Layers

`id`, `name`, `visible`, `locked`, `opacity` (0 to 1000) and `objects` (bottom object first).
All are required except `opacity` (default 1000).

A PDF background is not special: it is a `pdf` object in a locked bottom layer.

## 7. Objects

Every object has `id` and `type`. Any object may have `link` (see Links). Objects with a
box have `x`, `y`, `w`, `h` (top-left corner and size before rotation) and optional
`rotation` around the box centre.

### 7.1 `stroke`

```json
{
  "id": "s1", "type": "stroke", "tool": "pen", "color": "#1a1a1a", "width": 180,
  "pts": {
    "x": [10000, 10120, 10260], "y": [20000, 20040, 20110],
    "p": [310, 520, 480], "tilt": [520, 518, 515], "az": [1200, 1203, 1207],
    "roll": [0, 12, 25], "t": [0, 4, 8]
  }
}
```

| Field | Meaning |
|---|---|
| `tool` | `pen` or `highlighter`. Unknown tools render as `pen` |
| `color`, `width` | `width` is the nominal width at full pressure |
| `pts.x`, `pts.y` | required, same length, at least 1 point |
| `pts.p` | pressure, 0 to 1000 |
| `pts.tilt` | angle between pencil and page: 900 = upright, 0 = flat |
| `pts.az` | azimuth of the pencil, 0 to 3599 |
| `pts.roll` | barrel roll, -1800 to 1800 |
| `pts.t` | milliseconds since the first point |

`p`, `tilt`, `az`, `roll`, `t` are optional; when present they have the same length as `x`.

There are no eraser objects. Erasing removes strokes or splits them into new strokes; the
same goes for clip-select.

### 7.2 `shape`

```json
{ "id": "r1", "type": "shape", "shape": "roundRect",
  "x": 5000, "y": 5000, "w": 12000, "h": 6000, "rotation": 0, "radius": 600,
  "stroke": { "color": "#1a1a1a", "width": 150, "dash": [600, 300] },
  "fill": "#ffcc0040" }

{ "id": "c1", "type": "shape", "shape": "connector",
  "points": [17000, 8000, 30000, 8000],
  "from": { "object": "r1", "anchor": "e" }, "to": { "object": "r2", "anchor": "w" },
  "end": "arrow",
  "stroke": { "color": "#1a1a1a", "width": 150 } }
```

| `shape` | Geometry |
|---|---|
| `rect`, `roundRect`, `ellipse`, `triangle` | box; `radius` for `roundRect` |
| `line`, `arrow`, `polygon`, `curve`, `connector` | `points`: flat list `[x0, y0, x1, y1, ...]`, at least 2 points. `polygon` is closed. `curve` passes smoothly through its points |

- `stroke`: `color`, `width`, optional `dash` (lengths of dashes and gaps). Absent = no outline.
- `fill`: colour, absent or `null` = no fill.
- `start`, `end`: `none` or `arrow`. Defaults: `arrow` has `end: "arrow"`, everything else `none`.
- `connector` only: `from` and `to`, each `{ "object": <id on this page>, "anchor": "n"|"e"|"s"|"w"|"c" }`.
  `points` always holds the last computed route, so a reader without connector logic can
  draw it as a plain line. If the referenced object is gone, the end stays where it is.

### 7.3 `text`

```json
{ "id": "t1", "type": "text", "x": 5000, "y": 40000, "w": 30000,
  "markdown": "## Free fall\ns = ½ g t², see [[Physics#Units]] #formula",
  "fontSize": 1200, "color": "#1a1a1a" }
```

`x`, `y`, `w` and `markdown` are required. The height follows from the text; `h` is
optional and, when present, is the height as last laid out. Text is Markdown
(CommonMark). `fontSize` defaults to 1200, `color` to the theme's text colour.

### 7.4 `image`

```json
{ "id": "i1", "type": "image", "asset": "9f86d0…0a08.png",
  "x": 5000, "y": 50000, "w": 20000, "h": 15000 }
```

### 7.5 `pdf`

```json
{ "id": "bg", "type": "pdf", "asset": "2c26b4…7ae.pdf", "page": 1,
  "x": 0, "y": 0, "w": 59528, "h": 84189 }
```

`page` counts from 1.

## 8. Links and tags

- Inside text: `[[Notebook]]`, `[[Notebook#Page title]]`, `[[#Page title]]` (same notebook),
  with an optional label `[[target|label]]`. Targets are matched by title, case-insensitive.
- A link that must survive renaming uses ids: `[[bn:<notebookId>/<pageId>]]`.
- On any object: `"link": "<target>"`, the same text as between the brackets. This is how
  "link a selection" is stored.
- Tags: `#word` inside text, plus the `tags` lists of pages and notebooks.
- Backlinks are never stored. Apps compute them by scanning.

## 9. Assets

`assets/<sha256>.<ext>`: the lowercase hex SHA-256 of the file's bytes, then the usual
extension (`png`, `jpg`, `webp`, `svg`, `pdf`). Objects refer to the file name. The same
file is therefore stored once, and an asset never changes. Apps delete unused assets only
on an explicit clean-up.

## 10. OCR sidecar `pages/<pageId>.ocr.json`

```json
{
  "format": "betternotes.ocr",
  "formatVersion": "1.0",
  "page": "0d6f6c0a-1d1b-4c58-9a57-3d0b7d3a8f10",
  "pageModified": "2026-11-10T12:30:00Z",
  "engine": "apple-vision",
  "items": [
    { "text": "Free fall", "x": 5000, "y": 3000, "w": 9000, "h": 1500, "confidence": 870 }
  ]
}
```

Derived data: it can be deleted and regenerated at any time. `pageModified` is the page's
`modified` when the recognition ran; if it differs from the page, the sidecar is stale.
It is a separate file so that devices that cannot recognise handwriting (the web app) can
still search it, and so that re-running recognition never touches the page file.

## 11. Conformance

`fixtures/valid/` holds notebooks every implementation must load and save without any
change in content (compared as parsed JSON, not as bytes). `fixtures/invalid/` holds single
files every implementation must reject. See `fixtures/README.md`.
