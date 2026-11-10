// Shapes of the files described in docs/FORMAT.md.
// Files stay plain parsed JSON: fields and object types this code does not know are simply
// kept, which is what the format's forward-compatibility rule demands.

export type Json = null | boolean | number | string | Json[] | { [key: string]: Json };
export type JsonObject = { [key: string]: Json };

export interface Notebook {
  format: "betternotes.notebook";
  formatVersion: string;
  id: string;
  title: string;
  created: string;
  modified: string;
  tags?: string[];
  cover?: { color?: string; asset?: string };
  chapters: Chapter[];
}

export interface Chapter {
  id: string;
  title: string;
  order: number;
}

export interface Page {
  format: "betternotes.page";
  formatVersion: string;
  id: string;
  chapter: string | null;
  order: number;
  title?: string;
  created: string;
  modified: string;
  tags?: string[];
  size: { w: number; h: number };
  paper?: { type?: string; color?: string; lineColor?: string; spacing?: number };
  mirror?: { mode: string; cx?: number; cy?: number; count?: number };
  layers: Layer[];
}

export interface Layer {
  id: string;
  name: string;
  visible: boolean;
  locked: boolean;
  opacity?: number;
  objects: PageObject[];
}

interface ObjectBase {
  id: string;
  link?: string;
  x?: number;
  y?: number;
  w?: number;
  h?: number;
  rotation?: number;
}

export interface Stroke extends ObjectBase {
  type: "stroke";
  tool: string;
  color: string;
  width: number;
  pts: { x: number[]; y: number[]; p?: number[]; tilt?: number[]; az?: number[]; roll?: number[]; t?: number[] };
}

export interface Attachment {
  object: string;
  anchor: string;
}

export interface Shape extends ObjectBase {
  type: "shape";
  shape: string;
  points?: number[];
  radius?: number;
  stroke?: { color: string; width: number; dash?: number[] };
  fill?: string | null;
  start?: string;
  end?: string;
  from?: Attachment;
  to?: Attachment;
}

export interface TextBlock extends ObjectBase {
  type: "text";
  x: number;
  y: number;
  w: number;
  markdown: string;
  fontSize?: number;
  color?: string;
}

export interface ImageObject extends ObjectBase {
  type: "image";
  asset: string;
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface PdfObject extends ObjectBase {
  type: "pdf";
  asset: string;
  page: number;
  x: number;
  y: number;
  w: number;
  h: number;
}

/** An object type this version does not know. Keep it, never edit it. */
export interface UnknownObject extends ObjectBase {
  type: string;
  [key: string]: unknown;
}

export type KnownObject = Stroke | Shape | TextBlock | ImageObject | PdfObject;
export type PageObject = KnownObject | UnknownObject;

export interface OcrSidecar {
  format: "betternotes.ocr";
  formatVersion: string;
  page: string;
  pageModified: string;
  engine?: string;
  items: { text: string; x: number; y: number; w: number; h: number; confidence?: number }[];
}
