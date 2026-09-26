# KitScenes v2 (KitIllustration and `lib/ui/kit/scenes/*`) — API freeze (wave 0)

Unit: `kit-KitScenes-v2` (wave 1, tier 1a, kind `kit-change`, model sonnet; title "Kit scenes and illustration on theme roles"; spec path per work-units.json `docs/ux-system/kit-api/KitScenes.md`). Spec: design-standard §10 (motion and illustration), VL §7 ("illustrations are vector or shader"), with cut review C19 (verdict keep, with a correction: recount before writing the acceptance) and C21 (e) (radius literals inside scene drawing geometry are exempt from the look ratchet). Rules: LOOK-1, LOOK-2, LOOK-4, LOOK-5, LOOK-6, LOOK-35, LOOK-36, LOOK-37, LOOK-38, KIT-9, KIT-43, MOT-6, MOT-7, MOT-9, TEST-14, LAY-8.

## Purpose

The app's drawings: line art in the brand's stroke, drawn in code, that play their entrance once and breathe only while the person waits. v2 moves every colour a scene paints onto `ThemeRoles`, so a drawing follows every theme pack and the coming custom theme with the same meanings as the rest of the app:

- the accent for what matters;
- no red for failures;
- amber only for "needs you";
- flat fills at no more than 12 %.

## Replaces

- **Recount (C19 correction), on `feat/phone-setup-v2` at the time of this freeze:**
  - **`BorderRadius` / `Radius.circular`:** 39 lines in 13 scene files (`folders_open_scene` 8, `states_scenes` 8, `servers_cast` 6, `team_scenes` 5, `setup_cast` 3, `setup_steps_scene` 2, and `servers_link_scene`, `states_parts`, `setup_phone_scene`, `setup_unplugged_scene`, `setup_ready_scene`, `portal_scene` and `states_working_scene` 1 each). There are none in `kit_illustration.dart`. All 39 are drawing geometry in scene units, and are exempt (C21 (e)).
  - **`colorScheme`:** 1 line (`kit_illustration.dart:54`, `KitPalette.of`). The same factory also reads `AppTheme.statusColor` 4 times and `AppTheme.mutedOf` once.
  - **`Color(0x…)`, `Colors.*`, `Gradient`, `MaskFilter`, blur or `Shadow`** in scenes or `kit_illustration.dart`: 0.
  - **Colour role misuse in scenes:**
    - `SetupUnpluggedScene` paints `palette.warning` (the attention amber) for a "not answering" drawing (LOOK-4);
    - `ServersLinkScene` and `SetupStepsScene` paint `palette.failure` (red) for a failed link or step (LOOK-5, B2 interim);
    - `accentSoft` is the accent at 16 %, above LOOK-36's 12 %.
- **What changes:** `KitPalette.of` (the only theme read) becomes a mapping from `ThemeRoles`. `SetupUnpluggedScene` stops using `warning`. No scene's geometry changes.
- **Map element (not built here):** `termux-setup-connect-termux#guide-illustrations` (kit-v2.json `assignment` → `module:special surface`; "one KitScene of the three moves"). Its page is `merge-into:phone-setup-progress`, so the new drawing belongs to the slice that builds that checklist row (MAP-1), which draws it as a `KitScene` under the rules frozen here.

## File

- `lib/ui/kit/kit_illustration.dart` and the 15 files in `lib/ui/kit/scenes/` (the unit's write set).
- Tests: `test/kit/kit_scenes_test.dart` (new). The unit's own existing tests: `kit_states_scenes_test.dart`, `servers_scenes_test.dart`, `setup_scenes_test.dart`, `motion_setup_test.dart`, `motion_states_test.dart`, `team_motion_test.dart`, `phone_setup_ready_screen_test.dart`, and the goldens `team_scenes_golden_test.dart`, `team_discover_scenes_golden_test.dart`, `folder_browser_golden_test.dart`.
- Gallery: `test/goldens/kit/kit_scenes_golden_test.dart` (new).

## Public API

Everything public today is kept (KIT-43). Additions are marked NEW.

```dart
abstract class KitScene {
  const KitScene();
  Size get box => const Size(120, 120);                  // UNCHANGED
  void paint(Canvas canvas, KitSceneFrame frame);         // UNCHANGED
  bool differs(covariant KitScene old);                   // UNCHANGED

  /// NEW. True for a drawing that shows progress along a line (steps, a
  /// relay, a link from one device to another): KitIllustration flips it
  /// horizontally under RTL (LAY-8: progress direction mirrors). Default
  /// false: devices, folders and marks are pictures and never mirror.
  bool get mirrorsInRtl => false;
}

@immutable
class KitPalette {
  const KitPalette({required accent, accentSoft, ink, muted, line, surface,
                    success, warning, failure, progress});   // UNCHANGED fields

  /// NEW. The palette of [roles] (the one mapping; see Tokens).
  factory KitPalette.fromRoles(ThemeRoles roles);

  /// UNCHANGED signature; now KitPalette.fromRoles(ThemeRoles.resolve(theme)).
  factory KitPalette.of(ThemeData theme);
}

@immutable
class KitSceneFrame { /* UNCHANGED: entrance, loop, looping, palette */ }

abstract final class KitDraw {
  static const stroke = 5.0;     // UNCHANGED (scene units)
  static const hairline = 2.5;   // UNCHANGED
  static Paint pen(Color color, [double width = stroke]);   // UNCHANGED
  static Paint fill(Color color);                           // UNCHANGED
  static double interval(double t, double begin, double end, [Curve curve = KitMotion.enter]);
  static double wave(double loop, [double phase = 0]);
  static void partialPath(Canvas canvas, Path path, double t, Paint paint);
  static Color fade(Color color, double opacity);           // UNCHANGED

  /// NEW. A flat accent fill (LOOK-36): [palette].accentSoft, optionally
  /// faded further by [opacity]; never above KitTokens.sceneWashAlpha.
  static Paint wash(KitPalette palette, [double opacity = 1]);
}

class KitIllustration extends StatefulWidget {
  const KitIllustration({
    super.key,
    required this.scene,
    this.width = 160,                        // UNCHANGED default (= KitTokens.illustrationPage)
    this.ambient = false,
    this.loopPeriod = KitMotion.breath,
    this.animateEntrance = true,
    this.entranceDuration = KitMotion.entrance,
    this.semanticLabel,
  });
}

// UNCHANGED public scenes (24): KitPortalScene, KitFoldersOpenScene,
// ServersLinkScene, ServersWelcomeScene, SetupPhoneScene, SetupReadyScene,
// SetupStepsScene, SetupUnpluggedScene, StatesSheetScene, StatesFolderScene,
// StatesTrayScene, StatesSearchScene, StatesTerminalScene,
// StatesUnpluggedScene, StatesWorkingScene, TeamDiscoverTeaserScene,
// TeamDiscoverRelayScene, TeamBoardScene, TeamPlanningScene,
// TeamWakingScene, TeamMergedScene, TeamNudgeScene, TeamRestScene,
// TeamIdleScene; helpers StatesParts, ServersPhone, ServersLaptop,
// TeamAgentPose and the cast files — constructors and fields unchanged.
```

- **No styling parameters are added.** Colours stay inside `KitPalette`, so no screen ever passes a colour to a scene.
- **`width` stays** (KIT-43). Hosts use the two named widths (Tokens) instead of literals; that rule is for the hosts' units.
- **`mirrorsInRtl`:** the unit reviews all 24 scenes and sets it where the drawing shows direction of travel. It records each choice in its QA record ("mirrors: SetupStepsScene, TeamDiscoverRelayScene, …"). The expected set is the step strip, the relay and the phone-to-computer link.
- **Kit copy:** none. Scenes have no words.

## States

| State | What paints | Governed by |
|---|---|---|
| entrance | the drawing draws itself in once over `KitMotion.entrance` (or `celebration` for a finished moment) | `KitIllustration` (unchanged) |
| finished | the complete, still drawing (`loop: 0`) | unchanged; every scene looks complete at `looping: false` |
| ambient | after the entrance, a loop of `KitMotion.breath`, only with `ambient: true`, only while `KitMotion.loopsIn` is true (Animations: Full), at most one per screen | unchanged (MOT-6) |
| reduced | the finished frame at once, with no ticker: under remove animations, Animations: Off, or a celebration with Celebrations off | unchanged (MOT-7) |

Scenes with data (for example the step strip's current step, or a link's failed end) draw what they are given. A failed end is drawn in `ink` (`text1`), never red (LOOK-5). Loading, empty, error, disabled, working and answered are their hosts' states; a scene is only ever a picture of one. KIT-12 doc comment on `KitIllustration`: "States: entrance, finished, ambient, reduced (decorative; not interactive)".

## Tokens

- **`KitPalette.fromRoles(roles)`, the one mapping:**

  | Palette field | Role | Was | Why |
  |---|---|---|---|
  | `accent` | `accent` | `colorScheme.primary` | the one thing that matters (VL §1; Appendix A #30: a drawing's accent) |
  | `accentSoft` | `accent` at `KitTokens.sceneWashAlpha` (0.12) | primary at 0.16 | LOOK-36: flat fills ≤ 12 % |
  | `ink` | `text1` | `onSurface` | strong outlines |
  | `muted` | `text2` | `mutedOf` | secondary outlines |
  | `line` | `text3` | `outlineVariant` | hairlines and quiet detail, opaque; faded only by `KitDraw.fade` in strokes |
  | `surface` | `surface3` | `surfaceContainerHigh` | filled shapes (a phone's screen, a card) |
  | `success` | `success` | status ok | done, merged |
  | `warning` | `attention` | status attention | only for a drawing of "needs you" (LOOK-4); no scene uses it after v2 |
  | `failure` | `text1` | status failure (red) | B2 interim: a failure is said in words and neutral marks (LOOK-5) |
  | `progress` | `accent` | status progress | a working mark (LOOK-6) |

- **`hairline` is not used by scenes:** it is translucent, and LOOK-3 forbids fading it again.
- **New tokens (pre-wave, `_new-tokens.md`):**
  - `KitTokens.sceneWashAlpha` = 0.12;
  - `KitTokens.illustrationPage` = 160 (the default width: a 120-unit box → 160 dp tall, inside LOOK-37's 140–200);
  - `KitTokens.illustrationInline` = 88 (KitStateView's inline width today).
- **KitText:** none.

## Adaptive

- **A drawing scales uniformly to its width and never grows with the window:** the page width is the same on compact, medium, expanded and large. The host centres it.
- **Short windows (< 480 dp tall):** the host uses `illustrationInline` or leaves the drawing out, so it never pushes the primary action off screen (LOOK-37). That is the host's rule (KitStateView), restated here for scene users.
- **DPR:** paths are vector and antialiased at the device pixel ratio (LOOK-35). There are no bitmaps, and nothing is scaled from a raster.
- **Pointer and keyboard:** none (decorative, not focusable).

## Accessibility

- **Excluded from semantics by default.** `semanticLabel` makes it one image node, only when the drawing says something the words around it do not (LOOK-38; unchanged, `kit_illustration_test.dart`).
- **Contrast:** strokes in `text1`, `text2` and `text3` meet the icon floor (≥ 3:1 on ground and surfaces, LOOK-8) in every pack. The `accentSoft` wash is decoration under strokes.
- **200 % text:** no text inside. The host keeps it from crowding the words (LOOK-37 at 412×915, 1.0).
- **No flashing:** loops are ≥ 4 s breaths with no hard on/off.

## RTL

- **Scenes do not mirror by default:** devices, folders, sheets and marks are pictures, and a mirrored laptop or phone looks wrong.
- **A scene with `mirrorsInRtl`** is flipped horizontally by `KitIllustration` under `TextDirection.rtl`, so progress runs from the start edge (LAY-8). The flip is a paint transform, so layout is unchanged.

## Motion and haptics

- **Unchanged:**
  - time comes only from `KitIllustration` (no `AnimationController`, `Ticker` or `Timer` in `lib/ui/kit/scenes`; MOT-9, `design_standard_test.dart`);
  - the entrance plays once;
  - the loop plays only on waiting screens, only under Animations: Full, and stops when `ambient` turns false;
  - Celebrations: off shows a finished moment at once.
- **Paint and transforms only,** each drawing in its own `RepaintBoundary`, with tickers stopped off screen (MOT-5).
- **No haptics.** A host may call `KitHaptics.done` at the moment a celebration marks; the scene never does.

## Data safety and honest state

- **A drawing never contradicts its host's words:**
  - a working scene is `ambient` only while the host's state is waiting or working;
  - a scene with data (step counts, a link's state) is built from the same field the host's words use, and `differs` repaints it when that changes;
  - a failed drawing never uses the accent for the failed part.
- **No new scene is added here.** The guide drawing for Termux belongs to the owning slice.

## Depends on

- **VL:** `ThemeRoles`, `ThemeRoles.resolve`, `KitTokens` (plus the three pre-wave tokens above), `KitMotion`, `KitEffects`.
- **No wave-1 dependency** (tier 1a).

Depended on by: kit-KitStateView-v2 (its `illustration` slot), and every screen that shows a moment (phone setup, servers, the AI Team, Work, Inbox, the terminal's empty state, the folder browser).

## Tests required

In `test/kit/kit_scenes_test.dart`, over all 24 scenes, finished frame, in `graphiteDark` and `graphiteLight` and one derived pack (Catppuccin):

1. **Mapping:** `KitPalette.fromRoles(roles)` equals the table for each field. `KitPalette.of(theme)` equals `fromRoles(ThemeRoles.resolve(theme))`.
2. **No red, no amber:** a painted-colour scan of each scene's finished frame (and of its failed or halted variant, where it has one) finds no `danger` and no `attention` colour. Any scene that draws "needs you" is named in an allowlist with a reason; the list starts empty.
3. **Flat, light fills:** a recording canvas finds no `Shader`, `MaskFilter`, `ImageFilter` or shadow in any paint, and every fill in the accent hue has alpha ≤ 0.12 (LOOK-36).
4. **Theme only:** a source scan of `kit_illustration.dart` and `lib/ui/kit/scenes/**` finds no `Color(0x`, no `Colors.` and no `colorScheme` (LOOK-1, LOOK-2). The look ratchet (kit-gates-ratchet) reports zero non-exempt findings for these files, and radius literals in `lib/ui/kit/scenes/**` are its only exemption (C21 (e)).
5. **Mirror:** a scene with `mirrorsInRtl: true` rendered under RTL equals its LTR render flipped horizontally (pixel compare). A scene with `false` renders identically in both.
6. **Still:** under reduced motion, Animations: Off and `KitMotion.loops = false`, every scene settles after one `pump()` with no active ticker (G8); an `ambient: true` illustration on a resting host does not loop when `loopsIn` is false.
7. **Existing tests pass:**
   - `kit_illustration_test.dart` (semantics, loops);
   - `kit_states_scenes_test.dart`;
   - `servers_scenes_test.dart`, `setup_scenes_test.dart`, `motion_*` and `team_motion_test.dart`.

   Any expectation that encodes the old colours is changed in the same commit and listed with LOOK-4, LOOK-5 or LOOK-36 as the reason (TEST-19 (1)).

## Galleries required

- **New, `test/goldens/kit/kit_scenes_golden_test.dart`,** DPR 3, Android, finished frames (TEST-14), as contact sheets of each scene group on `ground`:
  - portal and folders;
  - states (6);
  - working;
  - setup (5);
  - servers (2);
  - team (7);
  - team discover (2).
- **Contact sheets × dark and light at 412×915:** 7 × 2 = 14 PNGs.
- **Default** (`KitPortalScene` at `illustrationPage` above a title and a primary button, as a page state) × dark and light at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000: 10 PNGs.
- **Arabic** (the mirrored scenes' sheet, and the default page) at 412×915 and 1280×800, dark: 4 PNGs.
- **Text 2.0** (the default page) at 412×915 and 1280×800, dark: 2 PNGs.
- **Names:** `kit_scenes_<group>[_ar][_text2][_WxH]_<dark|light>.png`. That is 30 new PNGs.
- **Regenerated, owned by this unit** (R07: their scenes import only this unit's files): `team_scene_*`, `team_discover_scene_*`, `servers_scene_*` and the scene PNGs its other own tests render. Each changed PNG is looked at and listed (TEST-6). Shared goldens that include a scene inside a screen (phone setup, Work, the AI Team) are listed for the integrator (PROC-10, R07).

## Non-goals

- **No new scene and no redrawn geometry.** The Termux guide drawing belongs to the owning slice.
- **No change to `KitIllustration`'s timing, `KitMotion`, `KitEffects` or the entrance and loop rules.**
- **No host changes:** widths, illustration placement and which states get a drawing stay with the hosts' units (LOOK-37 is checked there).
- **No new colour role.** If the owner later wants a drawing-only accent per pack, that is a `ThemeRoles` decision (Appendix A #30 allows "their own drawing accent from the scene"; v2 keeps it equal to `accent`).

## Open questions

None.
