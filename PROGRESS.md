# Progress

Last updated: 2026-11-10

## Now

Milestone (b): drawing app with the three-way latency spike, UI screenshot tests,
OneDrive registration spike, SideStore source. Ends in a CHECKPOINT (owner tests drawing feel).

## Milestone status

| | Content | Status |
|---|---|---|
| a | Rules files, empty-app .ipa in CI, FORMAT.md + schema + fixtures, Swift and TypeScript packages, cross-language tests | done, tagged v0.1 (14 Swift tests, 11 TypeScript tests, each implementation reads the other's output in CI) |
| b | Drawing app + three-way latency spike + UI screenshot tests + OneDrive registration spike. CHECKPOINT | in progress |
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
