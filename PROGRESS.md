# Progress

Last updated: 2026-11-10

## Now

Milestone (a), step 3: the Swift package `core/` is written but has NEVER been compiled.
Next session, in this order:

1. Add `core/Sources/BetterNotesCore/Files.swift`: read a file from disk (migrating and
   backing up first if needed), atomic write (`Data.write(options: .atomic)`), and
   `backup()` into `.backup/<relative path>.<timestamp>`.
2. Add `core/Tests/BetterNotesCoreTests/ConformanceTests.swift`: the same tests as
   `packages/format-ts/test/conformance.test.ts` (valid fixtures unchanged by load + save,
   invalid rejected, readonly, ordering, migration with a fake table, typed edits keep
   unknown fields, atomic save + backup). Honour `BN_OUT_DIR` and `BN_FOREIGN_DIR`.
3. Add CI jobs: `core` on macos-26 (`needs: format-ts`, downloads artifact `ts-written`,
   runs `swift test`, uploads `swift-written`) and a final Ubuntu job that runs the
   TypeScript tests with `BN_FOREIGN_DIR` pointing at `swift-written`.
4. Fix compile errors from the CI log until green, then tag `v0.1`.

## Milestone status

| | Content | Status |
|---|---|---|
| a.1 | Rules files, empty app, CI builds unsigned .ipa, pre-release v0.0.1, SideStore guide | done; owner's install test pending (not blocking) |
| a.2 | `docs/FORMAT.md`, `schema/betternotes.schema.json`, synthetic fixtures | done |
| a.3 | `packages/format-ts/` | done, 11 tests pass locally |
| a.3 | `core/` Swift package | sources written, uncompiled, no tests, not in CI yet |
| a.4 | CI green on all jobs, tag v0.1 | todo |
| b | Drawing app + three-way latency spike + UI screenshot tests + OneDrive registration spike. CHECKPOINT | todo |
| c to m | see `docs/SCOPE.md` | todo |

## Waiting for the owner

1. Install test: follow `docs/SIDESTORE.md`, report the checklist at its end.

(Secret scanning and push protection were checked on 2026-11-10: both already enabled.)

## Open questions

- Does a private Microsoft account need an Entra directory to register an app? (spike in b)
- Does the school tenant allow the app, and does the app-folder scope work on a school
  OneDrive? (spike in b; outcomes table in `docs/ARCHITECTURE.md`)
- Custom ink latency vs PencilKit (spike in b).

## Deferred, with the milestone that picks it up

- SideStore source (`apps.json` on GitHub Pages): b, together with the Pages setup.
- App icon: f.
- Version number from the git tag instead of the fixed value in `ios/project.yml`: b.

## Owner's answers so far

- Licence GPL-3.0-or-later (apps) + CC0 (format).
- OneDrive: app folder only.
- The OneDrive account is a school account.
- No SideStore/AltStore installed before this project.
