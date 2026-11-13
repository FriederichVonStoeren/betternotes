# Progress

Last updated: 2026-11-10

## Now

CHECKPOINT (b): waiting for the owner to test the drawing feel (`docs/CHECKPOINT_B.md`),
the install (`docs/SIDESTORE.md`) and the OneDrive login (`docs/MICROSOFT_APP.md`).
Next after the report: milestone (c).

## Milestone status

| | Content | Status |
|---|---|---|
| a | Rules files, empty-app .ipa in CI, FORMAT.md + schema + fixtures, Swift and TypeScript packages, cross-language tests | done, tagged v0.1 (14 Swift tests, 11 TypeScript tests, each implementation reads the other's output in CI) |
| b | Drawing app + three-way latency spike + UI screenshot tests + OneDrive registration spike. CHECKPOINT | built, tagged v0.2; CI screenshots show all three modes drawing. Waiting for the device test |
| c to m | see `docs/SCOPE.md` | todo |

## Waiting for the owner

All steps and questions in one place: `docs/OWNER_TODO.md`.

1. Install test: follow `docs/SIDESTORE.md`, report the checklist at its end.
2. Drawing test: `docs/CHECKPOINT_B.md`, report the checklist at its end.
3. OneDrive test: `docs/MICROSOFT_APP.md`, send the copied report.

(Secret scanning and push protection were checked on 2026-11-10: both already enabled.)

## Open questions

- Does a private Microsoft account need an Entra directory to register an app? (spike in b)
- Does the school tenant allow the app, and does the app-folder scope work on a school
  OneDrive? (spike in b; outcomes table in `docs/ARCHITECTURE.md`)
- Custom ink latency vs PencilKit (spike in b).

## Deferred, with the milestone that picks it up

- Final app icon: f (a placeholder exists).
- Selection option `multilayerselection` (current layer / selected layers / all layers): picked up with the selector and layers work in c. Noted 2026-11-13, no code yet.

Done early: SideStore source (`apps.json` on GitHub Pages), version number from the git tag.

## Owner's answers so far

- Licence GPL-3.0-or-later (apps) + CC0 (format).
- OneDrive: app folder only.
- The OneDrive account is a school account.
- No SideStore/AltStore installed before this project.
