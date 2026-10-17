# Live background, 2026-10-14

Ten looks behind the ground of every page, one switch, a picker with live
tiles and a full-screen preview, and an Intensity choice. Solid cards and
rows stay on top; nothing is blurred or see-through (no glass), never red.

## Where it is wired

- `lib/ui/kit/kit_live_background.dart` is `KitLiveBackground`, used in
  `_PageFrame` of `lib/ui/kit/kit_screen.dart`: the single place a page's
  ground is painted (the Material there is now transparent over it).
- Looks live in `lib/ui/kit/live_background/` behind `KitLiveStyle`
  (`id`, `label`, `paint`, `warmUp`, `ceilingFactor`); registry
  `kitLiveStyles`, default `aurora`.
- Settings > Appearance > Effects: **Live background** switch, **Look** row
  (opens the picker), **Intensity** (Subtle 0.7, Normal 1.0, Bold 1.6).
  Stored per device: `oc.effectsLiveBackground`, `oc.effectsLiveStyle`,
  `oc.effectsLiveIntensity` (never profile scoped).
- Picker: `KitLiveStylePicker` (lazy grid, only on-screen tiles run, each a
  live look behind a mock chat, the chosen one marked with a check that
  pops in). Tap a tile: `KitLiveStylePreview` full screen with a
  "Reply running" switch and "Use this".
- Reply running: the composer's glowing border (`_ComposerFrameState`)
  adds one to `KitLiveBackground.running` while active, so the look
  brightens over 600 ms and settles. Composer glow itself is untouched.

## Pausing

One `Ticker` per visible page, started only when the setting is on (or a
preview), `KitMotion.loopsIn` (system remove-animations, Animations Calm or
Off stop it, leaving a still frame), and the app is resumed
(`WidgetsBindingObserver`); stopped otherwise. Covered pages are
ticker-muted by their route. Android battery saver: the app exposes no such
signal, and no new channel was added, so it is not wired.

## Frame cost and frame rate

No cap: the ticker fires every vsync (display refresh rate). Per frame:
- Field looks (aurora, mesh, contours, liquid blobs) sample a coarse grid
  (about 3 to 8 logical px) and draw it as ONE `drawVertices` mesh the GPU
  interpolates, no image decoding and no blur. The grid colours are
  recomputed at 15 to 30 Hz (the fields drift by under a pixel per
  recompute); the mesh draw itself is every frame.
- Sparse looks (dots, halftone, constellation, flow threads) draw a few
  hundred to ~1,500 small shapes from cached geometry (halftone's noise is
  cached; grain points are cached).
- Not measured on a device (no DevTools run here). The estimate: grid
  recompute is a few ms at 30 Hz, mesh and shape draws are well under 2 ms
  of raster. Needs a phone check at 120 Hz for contours and flow threads.
- Gradient banding: relies on the engine's own gradient dithering on the
  vertex mesh; none added. Look at a phone before calling it clean.

## Contrast

`test/kit/kit_live_background_test.dart` paints every look at its strongest
(running, several moments, dark and light), averages 4x4 pixel blocks, and
requires text2 and text3 to stay at 4.5:1 or better wherever they started
above it. The demo alphas failed that for six looks, so each carries a
calibration factor (dot ripple 0.28, contours 0.54, flow threads 0.54, glow
spill 0.54, light rays 0.7, halftone 0.65, aurora 0.95; mesh,
constellation and blobs 1.0). Bold intensity (1.6) is the person's choice
and is not held to the test.

## Goldens

Under `flutter test` `KitMotion.loops` is false, so the background paints
the flat ground only: every existing golden is unchanged. Only the Appearance
settings goldens changed (the new rows): `test/goldens/settings_appearance_*`
and `test/revamp/goldens/settings_appearance_*`. New kit galleries:
`test/goldens/kit/kit_live_background_*`, `kit_live_style_picker_*`,
`kit_live_style_preview_*`. Evidence images come from
`tool/capture/live_background_test.dart` (looks painted with the test-only
`paintWithoutLoops` flag).

## Known gap

`KitTopBar` paints its own solid ground, so with a strong look (mesh while
a reply runs) the top bar shows as a flat band. `kit_top_bar.dart` is owned
by another builder: make its background transparent over the page ground.

## Images (390 x 844, one screen each, still frame at 8 s)

### Aurora drift (default)

![Aurora drift (default) dark](aurora-dark.png)

![Aurora drift (default) light](aurora-light.png)

![Aurora drift (default) dark, reply running](aurora-dark-running.png)

### Breathing mesh

![Breathing mesh dark](mesh-dark.png)

![Breathing mesh light](mesh-light.png)

![Breathing mesh dark, reply running](mesh-dark-running.png)

### Dot ripple

![Dot ripple dark](dotRipple-dark.png)

![Dot ripple light](dotRipple-light.png)

![Dot ripple dark, reply running](dotRipple-dark-running.png)

### Contour lines

![Contour lines dark](topo-dark.png)

![Contour lines light](topo-light.png)

![Contour lines dark, reply running](topo-dark-running.png)

### Flow threads

![Flow threads dark](flowThreads-dark.png)

![Flow threads light](flowThreads-light.png)

![Flow threads dark, reply running](flowThreads-dark-running.png)

### Glow spill

![Glow spill dark](glowSpill-dark.png)

![Glow spill light](glowSpill-light.png)

![Glow spill dark, reply running](glowSpill-dark-running.png)

### Light rays

![Light rays dark](lightRays-dark.png)

![Light rays light](lightRays-light.png)

![Light rays dark, reply running](lightRays-dark-running.png)

### Constellation

![Constellation dark](constellation-dark.png)

![Constellation light](constellation-light.png)

![Constellation dark, reply running](constellation-dark-running.png)

### Halftone

![Halftone dark](halftone-dark.png)

![Halftone light](halftone-light.png)

![Halftone dark, reply running](halftone-dark-running.png)

### Liquid blobs

![Liquid blobs dark](liquidBlobs-dark.png)

![Liquid blobs light](liquidBlobs-light.png)

![Liquid blobs dark, reply running](liquidBlobs-dark-running.png)

## Loop strip (aurora, dark, 0 / 8 / 16 / 24 / 32 / 40 s)

![0s](strip-aurora-0s.png)

![8s](strip-aurora-8s.png)

![16s](strip-aurora-16s.png)

![24s](strip-aurora-24s.png)

![32s](strip-aurora-32s.png)

![40s](strip-aurora-40s.png)

