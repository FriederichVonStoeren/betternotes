# Progress

Last updated: 2026-11-10

## Now

Milestone (a), step 2: FORMAT.md + JSON schema + fixtures.

## Milestone status

| | Content | Status |
|---|---|---|
| a.1 | Rules files, empty app, CI builds unsigned .ipa, pre-release v0.0.1, SideStore guide | done, waiting for the owner's install test (not blocking) |
| a.2 | `docs/FORMAT.md`, `schema/betternotes.schema.json`, synthetic fixtures | next |
| a.3 | `core/` Swift package + `packages/format-ts/`, content-based conformance tests | todo |
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
