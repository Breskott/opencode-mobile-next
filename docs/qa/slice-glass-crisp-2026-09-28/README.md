# slice-glass-crisp — the floating glass, crisp on light and dark (2026-09-28)

Branch `revamp/slice-glass-crisp`, worktree `oc_app-slice-glass-crisp`, base
`7954e980` (feat/phone-setup-v2).

Finish line: on build 2057's Work page the pill, search and dock read as crisp
glass with one tight shadow, on Graphite light and dark. Non-goals: changing the
spec's numbers, glass anywhere but the floating navigation layer, and a flat
ground outside the shell.

## The owner's report

The owner, build 2057 on their phone (Impeller, light theme): "Glass effects aren't
looking good." See `../owner-glass-2057-light.jpg`. What was wrong:

- a large, soft grey shadow under the server pill, the search circle and the dock;
- the glass read as a plain white blob;
- the edges were soft.

The standard is visual language §6–7 and the canvas
`docs/design/visual-language-2026-09-26/GlassWork.png`.

## Reproduced first

`tool/capture/glass_crisp_test.dart` renders with real Impeller
(`flutter test --enable-impeller`, the liquid look), light and dark. The scene is a
Work-like page: `KitScreen` under `KitNav`, the shell top bar, rows, and the pinned
"New conversation" block. It has two states:

- at rest;
- scrolled, with no pinned block so the list passes under the dock.

The same script ran on the base (`renders/before/`) and on this branch
(`renders/after/`).

The before render matches the owner's phone. Under the light theme there is a hard
grey ledge under every glass piece, and the pill's lower half is grey.

**Cause.** `KitGlass` painted its `BoxShadow` *under* the glass. The glass then read
its own shadow from the backdrop, and the tint, which thins towards the edge, showed
it as a grey band inside the bottom edge. The shadow itself used Flutter's blur
conversion (sigma 9.7 for "blur 16") and spread all round the glass.

## What changed

- **Shadow** (`KitTokens.glassShadows`, `_GlassPaint.paintShadows`):
  - It is still one shadow: y 6, blur 16, 30 % `glassShadow`.
  - The blur now uses CSS's sigma (8), matching the canvas.
  - It is pulled in by 6 on every side (spread −6), so no halo shows above or beside the glass.
  - It is painted *after* the glass and *only outside* its shape, for single glass and for the joined pair. The glass never reads its own shadow, so the ledge is gone.
- **Rim** (`_GlassPaint.paintRim`), exactly one physical pixel wide:
  - It runs from a light line at the top to a darker line at the bottom, with no gap on the sides.
  - On light, where white glass has no edge of its own, the edge line is `glassRimDark` at 60 % going to 100 %. The pixel just inside the top edge is the light line.
  - The liquid pair now paints the rim too; before, it had none.
  - The shader's soft halo and band glow are gone.
  - Role changes: dark `glassRimLight` .20 → .28; light `glassRimDark` .10 → .18.
- **Pixel snapping:**
  - `_GlassPixelSnap` moves the glass's origin onto the device pixel grid (by under half a physical pixel; the shader reads the moved place).
  - `GlassGeometry.snap` / `rectFor` round every drawn edge to a physical pixel, so the clip and the rim are crisp wherever the glass is laid out.
- **Lens and tint** (`shaders/kit_glass.frag`):
  - The tint stays full over the middle, where labels sit.
  - It clears to about a quarter over the outer few pixels, so the bent backdrop shows as a clear lens ring.
  - A faint sheen lit from above covers the top half and gives the glass a body. It is a fill gradient, not a glow.
- **Ambient ground** (§6):
  - A page under `KitNav` (new `KitNav.hosts`) paints the theme's existing `ambient` roles on its ground, in `KitScreen`'s page frame.
  - Graphite dark gets a green field at the top start and a blue one at the end middle. Graphite light gets one green field. A theme pack gets one field in its accent.
  - Pages outside the shell keep a flat ground.
- **Dimming behind text:** unchanged and checked. Glass that holds words keeps `surface2` at 88 % over the middle, on a σ 5 frost. In the scrolled renders the list under the dock shows only as colour: no letters read through the dock or the pill.

## Images

- `canvas-owner-before-after.png`: the canvas, the owner's phone, and before/after for light and dark.
- `contact-sheet-light.png` and `contact-sheet-dark.png`: before on the left, after on the right. Each shows:
  - the server pill;
  - the search circle;
  - the dock with its active lens;
  - the list scrolled under the dock;
  - the top pair joined over the list.
- `renders/before/liquid-{rest,scrolled}-{light,dark}.png` and `renders/after/…`: full Impeller renders.
- `work-loaded-golden-before-after.png`: the Work golden (Skia, frosted), light and dark, before and after.

## Tests

New tests, each failing on the base and passing here:

- `test/kit_glass_test.dart` "the one shadow is the glassShadow role, tight, only outside the glass". It checks for a shadow below the glass, no halo above it, and no ledge inside the bottom edge. On the base it fails with a ledge of 13 against a limit of 4.
- `test/kit_glass_test.dart` "the glass sits on physical pixels wherever it is laid out". The glass is laid out at fractional offsets and sizes, and every drawn edge must land on a physical pixel. On the base the top edge lands at 30.3.

Updated tests:

- `test/app_theme_test.dart`: the shadow's spread is −6.
- `test/theme_roles_test.dart`: the two rim values.

**Gates, all passing:** kit_ratchet (including G21), kit_manifest (G4), kit_motion,
redaction, ui_glossary, no_raw_error_text, plus kit_glass, kit/kit_glass,
glass_surface (contrast on every theme pack), theme_roles, app_theme, kit_nav,
kit_top_bar and kit_screen.

**Failing here and on the base alike:**

- G23 golden harness ratchet;
- G25 golden-failure artefacts (history);
- the notice inventory test.

`flutter analyze` on the whole project: no issues. All heavy commands went
through `tool/qa/machine_lock.sh`.

**Goldens.** I ran all 207 golden test files on the base and on this branch and
compared failures by test name:

- The base already fails 862 golden tests.
- 81 tests failed only here, all in the glass, nav, top bar, Work, shell and chat-state files.
- I regenerated only those. Any image whose golden also fails on the base was reverted and left as it was.
- After that, those files fail only tests that fail on the base.

The refreshed goldens:

- `kit_glass_*`
- `kit_nav_dock_*`, `kit_nav_rail_needs_you_1280x800`, `kit_nav_sidebar_default*`
- `kit_top_bar_shell_*`
- `work_*` and `work_workspace_*`
- `shell_command_palette_open*`, `shell_home_shell_*`, `shell_shortcuts_help_open*`
- `chat_notify`, `chat_permission`, `chat_send_error`, `chat_transcript_1280x800`

## Not done

- **Emulator screenshot.** Debug APKs do not run on the Shorebird-pinned engine, and a release build is a long, signed Gradle build on a shared machine. So there is no emulator-5554 shot. The Impeller renders use the same engine path as the phone. The owner's phone was not touched.
- **Ambient field strength.** The fields are the theme's existing subtle values (6–8 %). The canvas's green field is much stronger. Raising them is a theme decision for the owner.
