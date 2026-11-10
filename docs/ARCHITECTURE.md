# betternotes: architecture proposal (revision 2)

## Context

The repo is empty (only `README.md`). You asked for a short architecture proposal first, with no app code until you say OK. Approving this plan is that OK: I then start milestone (a) and continue on my own until the first checkpoint (b).

Local state I checked: Node 22 is installed, Swift is not. So Swift code is only ever compiled and tested in GitHub Actions; the TypeScript side I can test locally.

Changed in this revision: empty-app .ipa as the very first CI job, content-based format tests with integer points and a raw JSON layer in Swift, an early Microsoft registration spike, simulator UI tests with screenshots, the companion scope, the AI integration, the no-extensions rule, and the six smaller points.

## Stack

| Part | Choice | Why |
|---|---|---|
| iPad app | Swift, SwiftUI shell + one UIKit canvas view | SwiftUI for library/tabs/settings (little code); UIKit for touch input, where SwiftUI is too slow and too limited |
| Core logic | Swift Package `BetterNotesCore` (format, geometry, sync), Foundation only | Unit-testable in CI without a UI |
| Project generation | **XcodeGen** (`project.yml`) | One small YAML file, `brew install xcodegen` on the runner. Tuist is heavier, pure SwiftPM cannot build an iOS app bundle |
| Web companion | TypeScript + Vite + Svelte, `vite-plugin-pwa`, pdf.js | Small, readable components; canvas 2D for drawing |
| Format packages | `BetterNotesCore` (Swift) and `packages/format-ts` (TypeScript) | Both run the same fixtures in `fixtures/` |
| Licence | **GPL-3.0-or-later** for the apps, **CC0** for FORMAT.md + JSON schema | Apps stay open for good; anyone may implement the format |
| Deployment target | iPadOS 18.0 | Covers every Pencil Pro API; your iPad runs newer anyway |

Repo layout:

```
CLAUDE.md  PROGRESS.md  README.md  LICENSE  .gitignore
docs/        FORMAT.md, DECISIONS.md, setup guides (SideStore, Actions, Microsoft app)
schema/      betternotes.schema.json
fixtures/    synthetic conformance fixtures (valid, invalid, unknown-fields, migrations)
core/        Swift Package BetterNotesCore + tests
ios/         project.yml (XcodeGen) + thin app target + UI tests
web/         PWA
packages/format-ts/
spikes/      throwaway test pages (e.g. the OneDrive login test)
private-samples/   (gitignored)
```

**One app, no app extensions.** A free Apple ID allows 3 sideloaded apps at a time and 10 app IDs per week, and every extension uses up one app ID. SideStore itself takes one slot. So betternotes is a single app target: no share extension, no widget, no Quick Look extension. Importing files works through the document picker, drag and drop and "Open in betternotes".

## Ink engine: custom, not PencilKit

PencilKit gives excellent latency for free, but its canvas is a black box: no layers, no own object types (shapes, connectors), no live mirrored strokes, and its eraser and lasso cannot be replaced with clip-select. Stacking several `PKCanvasView`s as layers breaks down as soon as a selection crosses layers.

So: own stroke model (it is the file format anyway), own rendering. Input from `UITouch` with coalesced and predicted touches; finished strokes cached as bitmaps per layer, the live stroke drawn on top. First version renders with Core Graphics; Metal only if the spike shows it is needed.

Milestone (b) is the proof: the hello-world app has a PencilKit canvas and the custom canvas side by side with an on-screen latency readout, and you judge the feel.

Fallback if custom feels clearly worse and Metal does not fix it: PencilKit draws the live stroke only, and on pen-up it is converted to our model and redrawn by our renderer. The known weak spot is a visible **jump in the stroke's shape** at that moment, because PencilKit's ink and ours never match exactly in width and taper. The spike includes this third mode, so you can see whether the jump is acceptable before we would ever depend on it.

Pencil Pro APIs (all public, no entitlement needed): squeeze and double-tap via `UIPencilInteraction`, roll via `UITouch.rollAngle`, hover via `UIHoverGestureRecognizer`, pressure/tilt via `UITouch`. I verify each against current Apple docs before using it. Squeeze and double-tap actions are configurable (quick-switch tool, toggle eraser, open palette).

## Data model and format

A notebook is a plain folder:

```
MyNotebook.bnote/
  notebook.json          title, tags, chapters (id, title, order), formatVersion
  pages/<uuid>.json      one page: size, background, layers[], objects per layer
  pages/<uuid>.ocr.json  recognised handwriting text (so the web app can search it)
  assets/<sha256>.<ext>  images and PDFs, immutable, named by content hash
```

- Each page stores its own chapter id and a sort key, so adding or moving a page touches one page file, not the notebook file.
- Objects in a layer: `stroke`, `shape`, `text` (Markdown, `[[links]]`), `image`, plus `pdfBackground` as a locked base layer referencing asset + page number.
- **Stroke points are rounded integers**, stored as parallel arrays: x and y in 1/100 pt, pressure 0 to 1000, tilt, azimuth and **roll angle** in 1/10 degree, time in ms since stroke start. Integers make files smaller and remove every floating-point difference between Swift and TypeScript.
- **Swift raw JSON layer.** Swift's standard decoder (`Codable`) silently drops fields it does not know. So the Swift package keeps every file as a raw JSON tree (a small `JSONValue` type) and the typed model reads from and writes into that tree. Unknown fields and unknown object types therefore survive a load and save untouched. TypeScript keeps plain objects, which do this naturally. This is the rule that stops the web app from damaging iPad content.
- `formatVersion` is major.minor: a newer minor opens normally, a newer major opens read-only.
- Safety: write to a temp file, then atomic rename; autosave; the previous version is copied to `.backup/` before a migration or a conflict resolution.

**Conformance tests compare content, not bytes.** Each test parses the expected and the actual JSON and compares the values (key order and whitespace do not matter). Cases: load and save keeps everything including unknown fields; a file saved by Swift loads in TypeScript and the other way round (CI passes the written files between the two jobs); invalid fixtures are rejected; migrations produce the expected result.

## Sync (OneDrive)

- Microsoft Graph with OAuth 2.0 PKCE, done by hand (about 150 lines per platform) instead of the MSAL library: MSAL on iOS wants a keychain-sharing entitlement, a risk with free-account sideloading. iPad uses `ASWebAuthenticationSession` with a custom URL scheme; the PWA redirects to its GitHub Pages URL.
- Scope `Files.ReadWrite.AppFolder`: the app only sees its own folder `Apps/betternotes/`.
- Offline-first: the local folder is the truth. Download changes with Graph delta queries. Upload with `If-Match: <eTag>`; if the server version changed meanwhile, nothing is overwritten: the other version is kept as a conflict copy and shown in the UI.
- **The sync-state file stays on the device** (last known eTag per file, delta token). It lives outside the notebook folder and is never uploaded, because each device has its own view of the server.
- **`notebook.json` is merged automatically** instead of producing conflict copies: chapters are merged by id, tags as a set, and for a field changed on both sides the newer one wins. The old version still goes to `.backup/`. Page files are never auto-merged.
- The decision logic (upload, download, conflict, merge) is pure and lives in the core package with tests; the network part is a thin layer.

**Early registration spike (during milestone b, not g).** Open point to settle first: whether a personal Microsoft account can still register an app without an Entra (Azure) directory. I believe Microsoft now requires a directory, which means a free Azure sign-up; I check the current rules and write click-by-click steps for whichever path works. Then a one-page test site in `spikes/onedrive/` on GitHub Pages: you press "Sign in", and it reports whether login, creating the app folder, uploading a file and a delta query worked. If this fails for personal accounts we know months before milestone (g) and can change the sync design.

## Web companion scope

- View everything: strokes, layers, shapes, PDFs, chapters, links.
- Type and edit text blocks, paste text and images, search, library and graph, export PDF/SVG/PNG.
- Basic drawing: freehand pen, highlighter, eraser; basic shapes and arrows; layers (show/hide, reorder, move to layer); select and move whole objects.
- Not built: clip-select, mirror mode, advanced shape tools (connectors, align/distribute), iPad-level pen feel.
- Objects it does not understand are shown as a placeholder where possible and always preserved on save.

## Opt-in Claude / Perplexity

- Your own API keys, typed into the app: Keychain on the iPad, encrypted local storage on the web. Never in the repo, never synced.
- Nothing is sent unless you trigger it ("Ask Claude about this selection", "Research with Perplexity"). Before sending, the app shows what will be sent. The answer is inserted as a text block.
- One small provider interface (`send(prompt, attachments) -> text`) with two implementations, so another provider is one file. No AI features beyond these two actions.

## CI

One workflow, on every push:

1. `ios` (built first, in milestone a): `xcodegen generate`, `xcodebuild` with code signing disabled, zip `Payload/` into `betternotes.ipa`, upload as artifact.
2. `core`: `swift test` on macOS only. No simulator run for the core package; it has no UI code.
3. `web`: `npm test` + build on Ubuntu; deploy to GitHub Pages from main.
4. `ui-tests`: XCUITest on an iPad simulator. Each test opens a screen and saves screenshots; CI exports them from the test result as an artifact. I download and look at them after each push, so layout and navigation bugs are caught before your checkpoints. Limit: the simulator has no Pencil, so pressure, latency and feel still need you.
5. On a `v*` tag: GitHub Release with the .ipa, and `apps.json` (SideStore source) updated on GitHub Pages.

macOS runner minutes are free for public repos.

## Top risks, honestly

1. **First SideStore install without a Mac.** Weekly refresh works on the iPad itself, but the very first install needs a computer, on Fedora a Linux installer tool. Most likely step to cost you an evening, which is why the empty app comes first.
2. **No Mac for me either.** Screenshots from simulator UI tests cover layout; everything Pencil-related is only found by you. Each fix is a CI round trip of roughly 10 minutes.
3. **Custom ink latency.** May not match PencilKit at first. The spike decides, including the fallback's shape jump.
4. **Handwriting OCR.** Apple's Vision text recognition is the only local option; Apple's own handwriting engine has no public API. Expect usable search for neat print handwriting, weak results for cursive, mixed German/English and maths.
5. **Microsoft registration and PWA login lifetime.** The directory question above; and Microsoft limits browser-app refresh tokens to 24 hours, so the web app may ask you to sign in again daily (usually one click). Browser storage can be cleared by the browser; the PWA asks for persistent storage, and OneDrive remains the real copy.
6. **Mebis.** Logged-in automation is probably blocked and may be against the terms. Expect the manual flow. PPTX/DOCX: the iPad can render them with the system viewer and save as PDF (good quality); the web app cannot, so there it is PDF-only.
7. **.goodnotes.** Proprietary and undocumented. Realistic: pages, PDFs and images recovered; strokes maybe; text boxes unknown until I see your sample.
8. **Scope.** Very large. Connectors, clip-select and the graph view are each substantial. I build the smallest working version of each first.

## Milestone (a), in order

1. **Empty app + CI job that builds the .ipa.** The same first commit carries `.gitignore`, `CLAUDE.md`, `PROGRESS.md`, `docs/DECISIONS.md` and `LICENSE` (the .gitignore has to exist before anything else is pushed). The .ipa is published as pre-release `v0.0.1`, with `docs/SIDESTORE.md` giving the Fedora install steps. You test the install while I continue with the format; it is not a blocking checkpoint.
2. `docs/FORMAT.md` + `schema/betternotes.schema.json` + synthetic fixtures.
3. `core/` Swift package (raw JSON layer, typed model, atomic write, migration hook) and `packages/format-ts/`; both test against `fixtures/` by content.
4. CI green on all jobs; tag `v0.1`.

Then milestone (b): drawing app with the three-way spike (PencilKit, custom, fallback), first UI screenshot test, the OneDrive registration spike. Stop at the checkpoint with test instructions.

Along the way you get the steps for GitHub secret scanning + push protection and for enabling GitHub Pages.

## Verification

- (a): the `v0.0.1` .ipa exists as a release asset; CI green; cross-language test passes (Swift-written files load in TypeScript and back, compared by content, unknown fields intact).
- Later milestones: CI green, UI screenshots reviewed by me, tagged release; device behaviour verified by you at checkpoints with a done/not-done list.

## Your answers (settled)

1. Licence: GPL-3.0-or-later for the apps, CC0 for the format.
2. OneDrive scope: app folder only.
3. Your OneDrive is a **school account**. See below, this changes the sync risk.
4. No SideStore or AltStore yet: `docs/SIDESTORE.md` starts from zero (Apple ID, installer on Fedora, pairing, first install, weekly refresh).

## What the school account means

- **Who registers the app.** A school directory normally does not let students register apps. You will most likely register it with a private Microsoft account (free), set to "any organisation and personal accounts", so it works for your school login and for friends.
- **The school can block it.** Many school directories forbid users from approving third-party apps. Then the login shows "needs admin approval" and only the school's IT admin can allow it. Nothing in our code can get around that, and it should not try.
- **App-folder scope on school accounts.** I believe it works on school/work OneDrive, but I have not verified it; the spike tests exactly this.
- **Your notes outlive the account.** A school account is deleted when you leave. Because the local folder is the truth and the format is open, you lose nothing, but you will need to move to another account then.

So the spike in milestone (b) now has three possible results:

| Result | Consequence |
|---|---|
| Login and app folder work with the school account | Sync is built as planned |
| Login works, app folder does not | Ask you whether full-OneDrive access is acceptable |
| School blocks the app | You ask the school admin (I write the request text), or use a private Microsoft account (5 GB free), or we pick another storage provider before milestone (g) |

The sync decision logic is storage-neutral anyway, so a different provider would replace only the thin network layer.
