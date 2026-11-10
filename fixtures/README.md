# Conformance fixtures

Everything here is synthetic. Never put real notes in this folder.
Both reference implementations (`core/`, `packages/format-ts/`) run against these files.

| Folder | Every implementation must |
|---|---|
| `valid/*.bnote/` | accept every JSON file; load it and save it again with the same content (compared as parsed JSON: key order and whitespace do not matter) |
| `valid/future-minor.bnote/` | as above. It contains fields, object types, tools and shapes that version 1.0 does not know: all of it must survive |
| `readonly/` | recognise a newer major version: open read-only, refuse to save |
| `invalid/` | reject every file. The JSON schema rejects these too |
| `invalid-beyond-schema/` | reject every file. These break rules the JSON schema cannot express (array lengths, duplicate ids) |

Asset files in `valid/full.bnote/assets/` are a 1x1 PNG and a one-page empty PDF, named by
their SHA-256 as the format requires.
