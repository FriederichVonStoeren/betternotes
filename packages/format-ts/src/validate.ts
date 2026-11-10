// Checks a parsed file against docs/FORMAT.md.
// core/Sources/BetterNotesCore/Validate.swift is the same code in Swift: change both together.
// Unknown fields and unknown object types are never an error.

import type { Json, JsonObject } from "./types.ts";

export const FORMAT_MAJOR = 1;
export const FORMAT_MINOR = 0;
export const FORMAT_VERSION = `${FORMAT_MAJOR}.${FORMAT_MINOR}`;

export type Validation =
  | { status: "ok" }
  /** Written by a newer major version: show it if you can, never save it. */
  | { status: "readOnly" }
  | { status: "invalid"; errors: string[] };

const ID = /^[A-Za-z0-9_-]{1,64}$/;
const TIME = /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$/;
const COLOR = /^#([0-9a-f]{6}|[0-9a-f]{8})$/;
const ASSET = /^[0-9a-f]{64}\.[a-z0-9]{1,8}$/;
const VERSION = /^[0-9]+\.[0-9]+$/;

const BOX_SHAPES = ["rect", "roundRect", "ellipse", "triangle"];
const PATH_SHAPES = ["line", "arrow", "polygon", "curve", "connector"];

export function isObject(v: Json | undefined): v is JsonObject {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

interface Opt {
  optional?: boolean;
  nullable?: boolean;
  re?: RegExp;
  min?: number;
  max?: number;
}

class Checker {
  errors: string[] = [];

  fail(path: string, message: string): void {
    this.errors.push(`${path}: ${message}`);
  }

  /** The field's value, or undefined when there is nothing (more) to check. */
  private field(o: JsonObject, key: string, path: string, opt: Opt): Json | undefined {
    const v = o[key];
    if (v === undefined) {
      if (!opt.optional) this.fail(`${path}.${key}`, "missing");
      return undefined;
    }
    if (v === null && opt.nullable) return undefined;
    return v;
  }

  str(o: JsonObject, key: string, path: string, opt: Opt = {}): void {
    const v = this.field(o, key, path, opt);
    if (v === undefined) return;
    if (typeof v !== "string") this.fail(`${path}.${key}`, "must be a string");
    else if (opt.re && !opt.re.test(v)) this.fail(`${path}.${key}`, "has the wrong form");
  }

  int(o: JsonObject, key: string, path: string, opt: Opt = {}): void {
    const v = this.field(o, key, path, opt);
    if (v === undefined) return;
    if (typeof v !== "number" || !Number.isInteger(v)) this.fail(`${path}.${key}`, "must be an integer");
    else if ((opt.min !== undefined && v < opt.min) || (opt.max !== undefined && v > opt.max))
      this.fail(`${path}.${key}`, "is out of range");
  }

  bool(o: JsonObject, key: string, path: string): void {
    const v = this.field(o, key, path, {});
    if (v !== undefined && typeof v !== "boolean") this.fail(`${path}.${key}`, "must be true or false");
  }

  obj(o: JsonObject, key: string, path: string, opt: Opt = {}): JsonObject | undefined {
    const v = this.field(o, key, path, opt);
    if (v === undefined) return undefined;
    if (isObject(v)) return v;
    this.fail(`${path}.${key}`, "must be an object");
    return undefined;
  }

  arr(o: JsonObject, key: string, path: string, opt: Opt = {}): Json[] | undefined {
    const v = this.field(o, key, path, opt);
    if (v === undefined) return undefined;
    if (Array.isArray(v)) return v;
    this.fail(`${path}.${key}`, "must be a list");
    return undefined;
  }

  /** A list of integers with at least opt.min entries. Returns its length. */
  ints(o: JsonObject, key: string, path: string, opt: Opt = {}): number | undefined {
    const a = this.arr(o, key, path, opt);
    if (a === undefined) return undefined;
    if (!a.every((n) => typeof n === "number" && Number.isInteger(n))) this.fail(`${path}.${key}`, "must contain only integers");
    else if (a.length < (opt.min ?? 0)) this.fail(`${path}.${key}`, "has too few entries");
    return a.length;
  }

  strs(o: JsonObject, key: string, path: string, opt: Opt = {}): void {
    const a = this.arr(o, key, path, opt);
    if (a !== undefined && !a.every((s) => typeof s === "string")) this.fail(`${path}.${key}`, "must contain only strings");
  }

  /** Each entry of a list that must contain objects, with its path. */
  objects(o: JsonObject, key: string, path: string): [JsonObject, string][] {
    const out: [JsonObject, string][] = [];
    (this.arr(o, key, path) ?? []).forEach((v, i) => {
      if (isObject(v)) out.push([v, `${path}.${key}[${i}]`]);
      else this.fail(`${path}.${key}[${i}]`, "must be an object");
    });
    return out;
  }

  unique(ids: Json[], path: string, what: string): void {
    const seen = new Set<Json>();
    for (const id of ids) {
      if (typeof id !== "string") continue;
      if (seen.has(id)) this.fail(path, `duplicate ${what} id "${id}"`);
      seen.add(id);
    }
  }
}

export function validate(file: Json): Validation {
  if (!isObject(file)) return { status: "invalid", errors: ["$: must be an object"] };
  const format = file.format;
  const version = file.formatVersion;
  if (format !== "betternotes.notebook" && format !== "betternotes.page" && format !== "betternotes.ocr")
    return { status: "invalid", errors: ["$.format: unknown or missing"] };
  if (typeof version !== "string" || !VERSION.test(version))
    return { status: "invalid", errors: ["$.formatVersion: must look like \"1.0\""] };
  const major = Number(version.split(".")[0]);
  if (major > FORMAT_MAJOR) return { status: "readOnly" };
  if (major < FORMAT_MAJOR) return { status: "invalid", errors: ["$.formatVersion: older major version, migrate first"] };

  const c = new Checker();
  if (format === "betternotes.notebook") notebook(c, file);
  else if (format === "betternotes.page") page(c, file);
  else ocr(c, file);
  return c.errors.length === 0 ? { status: "ok" } : { status: "invalid", errors: c.errors };
}

function notebook(c: Checker, o: JsonObject): void {
  const p = "$";
  c.str(o, "id", p, { re: ID });
  c.str(o, "title", p);
  c.str(o, "created", p, { re: TIME });
  c.str(o, "modified", p, { re: TIME });
  c.strs(o, "tags", p, { optional: true });
  const cover = c.obj(o, "cover", p, { optional: true });
  if (cover) {
    c.str(cover, "color", `${p}.cover`, { optional: true, re: COLOR });
    c.str(cover, "asset", `${p}.cover`, { optional: true, re: ASSET });
  }
  const chapters = c.objects(o, "chapters", p);
  for (const [ch, cp] of chapters) {
    c.str(ch, "id", cp, { re: ID });
    c.str(ch, "title", cp);
    c.int(ch, "order", cp);
  }
  c.unique(chapters.map(([ch]) => ch.id ?? null), `${p}.chapters`, "chapter");
}

function page(c: Checker, o: JsonObject): void {
  const p = "$";
  c.str(o, "id", p, { re: ID });
  c.str(o, "chapter", p, { re: ID, nullable: true });
  c.int(o, "order", p);
  c.str(o, "title", p, { optional: true });
  c.str(o, "created", p, { re: TIME });
  c.str(o, "modified", p, { re: TIME });
  c.strs(o, "tags", p, { optional: true });
  const size = c.obj(o, "size", p);
  if (size) {
    c.int(size, "w", `${p}.size`, { min: 1 });
    c.int(size, "h", `${p}.size`, { min: 1 });
  }
  const paper = c.obj(o, "paper", p, { optional: true });
  if (paper) {
    c.str(paper, "type", `${p}.paper`, { optional: true });
    c.str(paper, "color", `${p}.paper`, { optional: true, re: COLOR });
    c.str(paper, "lineColor", `${p}.paper`, { optional: true, re: COLOR });
    c.int(paper, "spacing", `${p}.paper`, { optional: true, min: 1 });
  }
  const mirror = c.obj(o, "mirror", p, { optional: true });
  if (mirror) {
    c.str(mirror, "mode", `${p}.mirror`);
    c.int(mirror, "cx", `${p}.mirror`, { optional: true });
    c.int(mirror, "cy", `${p}.mirror`, { optional: true });
    c.int(mirror, "count", `${p}.mirror`, { optional: true, min: 2 });
  }
  const layers = c.objects(o, "layers", p);
  const objectIds: Json[] = [];
  for (const [layer, lp] of layers) {
    c.str(layer, "id", lp, { re: ID });
    c.str(layer, "name", lp);
    c.bool(layer, "visible", lp);
    c.bool(layer, "locked", lp);
    c.int(layer, "opacity", lp, { optional: true, min: 0, max: 1000 });
    for (const [obj, op] of c.objects(layer, "objects", lp)) {
      object(c, obj, op);
      objectIds.push(obj.id ?? null);
    }
  }
  c.unique(layers.map(([l]) => l.id ?? null), `${p}.layers`, "layer");
  c.unique(objectIds, `${p}.layers`, "object");
}

function object(c: Checker, o: JsonObject, p: string): void {
  c.str(o, "id", p, { re: ID });
  c.str(o, "type", p);
  c.str(o, "link", p, { optional: true });
  const type = o.type;
  const shape = o.shape;
  // Which kinds must have a box: text needs no height, path shapes need no box at all.
  const needsBox = type === "image" || type === "pdf" || (type === "shape" && typeof shape === "string" && BOX_SHAPES.includes(shape));
  const needsXYW = needsBox || type === "text";
  c.int(o, "x", p, { optional: !needsXYW });
  c.int(o, "y", p, { optional: !needsXYW });
  c.int(o, "w", p, { optional: !needsXYW, min: 0 });
  c.int(o, "h", p, { optional: !needsBox, min: 0 });
  c.int(o, "rotation", p, { optional: true });

  if (type === "stroke") {
    c.str(o, "tool", p);
    c.str(o, "color", p, { re: COLOR });
    c.int(o, "width", p, { min: 0 });
    const pts = c.obj(o, "pts", p);
    if (pts) {
      const pp = `${p}.pts`;
      const n = c.ints(pts, "x", pp, { min: 1 });
      const lengths = [c.ints(pts, "y", pp, { min: 1 })];
      for (const key of ["p", "tilt", "az", "roll", "t"]) lengths.push(c.ints(pts, key, pp, { optional: true }));
      if (n !== undefined && lengths.some((len) => len !== undefined && len !== n))
        c.fail(pp, "all lists must have the same length as x");
    }
  } else if (type === "shape") {
    c.str(o, "shape", p);
    const needsPoints = typeof shape === "string" && PATH_SHAPES.includes(shape);
    const n = c.ints(o, "points", p, { optional: !needsPoints, min: 4 });
    if (n !== undefined && n % 2 !== 0) c.fail(`${p}.points`, "must have an even number of entries");
    c.int(o, "radius", p, { optional: true, min: 0 });
    const stroke = c.obj(o, "stroke", p, { optional: true });
    if (stroke) {
      c.str(stroke, "color", `${p}.stroke`, { re: COLOR });
      c.int(stroke, "width", `${p}.stroke`, { min: 0 });
      c.ints(stroke, "dash", `${p}.stroke`, { optional: true });
    }
    c.str(o, "fill", p, { optional: true, nullable: true, re: COLOR });
    c.str(o, "start", p, { optional: true });
    c.str(o, "end", p, { optional: true });
    for (const key of ["from", "to"]) {
      const a = c.obj(o, key, p, { optional: true });
      if (a) {
        c.str(a, "object", `${p}.${key}`, { re: ID });
        c.str(a, "anchor", `${p}.${key}`);
      }
    }
  } else if (type === "text") {
    c.str(o, "markdown", p);
    c.int(o, "fontSize", p, { optional: true, min: 1 });
    c.str(o, "color", p, { optional: true, re: COLOR });
  } else if (type === "image") {
    c.str(o, "asset", p, { re: ASSET });
  } else if (type === "pdf") {
    c.str(o, "asset", p, { re: ASSET });
    c.int(o, "page", p, { min: 1 });
  }
}

function ocr(c: Checker, o: JsonObject): void {
  const p = "$";
  c.str(o, "page", p, { re: ID });
  c.str(o, "pageModified", p, { re: TIME });
  c.str(o, "engine", p, { optional: true });
  for (const [item, ip] of c.objects(o, "items", p)) {
    c.str(item, "text", ip);
    c.int(item, "x", ip);
    c.int(item, "y", ip);
    c.int(item, "w", ip, { min: 0 });
    c.int(item, "h", ip, { min: 0 });
    c.int(item, "confidence", ip, { optional: true, min: 0, max: 1000 });
  }
}
