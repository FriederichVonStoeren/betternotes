// Runs the shared fixtures (fixtures/README.md) and the cross-language check.
//   BN_OUT_DIR      if set, every valid fixture is saved there (CI hands these to the Swift tests)
//   BN_FOREIGN_DIR  if set, files written by the Swift implementation are compared with the fixtures

import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { Ajv2020 } from "ajv/dist/2020.js";
import { load, migrations, orderBetween, renumbered, save, serialize, sorted, timestamp, validate } from "../src/index.ts";
import type { JsonObject, Page } from "../src/index.ts";

const root = join(import.meta.dirname, "../../..");
const fixtures = join(root, "fixtures");
const read = (path: string) => readFileSync(path, "utf8");
const jsonFiles = (dir: string): string[] =>
  readdirSync(dir, { recursive: true, encoding: "utf8" })
    .filter((f) => f.endsWith(".json"))
    .map((f) => join(dir, f))
    .sort();

const schema = new Ajv2020().compile(JSON.parse(read(join(root, "schema/betternotes.schema.json"))));
const valid = jsonFiles(join(fixtures, "valid"));

test("fixtures exist", () => {
  assert.ok(valid.length >= 8);
  assert.ok(jsonFiles(join(fixtures, "invalid")).length >= 25);
});

test("valid fixtures: accepted, and unchanged by load + save", () => {
  for (const path of valid) {
    const original = JSON.parse(read(path));
    assert.ok(schema(original), `${path}: schema says ${JSON.stringify(schema.errors)}`);
    const loaded = load(read(path));
    assert.equal(loaded.status, "ok", `${path}: ${JSON.stringify(loaded)}`);
    if (loaded.status !== "ok") continue;
    assert.equal(loaded.readOnly, false, path);
    assert.equal(loaded.migrated, false, path);
    const written = save(loaded.file);
    assert.deepEqual(JSON.parse(written), original, path);
    if (process.env.BN_OUT_DIR) {
      const out = join(process.env.BN_OUT_DIR, relative(join(fixtures, "valid"), path));
      mkdirSync(dirname(out), { recursive: true });
      writeFileSync(out, written);
    }
  }
});

test("invalid fixtures: rejected", () => {
  for (const path of jsonFiles(join(fixtures, "invalid"))) {
    assert.equal(load(read(path)).status, "invalid", path);
    assert.equal(schema(JSON.parse(read(path))), false, `${path}: the schema should reject this too`);
  }
  for (const path of jsonFiles(join(fixtures, "invalid-beyond-schema"))) {
    assert.equal(load(read(path)).status, "invalid", path);
    assert.equal(schema(JSON.parse(read(path))), true, `${path}: belongs in invalid/, the schema catches it`);
  }
  assert.equal(load("{ not json").status, "invalid");
});

test("newer major version: read-only, cannot be saved", () => {
  for (const path of jsonFiles(join(fixtures, "readonly"))) {
    const loaded = load(read(path));
    assert.ok(loaded.status === "ok" && loaded.readOnly, path);
    if (loaded.status === "ok") assert.throws(() => save(loaded.file), /read-only/, path);
  }
});

test("save refuses an invalid file", () => {
  const page = JSON.parse(read(join(fixtures, "valid/minimal.bnote/pages/p-min.json"))) as JsonObject;
  delete page.size;
  assert.throws(() => save(page), /invalid/);
});

test("editing a page keeps what this version does not know", () => {
  const path = join(fixtures, "valid/future-minor.bnote/pages/p-future.json");
  const loaded = load(read(path));
  assert.equal(loaded.status, "ok");
  if (loaded.status !== "ok") return;
  const page = loaded.file as unknown as Page;
  page.layers[0]!.objects.push({ id: "new", type: "text", x: 0, y: 0, w: 100, markdown: "added" });
  const after = JSON.parse(save(loaded.file));
  const before = JSON.parse(read(path));
  assert.equal(after.formatVersion, "1.7");
  assert.equal(after.futurePageField, "keep me");
  assert.deepEqual(after.layers[0].objects.slice(0, 5), before.layers[0].objects);
  assert.equal(after.layers[0].blendMode, "multiply");
});

test("serialize: same content gives the same text", () => {
  assert.equal(serialize({ b: 1, a: { d: [3, { z: 1, y: 2 }], c: "ü" } }), '{"a":{"c":"ü","d":[3,{"y":2,"z":1}]},"b":1}');
});

test("migrations run in order and report that a backup is needed", () => {
  assert.deepEqual(migrations, {});
  const old = JSON.stringify({ format: "betternotes.ocr", formatVersion: "0.3", pageId: "p", items: [] });
  assert.equal(load(old).status, "invalid");
  const loaded = load(old, {
    0: (f) => ({ format: f.format!, formatVersion: "1.0", page: f.pageId!, pageModified: "2026-01-01T00:00:00Z", items: f.items! }),
  });
  assert.ok(loaded.status === "ok" && loaded.migrated && !loaded.readOnly);
  if (loaded.status === "ok") assert.equal(loaded.file.page, "p");
});

test("ordering", () => {
  assert.equal(orderBetween(null, null), 1024);
  assert.equal(orderBetween(1024, null), 2048);
  assert.equal(orderBetween(null, 1024), 0);
  assert.equal(orderBetween(1024, 2048), 1536);
  assert.equal(orderBetween(-3, 0), -2);
  assert.equal(orderBetween(5, 6), null);
  assert.equal(orderBetween(5, 5), null);
  assert.deepEqual(renumbered(3), [1024, 2048, 3072]);
  const items = [{ id: "b", order: 2 }, { id: "c", order: 1 }, { id: "a", order: 2 }];
  assert.deepEqual(sorted(items).map((i) => i.id), ["c", "a", "b"]);
});

test("timestamp has the form the format requires", () => {
  assert.equal(timestamp(new Date(Date.UTC(2026, 10, 10, 12, 0, 0, 999))), "2026-11-10T12:00:00Z");
  assert.equal(validate({ format: "betternotes.ocr", formatVersion: "1.0", page: "p", pageModified: timestamp(), items: [] }).status, "ok");
});

test("files written by the Swift implementation have the same content", { skip: !process.env.BN_FOREIGN_DIR }, () => {
  const foreign = process.env.BN_FOREIGN_DIR!;
  const files = jsonFiles(foreign);
  assert.equal(files.length, valid.length, "Swift should have written every valid fixture");
  for (const path of files) {
    const loaded = load(read(path));
    assert.equal(loaded.status, "ok", path);
    assert.deepEqual(JSON.parse(read(path)), JSON.parse(read(join(fixtures, "valid", relative(foreign, path)))), path);
  }
});
