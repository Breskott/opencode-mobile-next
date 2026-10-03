# Liquid glass and Settings › Appearance › Effects (2026-09-25)

## Scope

The owner: "Why no liquid glass for Android?" (iOS 26's Liquid Glass: translucent
surfaces that lens what is behind them at their edges, a soft specular rim, frost,
depth). Then, approved mid-task: "Let's improve appearance with feature toggle in
appearance, good idea." Issue #87 began as "choppy UI", so performance is the gate.

Two slices on `ds/liquid-glass` (from `2730891b`, merged with `feat/phone-setup-v2`
at `019f643a` for the coordinator's `KitEffects`):

1. **`KitGlass`** (`lib/ui/kit/glass/`, `shaders/kit_glass.frag`): a bounded rounded
   surface that is liquid glass where the phone runs the shader, the old frosted blur
   where it cannot, and solid when turned off or under accessibility settings. The
   bottom dock (`GlassSurface`) now delegates to it.
2. **Settings › Appearance › Effects**: Glass effects, Animations (Full · Calm · Off),
   Celebrations, Vibration — stored app-wide, provided above the navigator by
   `KitEffectsScope`, obeyed by `KitGlass`, `KitMotion`, `KitIllustration` and
   `KitHaptics`.

### Feasibility (timeboxed; answered from the pinned engine's sources)

Pinned Flutter 3.47.1, `~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5`.

| Question | Answer (where) |
|---|---|
| Can a backdrop run a custom fragment shader? | **Yes.** `ui.ImageFilter.shader(FragmentShader)` (`bin/cache/pkg/sky_engine/lib/ui/painting.dart:4461`) used as a `BackdropFilterLayer`'s filter. The first uniform must be a `vec2` (the engine writes the input texture's size into it) and the first `sampler2D` receives the backdrop. Impeller renders it in `impeller/entity/contents/filters/runtime_effect_filter_contents.cc`; the engine's own tests `ClippedBackdropFilterWithShader` and `ComposeBackdropRuntimeOuterBlurInner` cover a clipped backdrop and a shader composed over a blur — exactly this use. |
| Coordinates | `FlutterFragCoord()` is a pixel of the input texture (the `_fragCoord` varying of `runtime_effect.vert`), which for the app's layers is the screen's physical pixel grid. The glass therefore passes its own rectangle in physical pixels: `getTransformTo(null)` (which stops below the root view's device pixel ratio — measured: it returns logical pixels) × `devicePixelRatio`. |
| Uniform lifetime | `ReusableFragmentShader::as_image_filter` copies the uniforms when the native filter is created (lazily, at `addToScene`), and two filters made from one shader compare equal. `RenderLiquidGlass` alternates between two shaders so a moved glass always gets a new filter. |
| Impeller on OpenGL ES (Vulkan-less phones) | Supported: `isShaderFilterSupported` is true for any Impeller backend. The texture's y axis is flipped on GLES; the shader flips `uv.y` under `#ifdef IMPELLER_TARGET_OPENGLES` (as the API docs require). `impellerc` compiles GLES, GLES3 and Vulkan stages from the one `.frag`. |
| Skia (Impeller disabled) | `ImageFilter.shader` throws `UnsupportedError`. Detected with `ui.ImageFilter.isShaderFilterSupported` (**false** under Skia and under plain `flutter test`); `KitGlass` then never loads the shader and draws the frosted blur. The app does not disable Impeller in `AndroidManifest.xml`, so Android uses Impeller (Vulkan, falling back to GLES). |
| Sharing one backdrop read | `BackdropKey` / `BackdropGroup` / `BackdropFilter.grouped` exist (`rendering/layer.dart:2315`, `widgets/basic.dart:471`); `KitGlass` joins the nearest `BackdropGroup` (liquid via `BackdropFilterLayer.backdropKey`, frosted via `backdropGroupKey`). |
| "Reduce transparency" on Android | Not exposed to Flutter: `AccessibilityFeatures` has high contrast, accessible navigation, remove animations, bold text, invert colours, … but no transparency flag. Glass is solid under the first three (as the dock already was). |
| Package needed? | **No.** Everything is in `dart:ui` and the framework. (`liquid_glass_renderer` on pub.dev does similar things; not needed and not added.) |
| Can tests see the shader? | `flutter test --enable-impeller` runs flutter_tester on Impeller: the shader loads and renders (used for `renders/` and the two Impeller-only tests). Plain `flutter test` is Skia: frosted path only. |

### What `KitGlass` does

`KitGlass(child:, borderRadius:, shadow:)`, look chosen by `KitGlass.lookOf(context)`:

| Look | When | Draws |
|---|---|---|
| `liquid` | Impeller, shader loaded, Glass effects on, no accessibility override | One `BackdropFilterLayer` inside a `ClipRRect`: `ImageFilter.compose(outer: kit_glass.frag, inner: blur σ 8)`. The shader: within 18 dp of the rounded edge the (lightly frosted) backdrop is read from up to 10 dp further in (a lens pulling content outwards); red is read a little further in at the rim (dispersion); the surface tint is laid full over the middle (the dock's 72/78 % — same contrast guarantee for the labels) and thins to half across the edge so the bend shows; an analytic rim light from the top left plus a fainter opposite rim. **2 texture reads per pixel, no loops**, over the glass's own rectangle only. |
| `frosted` | Skia, or before the shader has loaded (first frames) | Exactly the dock's old look: blur σ 12, tint 72/78 %, hairline border, soft shadow. |
| `solid` | Glass effects off, or high contrast / accessible navigation / remove animations | Opaque `surfaceContainerHigh` with an outline, no shadow, no filter. |

The glass follows itself: the rectangle is read when it paints and checked after every
frame (a page transition or keyboard moves it without repainting); a change repaints
within one frame; an idle screen stays idle (post-frame check only, never asks for a
frame; `pumpAndSettle` settles in the test).

Where it is used now: **the bottom dock** (`GlassSurface` → `KitGlass`, API unchanged)
and the preview chip in Settings › Appearance.

Not applied, and why:

- **Chat composer** — the chat library (`chat_screen.dart` + `chat/*.dart`) belongs to
  ds/motion-adopt. Adoption steps for its owner are below.
- **Top bar** — no screen scrolls content under its `AppBar` today (`extendBodyBehindAppBar`
  is never set); glass there needs per-screen layout changes plus a scrolled-under
  switch. Not cheap, so not done; `app_theme.dart` is untouched.
- **Bottom sheets** — a modal sheet sits over a 54 % scrim, so glass would only frost a
  dark scrim, and tall sheets approach full screen (the standard forbids full-screen
  glass). Left opaque.

### Settings › Appearance › Effects

`AppearanceSettingsScreen` (`lib/ui/screens/settings/personal_settings_screens.dart`) now
reads: **Display** (Light or dark, Language) · **Effects** · **Theme**. Effects:

- a small live preview: the portal drawing (draws itself in again on each Animations
  change, finished at once under Off; no loop, so the page rests) beside a glass chip
  over stripes (liquid/frosted/solid as chosen);
- **Glass effects** switch — supporting line says the truth: "The dock and message box
  float as glass over what scrolls beneath" (liquid-capable), "Uses a frosted surface on
  this phone" (Skia), or "Solid while high contrast, a screen reader or Remove
  animations is on";
- **Animations**: Full · Calm · Off segmented choice with the chosen one's line (Full
  "Drawings move and waiting screens breathe", Calm "Drawings appear, nothing keeps
  moving", Off "Everything shows at once") and, when the system's Remove animations is
  on, a note that it overrides;
- **Celebrations** and **Vibration** switches.

A choice shows at once and is saved; a refused save puts it back and shows a `KitNotice`.
Stored in `ProfileStore` next to appearance/theme (`oc.effectsGlass`, `oc.effectsMotion`,
`oc.effectsCelebrations`, `oc.effectsHaptics`: app-wide, no profile id), exposed as
`ConnectionController.effects` (`ValueNotifier<KitEffects>`) + `setEffects`, provided by
`KitEffectsScope` in `main.dart`'s `MaterialApp.builder` (above the navigator), which
also mirrors Vibration into `KitHaptics.enabled`. Strings in `app_en.arb` / `app_ar.arb`
(20 keys, `effects*` + `appearanceDisplaySection`).

`lib/state/{profiles,connection}.dart` import `lib/ui/kit/kit_effects.dart` (`show
KitEffects, KitMotionLevel`) — the first `state → ui` import. `KitEffects` is a plain
value type; moving it to `lib/state/` (or `lib/domain/`) and re-exporting from the kit
would remove the edge — the coordinator's call, since the kit file is coordinator-owned.

### For the chat owner: adopting glass in the composer

The composer is not floating today (the transcript ends above it), so glass needs the
transcript to scroll under it:

1. In `chat_screen.dart`, lay the transcript and `_ChatComposer` in a `Stack`: the
   transcript fills the body; the composer is `Positioned(bottom: 0, left: 0, right: 0)`;
   the transcript's list gets a bottom padding equal to the composer's measured height
   (measure with a `SizeChangedLayoutNotifier` or a small `RenderProxyBox` that reports
   its size; keep the "jump to latest" and nudge slot above it).
2. Wrap the chat `Scaffold` in `BackdropGroup(...)` so the composer and any later glass
   (a floating top bar) share one backdrop read.
3. In `chat/composer.dart` `build`, keep `AnimatedContainer('chat-composer-surface')` for
   the border and the activity ring but give it `color: Colors.transparent`, and wrap its
   child in `KitGlass(borderRadius: radius, shadow: false, child: ...)` (import
   `../../kit/kit.dart`, already imported by the library). `KitGlass` lays the tint and
   is solid under accessibility settings and when turned off, so no extra conditions.
4. Test: the composer's `KitGlass` is `frosted` under `flutter test`, `solid` under
   `KitEffects(glass: false)`; the last transcript row stays fully visible above the
   composer (hit-testable), with the keyboard open and closed.
5. Measure scenario 1 below with the composer before merging.

## Builds

- Branch `ds/liquid-glass` (no push). No APK, no emulator, no Gradle (other agents share
  the machine).
- Shader compile check (0.4 s, no Gradle), the same invocation flutter_tools uses for
  `shaders:` on Android:

  ```sh
  E=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/cache/artifacts/engine/linux-x64
  $E/impellerc --sksl --runtime-stage-gles --runtime-stage-gles3 --runtime-stage-vulkan \
    --iplr --sl=/tmp/kit_glass.frag.iplr --spirv=/tmp/kit_glass.frag.iplr.spirv \
    --input=shaders/kit_glass.frag --input-type=frag --include=shaders --include=$E/shader_lib
  ```

  Exit 0, 17.6 KB `.iplr` (SkSL + GLES + GLES3 + Vulkan stages). `flutter test` also
  compiles `shaders:` entries into the test asset bundle, and every test here that loads
  `shaders/kit_glass.frag` did so.

## Devices

None. Widget tests (Skia and Impeller flutter_tester) and rendered frames only.

## Runs

| # | Run | Expected | Actual |
|---|---|---|---|
| 1 | `test/kit_glass_test.dart` (10): frosted where unsupported, clipped and bounded to its own rect, nothing loaded; the engine's answer drives support; glass off → solid; high contrast / accessible navigation / remove animations → solid even with the shader loaded; frosted until the shader loads, then liquid; two glasses under a `BackdropGroup` share one key; **Impeller only:** the lens sits in a `ClipRRect` at the glass's rectangle × dpr with no child fill; a glass moved by an ancestor transform without repainting is followed within one frame and the screen settles | pass | PASS — plain: 8 + 2 skipped; `--enable-impeller`: 10 |
| 2 | `test/appearance_effects_test.dart` (12): defaults on; round trip through a restart; app-wide keys not swept with a profile; unknown motion reads Full; the section shows the four choices and the frosted truth; glass off → preview solid and saved; Calm/Off chosen, saved, line changes; Celebrations/Vibration saved; the system's Remove animations note; refused save reverts with a notice; **the real `OcApp`**: routes read the stored choice (Calm: no loops; Full: loops; Off: reduced) and follow changes, `KitHaptics.enabled` mirrors Vibration; Vibration off → zero `HapticFeedback.vibrate` calls on a mocked `SystemChannels.platform` (send and done, with and without context); glass off → solid app-wide | pass | PASS |
| 3 | `test/glass_surface_test.dart` (+1: the dock is solid when Glass effects is off) | pass | PASS |
| 4 | Runs 2–3 with the pre-change `glass_surface.dart`, `personal_settings_screens.dart` and `main.dart` (from `019f643a`; persistence and new files kept so it compiles) | the new behaviours fail | FAIL, 10 tests (`failing-first-without-change.txt`): the dock ignoring Glass off, 6 page tests (no Effects section), 3 app-wiring tests (no scope, haptics not mirrored) |
| 5 | Affected files: home navigation, theme packs, settings hub, search index, kit illustration, design standard, appearance picker, all `test/goldens/`, routing/shell/text-scale/accessibility tests that pump the app | pass | see "Final checks" |
| 6 | `tool/capture/liquid_glass_test.dart` with `--enable-impeller` | renders | 8 PNGs in `renders/` |

### Final checks

- `flutter analyze lib test tool/capture/liquid_glass_test.dart`: no issues.
- Run 5, one `-j 2` invocation of 38 files (all 13 `test/goldens/` files, home
  navigation, first run, server switcher, share/launch/session-link routing, text scale,
  accessibility guidelines, search index, lifecycle, product regressions, glass surface,
  theme packs, work tab cleanup, motion states, release blockers, kit glass, appearance
  effects, settings hub, design standard, kit illustration, appearance picker, codex
  navigation, desktop shortcuts): **572 passed, 2 skipped** (the Impeller-only tests),
  0 failed. Only `settings_appearance_{dark,light}` goldens changed and were re-recorded
  first. After a last main.dart edit (same behaviour, smaller diff): appearance effects,
  share routing and text scale re-run, 22 passed.
- The full suite was **not** run (coordinator's gate).

## Evidence

- `failing-first-without-change.txt` — run 4.
- `renders/` (Impeller flutter_tester, 3×, real fonts): `liquid-dark.png`,
  `liquid-light.png` (the dock liquid), `frosted-*.png` (the old look, now the
  fallback), `solid-*.png`, and close-ups `edge-liquid-dark.png` / `edge-frosted-dark.png`
  (a 48 dp-radius pill over diagonal colour and text). In liquid, the rim catches light
  along the top-left and the corners, and colour at the rounded ends is pulled outwards
  and brightened; frosted is flat to the edge.
- Goldens `test/goldens/settings_appearance_{dark,light}.png` re-recorded after looking
  at them (Display label added; Effects section with preview; theme grid moved down).

**What the goldens can and cannot show.** The suite runs on Skia, where the shader is
unsupported: goldens show the frosted fallback and the solid look, never the liquid
glass. The liquid look is only in `renders/` (Impeller flutter_tester, a software
Vulkan) — the same shader and filter path as a phone, but not a phone's GPU, colour
pipeline or timing. Neither shows motion or cost.

## Measure on a device (coordinator)

Profile or release build of this branch merged; the issue-#87 emulator **and** the
owner's phone (Vulkan). If possible also a phone or AVD where Impeller falls back to
OpenGL ES (logcat says "Impeller … OpenGLES") to see the y-flip is right. For each
scenario, glass **On** then **Off**
(Settings › Appearance › Effects › Glass effects), same data, same build:

```sh
PKG=<applicationId>
adb shell dumpsys gfxinfo $PKG reset
# … do the scenario …
adb shell dumpsys gfxinfo $PKG framestats > gfx-<scenario>-<on|off>.txt
# Record: Total frames rendered, Janky frames (%), 50/90/95/99th percentile,
# and from the framestats rows the longest frame (FrameCompleted − IntendedVsync).
```

| # | Scenario | What to do |
|---|---|---|
| 1 | Work tab under the dock | ≥ 20 conversations; fling the Work list up and down 10 times, 1 s apart |
| 2 | Long chat (composer, once adopted) | a conversation with ≥ 100 turns; fling 10 times; then open the keyboard and close it 5 times |
| 3 | Tabs under the dock | Work → Inbox → Project → Settings → Work, 5 rounds (the dock stays, content fades beneath it) |
| 4 | Page push over the dock | open a conversation from Work and go back, 10 times (the lens must stay on the dock's edge during the 250 ms transition — also look) |
| 5 | Sheet | open and close the server switcher sheet 10 times over the Work tab |
| 6 | Settings › Appearance | scroll the page, toggle Glass effects 5 times (preview chip) |

**Pass rule (every scenario):** with glass on, janky frames % is no more than **1
point** above glass off, and no frame over **32 ms** that is absent with glass off.
Also record: GPU/renderer in use (`adb logcat | grep -i impeller` shows "Using the
Impeller rendering backend (Vulkan|OpenGLES)"), and screenshots of the dock on and off
(light and dark) for the audit. If a scenario fails on a device, the fix is to lower
the blur σ (8) or skip the composed blur there, not to widen the glass.

Visual checks on the device: the rim is on the dock's edge (not offset) in portrait
and landscape and during scenario 4; nothing is upside down on a GLES device; labels
stay readable over busy content in both themes.

## How to reproduce

```sh
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get
$F test -j 2 test/kit_glass_test.dart test/appearance_effects_test.dart test/glass_surface_test.dart
$F test --enable-impeller test/kit_glass_test.dart          # the 2 liquid tests run
$F test --enable-impeller --concurrency=1 tool/capture/liquid_glass_test.dart   # renders/
# Failing first
git show 019f643a:lib/ui/widgets/glass_surface.dart > lib/ui/widgets/glass_surface.dart
git show 019f643a:lib/ui/screens/settings/personal_settings_screens.dart > lib/ui/screens/settings/personal_settings_screens.dart
git show 019f643a:lib/main.dart > lib/main.dart
$F test -j 2 test/glass_surface_test.dart test/appearance_effects_test.dart   # 10 fail
git checkout -- lib/ui/widgets/glass_surface.dart lib/ui/screens/settings/personal_settings_screens.dart lib/main.dart
```

## NOT proven

- **Nothing on a device**: no frame timing, no real GPU, no GLES device, no look at
  the glass on a phone. "Cheap" is a design claim (2 reads, one bounded pass, a
  downsampled blur) until the table above is measured.
- The composer, top bar and sheets do not use glass (reasons above).
- The search index has no entry for Appearance › Effects (`lib/ui/search/search_index.dart`
  is not in this write set; `AppearanceSection.effects` exists for it to use).
- The lens during a page transition inside a save layer that does not start at the
  screen's origin (none known in the app) would be offset for that transition.
- Arabic strings are written by the agent, not yet reviewed by the Arabic reviewer.
