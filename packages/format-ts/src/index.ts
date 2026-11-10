// TypeScript reference implementation of the betternotes format. Spec: docs/FORMAT.md.

import type { Json, JsonObject } from "./types.ts";
import { FORMAT_MAJOR, isObject, validate } from "./validate.ts";

export * from "./types.ts";
export * from "./validate.ts";

/** Upgrades a file by one major version. Keyed by the major version it upgrades FROM. */
export type Migrations = Record<number, (file: JsonObject) => JsonObject>;

/** Version 1 is the first format version, so there is nothing to migrate from yet. */
export const migrations: Migrations = {};

export type Loaded =
  | { status: "ok"; file: JsonObject; readOnly: boolean; migrated: boolean }
  | { status: "invalid"; errors: string[] };

/**
 * Parses and checks the text of a notebook, page or OCR file.
 * `migrated: true` means the caller must back up the original before saving (FORMAT.md, 3.4).
 */
export function load(text: string, table: Migrations = migrations): Loaded {
  let file: Json;
  try {
    file = JSON.parse(text);
  } catch (e) {
    return { status: "invalid", errors: [`$: not JSON (${(e as Error).message})`] };
  }
  let migrated = false;
  while (isObject(file) && typeof file.formatVersion === "string") {
    const major = Number(file.formatVersion.split(".")[0]);
    const step = table[major];
    if (!step || !(major < FORMAT_MAJOR)) break;
    file = step(file);
    migrated = true;
  }
  const v = validate(file);
  if (v.status === "invalid") return v;
  return { status: "ok", file: file as JsonObject, readOnly: v.status === "readOnly", migrated };
}

/**
 * The text to write to disk. Throws instead of producing a file that other devices could
 * not read, and for files from a newer major version (those are read-only).
 */
export function save(file: JsonObject): string {
  const v = validate(file);
  if (v.status === "readOnly") throw new Error("written by a newer version of betternotes: read-only");
  if (v.status === "invalid") throw new Error(`refusing to save an invalid file: ${v.errors.join("; ")}`);
  return serialize(file);
}

/** Compact JSON with sorted keys, so the same content always gives the same text. */
export function serialize(value: Json): string {
  return JSON.stringify(value, (_key, v) =>
    isObject(v) ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, v[k]])) : v,
  );
}

// ---- Ordering of chapters and pages (FORMAT.md, "Ordering")

export const ORDER_STEP = 1024;

/**
 * An `order` between two neighbours (null = no neighbour on that side).
 * Returns null when there is no gap left: renumber the siblings with `renumbered` first.
 */
export function orderBetween(before: number | null, after: number | null): number | null {
  if (before === null) return after === null ? ORDER_STEP : after - ORDER_STEP;
  if (after === null) return before + ORDER_STEP;
  const middle = Math.floor((before + after) / 2);
  return middle > before && middle < after ? middle : null;
}

/** Fresh `order` values for `count` items that are already in the right sequence. */
export function renumbered(count: number): number[] {
  return Array.from({ length: count }, (_, i) => (i + 1) * ORDER_STEP);
}

/** Sorts by `order`, ties by `id`. Returns a new array. */
export function sorted<T extends { id: string; order: number }>(items: readonly T[]): T[] {
  return [...items].sort((a, b) => a.order - b.order || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
}

export function timestamp(date: Date = new Date()): string {
  return date.toISOString().slice(0, 19) + "Z";
}
