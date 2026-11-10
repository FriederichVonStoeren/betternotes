# Checkpoint (b): how the drawing feels

This build is only a test bench. It saves nothing; everything you draw is gone when the app
closes. The point is to decide how betternotes will draw (docs/DECISIONS.md, D2) and to see
what your Pencil Pro reports.

## Install

Follow [SIDESTORE.md](SIDESTORE.md). Use the newest release (v0.2 or later).

## The three modes (switch at the top)

| Mode | What draws | What to judge |
|---|---|---|
| **PencilKit** | Apple's own canvas | The reference: this is the best latency an app can get |
| **Custom** | Our own engine | Does the line lag behind the tip more than in PencilKit? Does it feel "attached"? |
| **Hybrid** | PencilKit while the pencil is down; our engine redraws the stroke when you lift | Does the stroke visibly jump or change thickness at lift-off? |

"Finger draws" is off on the iPad, so your palm cannot draw. Switch it on only to try
without the Pencil.

## Tests

Write a few lines of normal handwriting in each mode, then fast loops and zig-zags.

1. **Lag**: draw quick long lines. How far behind the tip is the end of the line?
   Compare Custom with PencilKit.
2. **Slow-motion check** (optional but the most reliable): film the pencil tip with your
   phone in slow motion (240 fps if it has it), then step through the video. Count the
   frames between the tip moving and the line following. Do it for PencilKit and Custom.
3. **Palm**: rest your hand on the screen while writing in Custom. Any stray marks? Does the
   pencil stop drawing?
4. **Pressure**: press lightly, then hard, in Custom. Does the line get thicker?
5. **Long stroke**: draw one stroke for 20 seconds without lifting (scribble). Does Custom
   get slower towards the end?
6. **Lift-off in Hybrid**: draw, lift, and watch the stroke at that moment.
7. **Rotate the iPad** with strokes on the screen in Custom. They stay at their position on
   the screen and do not move with the paper yet; that is expected. Anything else odd?

## The grey text at the bottom left

| Line | Meaning | What I need |
|---|---|---|
| Custom engine: input age / drawing / samples per second | How old a pencil report is when the app gets it, how long our drawing code takes, how many reports arrive | The three numbers while drawing fast in Custom |
| Pencil: force, tilt, azimuth, roll | Live values while drawing in Custom | Does **roll** change when you rotate the Pencil Pro around its axis? |
| Hover | Shown while the tip is close above the screen | Does height change as you move the tip up and down? |
| Last gesture | Squeeze and double-tap on the Pencil Pro | Does a squeeze show up? Does a double-tap? |

Note: these numbers do not include the time the screen needs to show the line. No app can
measure that; this is what the slow-motion video is for.

## Report back

Done / not done:

- [ ] Installed through SideStore, app opens
- [ ] PencilKit mode draws
- [ ] Custom mode draws
- [ ] Hybrid mode draws
- [ ] Custom vs PencilKit lag: same / slightly worse / clearly worse
- [ ] Slow-motion frames: PencilKit ___ , Custom ___ (if you did it)
- [ ] Palm rejection in Custom: fine / stray marks / pencil blocked
- [ ] Pressure changes the width in Custom: yes / no
- [ ] Long stroke in Custom stays smooth: yes / no
- [ ] Hybrid lift-off: no visible change / small jump / clearly different stroke
- [ ] HUD numbers while drawing fast: input age ___ ms, drawing ___ ms, ___ samples/s
- [ ] Roll changes: yes / no
- [ ] Hover shows values: yes / no
- [ ] Squeeze detected: yes / no. Double-tap detected: yes / no
- [ ] Language follows the iPad (German/English): yes / no

Also for this checkpoint, separate from the iPad:

- [ ] OneDrive test: follow [MICROSOFT_APP.md](MICROSOFT_APP.md) and send the copied report
- [ ] SideStore source: in SideStore > Sources > **+**, add
      `https://friederichvonstoeren.github.io/betternotes/apps.json`. Does betternotes
      appear there, and does it offer the update when a new version is released?
