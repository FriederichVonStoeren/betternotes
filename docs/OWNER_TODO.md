# For the owner: progress, steps, questions

Last updated: 2026-11-11. Do these whenever you have time. Send each report back in the chat
when it is done; they do not have to come together.

## Progress so far

| Milestone | What | Status |
|---|---|---|
| a | Rules, open notebook format (spec, schema, test files), Swift and TypeScript format code, CI | Done, v0.1 |
| b | iPad drawing test app (PencilKit / Custom / Hybrid), Pencil readout, UI screenshot tests, OneDrive test page, SideStore source | Done, v0.2. **Waiting for your device test** |
| c | Real pen, layers, saving notebooks | Starts after your drawing report |
| d to m | Selection, shapes, PDF, library, sync, web app, ... | Later (`docs/SCOPE.md`) |

All automatic checks pass. What only you can check: how drawing feels with the real Pencil.

## Your steps

### 1. Install the app (about 30 to 60 minutes the first time)

Follow [SIDESTORE.md](SIDESTORE.md) from the top. In short: install iloader on Fedora,
connect the iPad by cable, install SideStore with your Apple ID, then install
`betternotes.ipa` from the [v0.2 release](https://github.com/FriederichVonStoeren/betternotes/releases/tag/v0.2).

Optional: in SideStore > Sources > **+** add
`https://friederichvonstoeren.github.io/betternotes/apps.json` so updates show up there.

Report: the checklist at the end of SIDESTORE.md.

### 2. Test the drawing (about 15 minutes)

Follow [CHECKPOINT_B.md](CHECKPOINT_B.md). Draw in each of the three modes and fill in its
checklist. A slow-motion phone video of the pencil tip is optional but the most accurate test.

Report: the checklist at the end of CHECKPOINT_B.md.

### 3. Test OneDrive with your school account (about 15 minutes)

Follow [MICROSOFT_APP.md](MICROSOFT_APP.md): register the app with Microsoft (no password or
secret involved), then open the
[test page](https://friederichvonstoeren.github.io/betternotes/spikes/onedrive/), paste the
ID, sign in with your school account.

Report: the text from the **Copy report** button, plus which account you used to register.

### 4. Optional: one GitHub setting

Lets each release update the SideStore source by itself. Without it I trigger the update
after each release; nothing breaks either way.

Repository **Settings** > **Environments** > **github-pages** > "Deployment branches and
tags" > **Add deployment branch or tag rule** > **Tag** > type `v*` > **Add rule**.

## Questions

1. Which iPad model and iPadOS version do you have? (Shown in Settings > General > About.)
2. Custom vs PencilKit: does Custom feel the same, slightly worse or clearly worse? This
   decides how betternotes draws from milestone (c) on.
3. Hybrid mode: is the change at lift-off acceptable if Custom turns out too slow?
4. Pencil Pro squeeze and double-tap: what should they do by default? Suggestion: squeeze
   opens the tool palette, double-tap switches between pen and eraser.
5. Did step 4 (GitHub setting) get done, or should I keep triggering the update myself?
